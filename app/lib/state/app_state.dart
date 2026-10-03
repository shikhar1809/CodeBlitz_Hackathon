import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../core/evidence_chain.dart';
import '../core/geo.dart';
import '../core/journey_monitor.dart';
import '../core/ladder.dart';
import '../core/pin_vault.dart';
import '../core/threat_judge.dart';
import '../services/alert_service.dart';
import '../services/cloud_service.dart';
import '../services/ear.dart';
import '../services/voice_service.dart';
import '../ui/theme.dart';
import 'models.dart';
import 'wingman_call.dart';

export 'models.dart';

/// Every action the UI can take, wired to the core engine and services.
class AppState extends ChangeNotifier {
  AppState({AlertService? alerts, VoiceService? voice, Ear? ear, CloudService? cloud, this.persist = true})
      : alerts = alerts ?? AlertService(),
        cloud = cloud ?? CloudService(),
        voice = voice ?? VoiceService(),
        ear = ear ?? Ear();

  final AlertService alerts;
  final CloudService cloud;
  final VoiceService voice;
  final Ear ear;
  final bool persist;

  Settings settings = Settings();
  PinVault vault = PinVault();
  bool locked = true;
  final List<LogEntry> log = [];
  final List<Recording> recordings = [];
  Session? session;
  WingmanCall? call;
  Timer? _ticker;
  int _blackboxTick = 0;
  final _rng = Random();
  String? banner;

  DateTime now() => DateTime.now();

  // ---------------------------------------------------------------- storage

  Future<void> load() async {
    if (!persist) return;
    final p = await SharedPreferences.getInstance();
    final s = p.getString('settings');
    final v = p.getString('vault');
    if (s != null) settings = Settings.fromJson(jsonDecode(s));
    if (v != null) vault = PinVault.fromJson(jsonDecode(v));
    notifyListeners();
  }

  Future<void> save() async {
    if (!persist) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('settings', jsonEncode(settings.toJson()));
    await p.setString('vault', jsonEncode(vault.toJson()));
  }

  void update(void Function(Settings s) change) {
    change(settings);
    save();
    notifyListeners();
  }

  void note(String text) {
    log.insert(0, LogEntry(now(), text));
    if (log.length > 300) log.removeLast();
    notifyListeners();
  }

  void showBanner(String text) {
    banner = text;
    notifyListeners();
    Timer(const Duration(seconds: 3), () {
      if (banner == text) {
        banner = null;
        notifyListeners();
      }
    });
  }

  // ------------------------------------------------------------ onboarding

  void finishOnboarding({
    required String name,
    required String lang,
    required List<Guardian> guardians,
    required String pin,
    required String duress,
    required bool homeMode,
  }) {
    vault = PinVault()..setPins(pin, duress);
    settings
      ..name = name.trim()
      ..lang = lang
      ..guardians = guardians
      ..homeMode = homeMode
      ..onboarded = true;
    locked = false;
    save();
    note('Winger set up for ${settings.name}');
  }

  // -------------------------------------------------------------- disguise

  /// The wallpaper search box. Returns true when Winger should open.
  bool tryUnlock(String entry) {
    if (!settings.onboarded) {
      // Demo build before set-up: the demo PIN opens onboarding.
      if (isDemo && entry == Demo.pin) {
        locked = false;
        notifyListeners();
        return true;
      }
      return false;
    }
    switch (vault.check(entry)) {
      case PinResult.real:
        locked = false;
        notifyListeners();
        return true;
      case PinResult.duress:
        if (session != null && session!.ladder.isAlerting) _duress();
        return false;
      default:
        return false;
    }
  }

  void lock() {
    locked = true;
    notifyListeners();
  }

  /// Long-press on a wallpaper: silent SOS. Nothing changes on screen.
  Future<void> silentSos() async {
    if (session == null) await _startSession(SessionKind.wingman, quiet: true);
    await silentAlert('Silent SOS from the wallpaper screen');
  }

  // --------------------------------------------------------------- sessions

  bool get active => session != null;

  Color? get statusColor {
    final s = session;
    if (s == null) return null;
    if (s.duress) return W.silentHelp;
    final r = s.ladder.rung;
    if (r.index >= Rung.guardian.index) return W.alerting;
    if (r == Rung.nudge || r == Rung.ask) return W.checking;
    if (s.silentAlertSent) return W.silentHelp;
    return W.watching;
  }

  /// Status as the guardian's tracking page shows it.
  String get cloudStatus {
    final c = statusColor;
    if (c == W.silentHelp) return 'silent';
    if (c == W.alerting) return 'alerting';
    if (c == W.checking) return 'checking';
    return 'watching';
  }

  String get _trackSuffix => cloud.trackUrl == null ? '' : ' Live: ${cloud.trackUrl}';

  String get headline {
    final s = session;
    if (s == null) return 'Hi ${settings.name.isEmpty ? 'there' : settings.name}';
    final r = s.ladder.rung;
    if (!s.duress && (r == Rung.nudge || r == Rung.ask)) return 'Are you okay?';
    if (!s.duress && r.index >= Rung.guardian.index) return 'Help is being called';
    return 'Wingman is on';
  }

  String get statusText {
    final s = session;
    if (s == null) return "You're protected. All quiet.";
    if (s.duress) return 'Alert cancelled.';
    switch (s.ladder.rung) {
      case Rung.idle:
        if (call != null && !call!.ended) return 'On a call with ${settings.companionName}.';
        return s.listenOnly ? 'Listening quietly.' : 'Watching over you.';
      case Rung.nudge:
        return 'Something looks unusual.';
      case Rung.ask:
        return 'Checking on you.';
      case Rung.guardian:
        return 'Guardians alerted.';
      case Rung.countdown112:
        return 'Calling 112 in ${s.ladder.remaining(now())}s.';
      case Rung.called112:
        return '112 called.';
    }
  }

  /// The check-in overlay is shown for ask and above, unless the duress PIN
  /// made everything look stopped.
  bool get showCheckIn {
    final s = session;
    if (s == null || s.duress) return false;
    final r = s.ladder.rung;
    return r == Rung.ask || r == Rung.guardian || r == Rung.countdown112;
  }

  Duration get _checkInEvery => isDemo || settings.demoMode ? Demo.checkInEvery : realCheckInEvery;

  LadderWindows get _windows => isDemo
      ? const LadderWindows(
          nudge: Duration(seconds: 5),
          ask: Duration(seconds: 30),
          guardian: Duration(seconds: 30),
          countdown112: Duration(seconds: 15))
      : const LadderWindows();

  Future<Session> _startSession(SessionKind kind, {bool quiet = false}) async {
    final t = now();
    final chain = await EvidenceChain.create();
    final title = switch (kind) {
      SessionKind.wingman => 'Wingman',
      SessionKind.journey => 'Journey',
      SessionKind.followed => 'Followed',
    };
    final rec = Recording('r${t.millisecondsSinceEpoch}', title, t, chain);
    recordings.insert(0, rec);
    final s = Session(
        kind: kind, startedAt: t, recording: rec, checkInEvery: _checkInEvery, windows: _windows);
    s.ladder.onClimb = (from, to) => _onClimb(s, from, to);
    session = s;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    note('Blackbox recording (GPS only, no mic)');
    final link = await cloud.start(
        name: settings.name, kind: kind.name, guardians: settings.guardians.map((g) => g.phone).toList());
    if (session != s) return s;
    if (link != null) note('Live tracking link ready');
    if (!quiet) {
      final mins = _checkInEvery.inMinutes;
      note('$title on for ${mins == 0 ? '${_checkInEvery.inSeconds} seconds' : '$mins minutes'}');
      await _smsAll('Winger: ${settings.name} turned on $title. '
          "You'll hear from Winger only if something looks wrong."
          '${link == null ? '' : ' Live: $link'}');
    }
    await _blackbox(s);
    _startEar();
    notifyListeners();
    return s;
  }

  /// Active duty: start Wingman and ring the companion.
  Future<WingmanCall> startWingman() async {
    session ??= await _startSession(SessionKind.wingman);
    return callWingman();
  }

  /// Start watching with no call (deterrent, followed).
  Future<void> startQuiet(SessionKind kind) async {
    session ??= await _startSession(kind);
    session!.listenOnly = true;
    notifyListeners();
  }

  Future<WingmanCall> callWingman() async {
    final s = session!;
    s.listenOnly = false;
    final c = WingmanCall(this);
    call = c;
    note('Wingman call started');
    unawaited(c.start());
    notifyListeners();
    return c;
  }

  /// The call ended: Winger says nothing from now on and only listens.
  void callEnded({bool cut = false}) {
    final s = session;
    if (s == null) return;
    s.listenOnly = true;
    note(cut ? 'Call cut. Staying quiet.' : 'Call ended. Staying quiet.');
    if (cut) {
      s.judge.hearCryForHelp(now(), bonus: -0.75); // call cut counts a little
    }
    notifyListeners();
  }

  Future<void> startJourney({
    required List<LatLon> route,
    required Duration eta,
    required String destination,
  }) async {
    final s = await _startSession(SessionKind.journey);
    s.route = route;
    s.destination = destination;
    s.journey = JourneyMonitor(route: route, eta: eta, startedAt: s.startedAt);
    s.listenOnly = true;
    note('Journey to $destination, about ${eta.inMinutes} min');
    notifyListeners();
  }

  void _onClimb(Session s, Rung from, Rung to) {
    switch (to) {
      case Rung.nudge:
        alerts.vibrate();
        note('Nudge: something looks unusual');
      case Rung.ask:
        alerts.vibrate();
        note('Asked: are you okay?');
        if (!s.listenOnly && settings.voiceCompanion && !settings.homeMode) {
          voice.say('Are you okay?', lang: settings.lang);
        }
      case Rung.guardian:
        alertGuardians('No answer to a check-in');
      case Rung.countdown112:
        note('112 countdown started');
      case Rung.called112:
        note('Calling 112');
        if (alerts.simulate) {
          note('Call to 112 (simulated)');
        } else {
          alerts.call('112');
        }
      case Rung.idle:
        break;
    }
    notifyListeners();
  }

  void tick() {
    final s = session;
    if (s == null) return;
    final t = now();
    s.ladder.tick(t);
    if (t.isAfter(s.nextCheckIn)) {
      s.nextCheckIn = t.add(s.checkInEvery);
      final onCall = call != null && !call!.ended;
      if (!onCall && s.ladder.rung == Rung.idle && s.kind != SessionKind.journey) {
        s.ladder.raise(t, to: Rung.ask);
      }
    }
    call?.tick(t);
    if (++_blackboxTick % 5 == 0) _blackbox(s);
    if (_blackboxTick % 15 == 0) cloud.beat(at: s.location, status: cloudStatus);
    notifyListeners();
  }

  // ------------------------------------------------------------- location

  int _walkStep = 0;

  Future<LatLon> location() async {
    final s = session;
    if (isDemo || settings.demoMode) {
      if (s != null && s.route.length >= 2) {
        // Simulated walk along the route.
        final i = min(_walkStep++ ~/ 3, s.route.length - 1);
        return s.route[i];
      }
      return LatLon(Demo.here.lat + (_rng.nextDouble() - .5) * 1e-4,
          Demo.here.lon + (_rng.nextDouble() - .5) * 1e-4);
    }
    try {
      final p = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      return LatLon(p.latitude, p.longitude);
    } catch (_) {
      return s?.location ?? Demo.here;
    }
  }

  Future<void> _blackbox(Session s) async {
    final p = await location();
    if (session != s) return;
    s.location = p;
    final rec = s.recording;
    await rec.chain.append(ChunkKind.gps, utf8.encode('${p.lat},${p.lon}'));
    rec.gpsPoints++;
    rec.first ??= p;
    rec.last = p;
    final j = s.journey;
    if (j != null) {
      for (final trouble in j.update(p, now())) {
        _journeyTrouble(s, trouble);
      }
      if (j.arrived(p)) {
        note('Arrived at ${s.destination}');
        await _smsAll('Winger: ${settings.name} reached ${s.destination} safely.');
        await stopSession(reason: 'Arrived');
      }
    }
  }

  void _journeyTrouble(Session s, JourneyTrouble t) {
    final what = switch (t) {
      JourneyTrouble.offRoute => 'Left the route',
      JourneyTrouble.stopped => 'Stopped for a while',
      JourneyTrouble.late => 'Running late',
    };
    note(what);
    call?.routeCue(t.name);
    s.judge.hearCryForHelp(now(), bonus: -0.5);
    s.ladder.raise(now(), to: Rung.nudge);
  }

  Future<void> addPhoto(List<int> bytes) async {
    final s = session;
    if (s == null) return;
    await s.recording.chain.append(ChunkKind.photo, bytes);
    s.recording.photos++;
    note('Photo added to the Blackbox');
  }

  // ------------------------------------------------------------- listening

  void _startEar() {
    if (ear.on) return;
    ear.start(phrases: settings.phrases, onHeard: onHeard).then((ok) {
      if (!ok) note('Microphone listening not available here');
    });
  }

  void onHeard(HeardEvent e) {
    final s = session;
    if (s == null) return;
    switch (e.kind) {
      case Heard.safePhrase:
        note('Safe phrase heard');
        silentAlert('Safe phrase: "${e.phrase}"');
      case Heard.cryForHelp:
        note('Heard: "${e.words}"');
        _verdict(s, s.judge.hearCryForHelp(now(), bonus: _bonus(s)));
      case Heard.speech:
        call?.herTurn(e.words);
    }
  }

  /// A sound from the tagger (or the demo sound button).
  void hearSound(String label, double confidence) {
    final s = session;
    if (s == null) return;
    note('Heard: $label');
    _verdict(s, s.judge.hearSound(label, confidence, now(), bonus: _bonus(s)));
  }

  double _bonus(Session s) => ThreatJudge.context(
      night: now().hour >= 21 || now().hour < 5);

  void _verdict(Session s, Verdict v) {
    switch (v) {
      case Verdict.ask:
        s.ladder.raise(now(), to: Rung.ask);
      case Verdict.alert:
        help();
      case Verdict.silentAlert:
        silentAlert('Safe phrase');
      case Verdict.calm:
        break;
    }
  }

  // ---------------------------------------------------------------- alerts

  String _mapLink(LatLon? p) {
    final q = p ?? Demo.here;
    return 'https://maps.google.com/?q=${q.lat.toStringAsFixed(5)},${q.lon.toStringAsFixed(5)}';
  }

  Future<void> _smsAll(String body) async {
    for (final g in settings.guardians) {
      final real = await alerts.sendSms(g.phone, body);
      note('SMS to ${g.phone}${real ? '' : ' (simulated)'}: $body');
    }
  }

  /// Loud alert: SMS everyone, call the first guardian.
  Future<void> alertGuardians(String reason) async {
    final s = session;
    if (s == null) return;
    s.guardiansAlerted = settings.guardians.length;
    await _smsAll('Winger ALERT: ${settings.name} may need help ($reason). '
        'Location: ${_mapLink(s.location)}.$_trackSuffix Please call her now.');
    cloud.beat(at: s.location, status: 'alerting', note: reason);
    if (settings.guardians.isNotEmpty && !settings.homeMode) {
      final g = settings.guardians.first;
      final real = await alerts.call(g.phone);
      note('Calling ${g.name}${real ? '' : ' (simulated)'}');
    }
    notifyListeners();
  }

  /// Silent alert: SMS only, nothing changes on screen or on the call.
  Future<void> silentAlert(String reason) async {
    final s = session;
    if (s == null) return;
    s.silentAlertSent = true;
    s.guardiansAlerted = settings.guardians.length;
    await _smsAll('Winger SILENT ALERT: ${settings.name} signalled she needs help '
        "($reason) but can't talk. Location: ${_mapLink(s.location)}. "
        'Do not call her; call 112 or go to her.$_trackSuffix');
    // The guardian page shows silent help; the reason stays off it so a
    // forced cancel is never revealed to whoever is watching her phone.
    cloud.beat(at: s.location, status: 'silent');
    notifyListeners();
  }

  /// "Help me": straight to guardians.
  void help() {
    session?.ladder.help(now());
    notifyListeners();
  }

  /// Swipe for SOS: straight to 112.
  void sos() {
    session?.ladder.sos(now());
    if (!alerts.simulate) alerts.dial112();
    notifyListeners();
  }

  // ------------------------------------------------------------------ PINs

  /// "I'm safe" / keypad `#`. Returns false for a wrong entry.
  Future<bool> answerPin(String entry) async {
    switch (vault.check(entry)) {
      case PinResult.real:
      case PinResult.code:
        final wasAlerting = (session?.ladder.isAlerting ?? false) ||
            (session?.silentAlertSent ?? false);
        if (wasAlerting) {
          await _smsAll('Winger: ${settings.name} is safe. False alarm, sorry for the worry.');
        }
        await stopSession(reason: 'She is safe');
        return true;
      case PinResult.duress:
        _duress();
        return true;
      case PinResult.wrong:
        return false;
    }
  }

  /// Answer a check-in (not ending the session).
  Future<bool> checkInSafe(String entry) async {
    final s = session;
    if (s == null) return false;
    switch (vault.check(entry)) {
      case PinResult.real:
      case PinResult.code:
        if (s.ladder.isAlerting) {
          await _smsAll('Winger: ${settings.name} is safe. False alarm.');
        }
        s.ladder.safe(now());
        s.judge.reset();
        s.nextCheckIn = now().add(s.checkInEvery);
        note("Check-in: she's okay");
        notifyListeners();
        return true;
      case PinResult.duress:
        _duress();
        return true;
      case PinResult.wrong:
        return false;
    }
  }

  /// Duress PIN: looks identical to a cancel, keeps alerting covertly.
  void _duress() {
    final s = session;
    if (s == null) return;
    s.duress = true;
    s.ladder.help(now());
    silentAlert('Duress PIN entered: she was forced to cancel');
    call?.hangUpQuietly();
    notifyListeners();
  }

  Future<void> stopSession({required String reason}) async {
    final s = session;
    if (s == null) return;
    await call?.end(byUser: false);
    call = null;
    s.recording.endedAt = now();
    session = null;
    _ticker?.cancel();
    await ear.stop();
    await voice.stop();
    note('Session ended: $reason');
    cloud.end(reason == 'She is safe' ? 'safe' : reason == 'Arrived' ? 'arrived' : 'ended');
    notifyListeners();
  }

  // ---------------------------------------------------------- phrase/code

  void setCode(String? code) {
    vault.setCode(code);
    save();
    notifyListeners();
  }

  void changePins(String pin, String duress) {
    final code = vault.codeHash;
    vault = PinVault(salt: vault.salt, codeHash: code)..setPins(pin, duress);
    save();
    notifyListeners();
  }

  void deleteRecording(Recording r) {
    if (r.inProgress) return;
    recordings.remove(r);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Provides [AppState] to the tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
