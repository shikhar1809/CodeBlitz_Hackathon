import '../core/evidence_chain.dart';
import '../core/geo.dart';
import '../core/journey_monitor.dart';
import '../core/ladder.dart';
import '../core/threat_judge.dart';

class Guardian {
  final String name;
  final String phone;

  /// Who this contact is for: guardian (safety), family (medicines), buddy.
  final String role;
  const Guardian(this.name, this.phone, [this.role = 'guardian']);

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'role': role};
  factory Guardian.fromJson(Map<String, dynamic> j) =>
      Guardian(j['name'] as String, j['phone'] as String, j['role'] as String? ?? 'guardian');
}

class Settings {
  String name = '';
  String lang = 'en';
  List<Guardian> guardians = [];
  List<String> phrases = ['Did you feed the cat'];
  bool shakeToStart = true;
  bool homeMode = false;
  bool voiceCompanion = true;
  bool demoMode = true;
  String companionName = 'Riya';
  LatLon? home;
  bool onboarded = false;

  /// Enabled presets; the first is the main one.
  List<String> presets = [];

  /// Prescription Agent: set up by a caregiver for someone else.
  bool caregiver = false;
  String? patientName;

  List<Guardian> contacts(String role) => guardians.where((g) => g.role == role).toList();

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'guardians': guardians.map((g) => g.toJson()).toList(),
        'phrases': phrases,
        'shake': shakeToStart,
        'homeMode': homeMode,
        'voice': voiceCompanion,
        'demo': demoMode,
        'companion': companionName,
        'home': home == null ? null : [home!.lat, home!.lon],
        'onboarded': onboarded,
        'presets': presets,
        'caregiver': caregiver,
        'patient': patientName,
      };

  static Settings fromJson(Map<String, dynamic> j) {
    final s = Settings()
      ..name = j['name'] as String? ?? ''
      ..lang = j['lang'] as String? ?? 'en'
      ..guardians = [
        for (final g in (j['guardians'] as List? ?? []))
          Guardian.fromJson(g as Map<String, dynamic>)
      ]
      ..phrases = (j['phrases'] as List? ?? ['Did you feed the cat']).cast<String>()
      ..shakeToStart = j['shake'] as bool? ?? true
      ..homeMode = j['homeMode'] as bool? ?? false
      ..voiceCompanion = j['voice'] as bool? ?? true
      ..demoMode = j['demo'] as bool? ?? true
      ..companionName = j['companion'] as String? ?? 'Riya'
      ..onboarded = j['onboarded'] as bool? ?? false
      ..caregiver = j['caregiver'] as bool? ?? false
      ..patientName = j['patient'] as String?;
    // Migration: set-ups from before presets were Women Companion.
    final ps = j['presets'] as List?;
    s.presets = ps == null ? (s.onboarded ? ['women'] : []) : ps.cast<String>();
    final h = j['home'] as List?;
    if (h != null) s.home = LatLon((h[0] as num).toDouble(), (h[1] as num).toDouble());
    return s;
  }
}

class LogEntry {
  final DateTime at;
  final String text;
  const LogEntry(this.at, this.text);
}

/// One Locker recording: an encrypted evidence chain written as it records.
class Recording {
  final String id;
  final String title;
  final DateTime startedAt;
  DateTime? endedAt;
  final EvidenceChain chain;
  bool interrupted = false;
  LatLon? first;
  LatLon? last;
  int gpsPoints = 0;
  int audioChunks = 0;
  int photos = 0;

  Recording(this.id, this.title, this.startedAt, this.chain);

  bool get inProgress => endedAt == null && !interrupted;
  Duration get audioLength => Duration(seconds: audioChunks * 5);
}

enum SessionKind { wingman, journey, followed }

class Session {
  final SessionKind kind;
  final DateTime startedAt;
  final Ladder ladder;
  final ThreatJudge judge = ThreatJudge();
  final Recording recording;
  final Duration checkInEvery;
  JourneyMonitor? journey;
  List<LatLon> route = const [];
  String? destination;
  DateTime nextCheckIn;

  /// After the call ends Winger says nothing and only listens.
  bool listenOnly = false;

  /// Duress PIN entered: everything looks stopped, alerts carry on.
  bool duress = false;
  int guardiansAlerted = 0;
  bool silentAlertSent = false;
  LatLon? location;

  Session({
    required this.kind,
    required this.startedAt,
    required this.recording,
    required this.checkInEvery,
    LadderWindows windows = const LadderWindows(),
  })  : ladder = Ladder(windows: windows),
        nextCheckIn = startedAt.add(checkInEvery);
}
