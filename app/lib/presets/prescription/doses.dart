import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arbiter.dart';
import '../../core/dose_book.dart';
import '../../core/presets.dart';
import '../../core/schedule.dart';
import '../../state/app_state.dart';

/// Prescription Agent: runs each dose's ladder (remind, nudge at +30 min,
/// family at +60 min) and the Taken / Taken some / Snooze answers.
///
/// Family messages go from the phone (simulated on web). While a safety
/// alert is on screen they are held back and sent afterwards: a dose never
/// delays or hides a safety escalation.
class Doses {
  Doses(this.app);
  final AppState app;

  DoseBook? _book;
  final List<(String occurrenceId, String body)> _held = [];

  DoseBook get book => _book ??= DoseBook(_steps)..onStep = _onStep;

  List<LadderStep> get _steps =>
      app.presets['prescription']?.ladder ??
      [
        LadderStep('remind', Duration.zero, [const ActionSpec('notify'), const ActionSpec('speak'), const ActionSpec('checkin')]),
        const LadderStep('nudge', Duration(minutes: 30), [ActionSpec('notify'), ActionSpec('speak')]),
        const LadderStep('contact', Duration(minutes: 60), [ActionSpec('message_contacts', 'family')]),
      ];

  bool get hindi => app.settings.lang == 'hi';

  /// Who the medicines are for ("you" or the patient's name).
  String get patient => app.settings.caregiver ? (app.settings.patientName ?? 'your patient') : app.settings.name;

  // ---------------------------------------------------------------- storage

  Future<void> load(SharedPreferences p) async {
    final meds = p.getString('medicines');
    final log = p.getString('doselog');
    _book = DoseBook(
      _steps,
      medicines: meds == null ? [] : [for (final m in jsonDecode(meds) as List) Medicine.fromJson(m)],
      log: log == null ? [] : [for (final e in jsonDecode(log) as List) DoseEvent.fromJson(e)],
    )..onStep = _onStep;
  }

  Future<void> save(SharedPreferences p) async {
    final b = book;
    await p.setString('medicines', jsonEncode(b.medicines.map((m) => m.toJson()).toList()));
    final keep = b.log.length > 1000 ? b.log.sublist(b.log.length - 1000) : b.log;
    await p.setString('doselog', jsonEncode(keep.map((e) => e.toJson()).toList()));
  }

  void _persist() {
    app.save();
    app.changed();
  }

  // ----------------------------------------------------------------- engine

  void tick(DateTime now) => book.tick(now);

  String _list(Occurrence o) => o.medIds.map((id) => book.med(id)?.label ?? id).join(', ');

  void _onStep(Occurrence o, LadderStep step) {
    final now = app.now();
    final kind = step.id == 'remind'
        ? DoseEventKind.reminded
        : step.has('message_contacts')
            ? DoseEventKind.contacted
            : DoseEventKind.nudged;
    if (step.has('notify')) {
      app.note(step.id == 'remind' ? 'Medicine time: ${_list(o)}' : 'Reminder again: ${_list(o)} not taken yet');
      app.alerts.vibrate();
    }
    if (step.has('speak') && app.settings.voiceCompanion && !app.showCheckIn) {
      app.voice.say(
        hindi ? 'दवा का समय। ${_list(o)}।' : 'Time for your medicine: ${_list(o)}.',
        lang: app.settings.lang,
      );
    }
    if (step.has('message_contacts')) {
      final role = step.actions.firstWhere((a) => a.kind == 'message_contacts').arg ?? 'family';
      final body = 'Winger: $patient has not confirmed the ${DayTime(o.due.hour, o.due.minute).label} '
          'medicines (${_list(o)}). Please check on them.';
      if (app.arbiter.holds(Priority.health)) {
        _held.add((o.id, body));
        book.record(DoseEvent(now, o.id, DoseEventKind.held));
        app.note('Family message held until the safety alert is over');
      } else {
        _send(role, o.id, body);
        book.record(DoseEvent(now, o.id, kind));
      }
    } else {
      book.record(DoseEvent(now, o.id, kind));
    }
    _persist();
  }

  Future<void> _send(String role, String occurrenceId, String body) async {
    final to = app.settings.contacts(role);
    if (to.isEmpty) {
      app.note('No family contact set, so nobody was told');
      return;
    }
    for (final c in to) {
      final real = await app.alerts.sendSms(c.phone, body);
      app.note('SMS to ${c.name}${real ? '' : ' (simulated)'}: $body');
    }
  }

  /// The safety alert ended: send what was held back.
  void releaseHeld() {
    if (_held.isEmpty) return;
    for (final (id, body) in _held) {
      _send('family', id, body);
      book.record(DoseEvent(app.now(), id, DoseEventKind.contacted));
    }
    _held.clear();
    _persist();
  }

  int get heldCount => _held.length;

  /// Doses waiting for an answer join the arbiter's queue.
  void syncArbiter(DateTime now) {
    if (!app.enabled('prescription')) return;
    for (final o in book.today(now)) {
      if (o.needsAnswer(now) && o.ladder.started) {
        app.arbiter.add(CheckInRequest(o.id, Priority.health, o.due));
      } else {
        app.arbiter.remove(o.id);
      }
    }
  }

  Occurrence? byId(String id) => book.today(app.now()).where((o) => o.id == id).firstOrNull;

  // ---------------------------------------------------------------- answers

  void takeAll(Occurrence o) {
    book.markTaken(o, app.now());
    app.arbiter.remove(o.id);
    app.note('Taken: ${_list(o)}');
    app.voice.stop();
    _persist();
  }

  void takeSome(Occurrence o, Set<String> ids) {
    book.markTaken(o, app.now(), ids: ids);
    if (o.allTaken) app.arbiter.remove(o.id);
    app.note('Taken: ${ids.map((i) => book.med(i)?.label ?? i).join(', ')}');
    _persist();
  }

  bool snooze(Occurrence o) {
    final ok = book.snooze(o, app.now());
    if (ok) {
      app.arbiter.remove(o.id);
      app.note('Snoozed 10 min');
      app.voice.stop();
      _persist();
    }
    return ok;
  }

  // ------------------------------------------------------------- medicines

  void addMedicine(Medicine m) {
    book.medicines.add(m);
    app.note('Medicine added: ${m.label}');
    _persist();
  }

  void removeMedicine(String id) {
    book.medicines.removeWhere((m) => m.id == id);
    _persist();
  }

  /// Demo only: a pre-checked prescription and a family contact.
  void seedDemo() {
    final today = app.now();
    final start = DateTime(today.year, today.month, today.day);
    book.medicines
      ..clear()
      ..addAll([
        Medicine(
            id: 'metformin',
            name: 'Metformin',
            strength: '500 mg',
            note: 'After food',
            schedule: Schedule(times: [const DayTime(9, 0), const DayTime(21, 0)], start: start)),
        Medicine(
            id: 'amlodipine',
            name: 'Amlodipine',
            strength: '5 mg',
            note: 'Morning',
            schedule: Schedule(times: [const DayTime(9, 0)], start: start)),
        Medicine(
            id: 'atorvastatin',
            name: 'Atorvastatin',
            strength: '10 mg',
            note: 'Night',
            schedule: Schedule(times: [const DayTime(21, 0)], start: start)),
      ]);
    if (app.settings.contacts('family').isEmpty) {
      app.settings.guardians = [...app.settings.guardians, const Guardian('Rahul (son)', '+91 98000 00002', 'family')];
    }
    if (!app.enabled('prescription')) app.settings.presets = [...app.settings.presets, 'prescription'];
    app.note('Demo prescription loaded');
    _persist();
  }
}
