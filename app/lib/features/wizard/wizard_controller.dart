import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../../ai/ai_config.dart';
import '../../domain/content_gate.dart';
import '../../domain/mention.dart';
import '../../domain/mention_extractor.dart';
import '../../domain/merge_engine.dart';
import '../../domain/offline_analyser.dart';
import '../../domain/pharmacy_check.dart';
import '../../domain/placement_advisor.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../../domain/sig_parser.dart';
import '../../platform/text_recogniser.dart';
import '../medicines/medicine_store.dart';
import '../sync/sync_queue.dart';
import '../sync/sync_service.dart';
import '../visit/media_store.dart';
import '../visit/visit.dart';
import '../visit/visit_repository.dart';
import 'wizard_models.dart';

/// Everything the eight-step "new prescription" wizard knows and decides,
/// with no widgets in it — so every step can be driven by a test, and the
/// goldens show what the real controller produced rather than a mock-up.
class VisitWizardController extends ChangeNotifier {
  VisitWizardController({
    required this.visit,
    required this.repository,
    required this.store,
    MediaStore? media,
    TextRecogniser? recogniser,
    DateTime Function()? clock,
    this.sync,
    bool? readOnlineLater,
  }) : _clock = clock ?? DateTime.now,
       _readOnlineLater = readOnlineLater ?? AiConfig.hasGeminiKey {
    _media = media;
    _recogniser = recogniser;
  }

  final Visit visit;
  final VisitRepository repository;
  final MedicineStore store;
  final DateTime Function() _clock;

  // Built lazily: both touch the platform.
  MediaStore? _media;
  MediaStore get media => _media ??= MediaStore();
  TextRecogniser? _recogniser;
  TextRecogniser get recogniser => _recogniser ??= TextRecogniser();

  WizardStep _step = WizardStep.doctorWords;
  WizardStep get step => _step;
  int get stepNumber => _step.index + 1;
  static int get stepCount => WizardStep.values.length;

  // ── Navigation ──────────────────────────────────────────────────────────

  bool get canGoBack => _step.index > 0;

  /// Why Next is locked, or null when it is not.
  bool get canGoNext => switch (_step) {
    WizardStep.photos => photosReady,
    WizardStep.processing => analysis != null && !_analysing,
    WizardStep.medicines => allDecided && keptRows.isNotEmpty,
    WizardStep.placement => placements.isNotEmpty,
    _ => true,
  };

  /// Honest only where the step really is optional.
  bool get canSkip => switch (_step) {
    WizardStep.doctorWords || WizardStep.pharmacyWords => true,
    WizardStep.doctorTakeaways || WizardStep.chemistTakeaways => true,
    _ => false,
  };

  Future<void> next() async {
    if (!canGoNext || _step == WizardStep.placement) return;
    await _leave(_step);
    _step = WizardStep.values[_step.index + 1];
    await _enter(_step);
    notifyListeners();
  }

  Future<void> skip() async {
    if (!canSkip) return;
    // A skipped step is recorded as "not provided": never blank, never
    // guessed.
    if (!visit.notProvided.contains(_step.name)) {
      visit.notProvided.add(_step.name);
    }
    if (_step == WizardStep.doctorWords) {
      visit.notProvided.add(WizardStep.doctorTakeaways.name);
    } else if (_step == WizardStep.pharmacyWords) {
      visit.notProvided.add(WizardStep.chemistTakeaways.name);
    }
    // Skipping the words skips their checkpoint as well.
    if (_step == WizardStep.doctorWords) {
      _step = WizardStep.photos;
    } else if (_step == WizardStep.pharmacyWords) {
      _step = WizardStep.processing;
      await _enter(_step);
    } else {
      await _leave(_step);
      _step = WizardStep.values[_step.index + 1];
      await _enter(_step);
    }
    notifyListeners();
  }

  void back() {
    if (!canGoBack) return;
    _step = WizardStep.values[_step.index - 1];
    notifyListeners();
  }

  Future<void> _enter(WizardStep s) async {
    switch (s) {
      case WizardStep.doctorTakeaways:
        _refreshTakeaways(SourceKind.doctor);
      case WizardStep.chemistTakeaways:
        _refreshTakeaways(SourceKind.chemist);
      case WizardStep.processing:
        await runAnalysis();
      case WizardStep.placement:
        _placeMedicines();
      default:
    }
  }

  Future<void> _leave(WizardStep s) async {
    if (s == WizardStep.photos) await commitPhotos();
    await repository.save(visit);
  }

  // ── Steps 1 and 4: words ────────────────────────────────────────────────

  // ── Offline ────────────────────────────────────────────────────────────

  /// Saves the session when there is no signal, and syncs later. Optional:
  /// without it, everything still works on the phone.
  final SyncService? sync;

  /// Queue the online handwriting read when there is no signal at approval.
  final bool _readOnlineLater;

  /// True once a capture happened with no connection. The screen shows a
  /// banner; nothing is blocked.
  bool offline = false;

  /// Called after every capture: saved already, so only check the signal.
  Future<void> _captured() async {
    final s = sync;
    if (s == null) return;
    final online = await s.network.isOnline();
    if (online == !offline) return;
    offline = !online;
    if (offline) await s.savedOffline();
    notifyListeners();
  }

  void setWords(SourceKind who, String text) {
    if (who == SourceKind.doctor) {
      visit.doctorWords = text;
    } else {
      visit.chemistWords = text;
    }
    repository.save(visit);
    notifyListeners();
    _captured();
  }

  String wordsOf(SourceKind who) =>
      who == SourceKind.doctor ? visit.doctorWords : visit.chemistWords;

  Future<void> keepAudio(SourceKind who, XFile file) async {
    final name = who == SourceKind.doctor ? 'doctor' : 'chemist';
    final path = await media.keep(visit.id, file, name: name);
    if (who == SourceKind.doctor) {
      visit.doctorAudioPath = path;
    } else {
      visit.chemistAudioPath = path;
    }
    await repository.save(visit);
    notifyListeners();
    await _captured();
  }

  /// Forget a kept recording: deleted, or about to be recorded again.
  Future<void> dropAudio(SourceKind who) async {
    if (who == SourceKind.doctor) {
      visit.doctorAudioPath = null;
    } else {
      visit.chemistAudioPath = null;
    }
    await repository.save(visit);
    notifyListeners();
  }

  // ── Steps 2 and 5: takeaways ────────────────────────────────────────────

  final Map<SourceKind, List<Takeaway>> _takeaways = {};
  final Map<SourceKind, String> _takeawaysFrom = {};

  List<Takeaway> takeaways(SourceKind who) => _takeaways[who] ?? const [];

  /// Rebuilt only when the words changed, so a person's ticks and edits
  /// survive going back a step and forward again.
  void _refreshTakeaways(SourceKind who) {
    final words = wordsOf(who);
    if (_takeawaysFrom[who] == words && _takeaways.containsKey(who)) return;
    _takeawaysFrom[who] = words;
    final x = MentionExtractor.extractWithNotes(words, who);
    _takeaways[who] = [
      for (final m in x.mentions) _takeawayOf(m),
      for (final n in x.notes) Takeaway.note(n),
    ];
  }

  static Takeaway _takeawayOf(Mention m) {
    final clear = m.sig.isClear && m.sig.hasTiming && !m.needsCorroboration;
    final t = Takeaway(
      name: _asSaid(m),
      sig: m.sig,
      sourceText: m.raw,
      ticked: clear,
      clear: clear,
      purpose: m.purpose,
    );
    if (!m.sig.isClear || !m.sig.hasTiming) {
      // Show the words themselves, not a confident reading of them.
      final rest = SigParser.normalise(m.raw)
          .replaceFirst(SigParser.normalise(m.name), '');
      t.rawInstruction = rest.trim().isEmpty ? null : _sentence(rest.trim());
    }
    return t;
  }

  static String _asSaid(Mention m) => m.name
      .split(' ')
      .map(
        (w) => RegExp(r'^\d').hasMatch(w) || w.length <= 2
            ? w
            : w[0] + w.substring(1).toLowerCase(),
      )
      .join(' ');

  static String _sentence(String s) => s[0].toUpperCase() + s.substring(1);

  void toggleTakeaway(SourceKind who, int i) {
    final t = _takeaways[who]![i];
    t.ticked = !t.ticked;
    notifyListeners();
  }

  /// A person's fix. The row is then clear by definition: a human wrote it.
  void editTakeaway(SourceKind who, int i, String name, String instruction) {
    final t = _takeaways[who]![i];
    final line = '$name $instruction'.trim();
    final parsed = SigParser.parseLine(line);
    t
      ..name = name.trim()
      ..sig = parsed.sig
      ..sourceText = line
      ..rawInstruction = parsed.sig.isClear ? null : instruction.trim()
      ..clear = parsed.sig.isClear && parsed.sig.hasTiming
      ..ticked = true;
    notifyListeners();
  }

  void addTakeaway(SourceKind who, String name, String instruction) {
    _takeaways.putIfAbsent(who, () => []);
    _takeaways[who]!.add(
      Takeaway(
        name: name,
        sig: Sig.empty,
        sourceText: '',
        ticked: true,
        clear: false,
      ),
    );
    editTakeaway(who, _takeaways[who]!.length - 1, name, instruction);
  }

  /// What the analyser hears from a person: only the ticked medicine rows.
  String _validatedText(SourceKind who) {
    final rows = _takeaways[who];
    if (rows == null) return wordsOf(who);
    if (who == SourceKind.doctor && verifier == Verifier.doctor) {
      return [
        for (final t in rows)
          if (!t.isNote && t.doctorVerified) doctorLine(t),
      ].join('\n');
    }
    return [
      for (final t in rows)
        if (t.ticked && !t.isNote && t.sourceText.isNotEmpty) t.sourceText,
    ].join('\n');
  }

  // ── Step 2: who verifies ────────────────────────────────────────────────

  /// Me until someone says the doctor is checking.
  Verifier get verifier => visit.verifiedBy ?? Verifier.me;

  void setVerifier(Verifier v) {
    visit.verifiedBy = v;
    repository.save(visit);
    notifyListeners();
  }

  void setCheck(SourceKind who, int i, CheckPoint point, CheckState state) {
    _takeaways[who]![i].checks[point] = state;
    notifyListeners();
  }

  /// What a doctor-verified row tells the analysis: only the points they
  /// confirmed. A point marked "not provided" is left out, so the merge sees
  /// it as missing — an amber card, not a guess.
  static String doctorLine(Takeaway t) {
    bool ok(CheckPoint p) => t.checks[p] == CheckState.confirmed;
    final sig = t.sig;
    final parts = <String>[t.name];
    if (ok(CheckPoint.timing)) {
      if (sig.sos) {
        parts.add('SOS');
      } else if (sig.stat) {
        parts.add('STAT');
      } else {
        parts.addAll(sig.slots.map((s) => s.name));
      }
    }
    if (ok(CheckPoint.dose) && sig.unitsPerDose != 1) {
      parts.add(
        sig.unitsPerDose == .5
            ? 'half tablet'
            : '${sig.unitsPerDose.round()} tablets',
      );
    }
    if (ok(CheckPoint.food)) {
      if (sig.food == FoodTiming.before) parts.add('before food');
      if (sig.food == FoodTiming.after) parts.add('after food');
    }
    if (ok(CheckPoint.duration)) {
      if (sig.everyNDays != null) parts.add('every ${sig.everyNDays} days');
      if (sig.durationDays != null) parts.add('for ${sig.durationDays} days');
    }
    if (ok(CheckPoint.purpose) && t.purpose != null) {
      parts.add('${t.purpose} ke liye');
    }
    return parts.join(' ');
  }

  // ── Note for the caretaker ─────────────────────────────────────────────

  void setCaretakerNote(String text) {
    visit.caretakerNote = text;
    repository.save(visit);
    notifyListeners();
  }

  void setNotePriority(NotePriority p) {
    visit.notePriority = p;
    repository.save(visit);
    notifyListeners();
  }

  // ── Step 3: photos ──────────────────────────────────────────────────────

  final List<PhotoCandidate> candidates = [];
  int ocrReads = 0;

  int get selectedCount => candidates.where((c) => c.selected).length;

  bool get photosReady =>
      candidates.any((c) => c.selected && c.label == PhotoLabel.prescription) ||
      visit.hasPrescription;

  /// Add photos from the camera, the gallery or the recent-photo scan, and
  /// read each one straight away. [hint] is what the user said it is.
  Future<void> addPhotos(Iterable<XFile> files, {PhotoLabel? hint}) async {
    unawaited(_captured());
    final added = <PhotoCandidate>[];
    for (final f in files) {
      final c = PhotoCandidate(
        path: f.path,
        label: hint ?? PhotoLabel.prescription,
      );
      candidates.add(c);
      added.add(c);
    }
    notifyListeners();
    for (final c in added) {
      await _read(c, hinted: hint != null);
    }
  }

  /// Add a candidate whose text was already read — the recent-photo scan
  /// reads while it labels, and that text is reused here, never read twice.
  void addReadCandidate(String path, String text) {
    final c = PhotoCandidate(path: path, label: PhotoLabel.prescription);
    c.ocrText = text;
    _label(c, ContentGate.judgeText(text), hinted: false);
    candidates.add(c);
    notifyListeners();
  }

  Future<void> _read(PhotoCandidate c, {required bool hinted}) async {
    if (c.ocrText != null) return; // read once
    c.reading = true;
    notifyListeners();
    final result = await recogniser.read(c.path);
    ocrReads++;
    c.reading = false;
    if (result.unsupported) {
      // Keep it, as the user labelled it, and say it could not be read.
      c.unreadable = true;
      c.selected = true;
    } else {
      c.ocrText = result.text;
      _label(c, ContentGate.judgeText(result.text), hinted: hinted);
    }
    notifyListeners();
  }

  void _label(PhotoCandidate c, ContentVerdict v, {required bool hinted}) {
    c.evidence = v.evidence;
    switch (v.kind) {
      case ContentKind.prescription:
        c.label = PhotoLabel.prescription;
      case ContentKind.bill:
        c.label = PhotoLabel.bill;
      case ContentKind.medicineStrip:
        c.label = PhotoLabel.strip;
      case ContentKind.medicalOther:
        if (!hinted) c.label = PhotoLabel.prescription;
      case ContentKind.notMedical:
        // Never hidden: unticked, with the reason shown, and overridable.
        c.selected = false;
        c.reason = 'notMedical';
    }
  }

  void setLabel(PhotoCandidate c, PhotoLabel label) {
    c.label = label;
    c.selected = true;
    notifyListeners();
  }

  void toggleSelected(PhotoCandidate c) {
    c.selected = !c.selected;
    notifyListeners();
  }

  /// Only ticked photos enter the visit, and only now, when the step is left.
  /// Scanning is an assistant, not an import.
  Future<void> commitPhotos() async {
    final paths = visit.photos.map((p) => p.path).toSet();
    for (final c in candidates.where((c) => c.selected)) {
      if (paths.contains(c.path)) continue;
      final kept = await media.keep(
        visit.id,
        XFile(c.path),
        name: '${c.label.name}_${visit.photos.length + 1}',
      );
      visit.photos.add(
        VisitPhoto(path: kept, label: c.label, ocrText: c.ocrText),
      );
    }
    await repository.save(visit);
  }

  // ── Step 6: processing ──────────────────────────────────────────────────

  AnalysisResult? analysis;
  bool _analysing = false;
  bool get analysing => _analysing;

  /// Rows read online (with consent) that join the same merge.
  final List<Mention> onlineMentions = [];

  Future<void> runAnalysis() async {
    _analysing = true;
    notifyListeners();
    final texts = <SourceText>[
      SourceText(SourceKind.doctor, _validatedText(SourceKind.doctor)),
      SourceText(SourceKind.chemist, _validatedText(SourceKind.chemist)),
      for (final p in visit.photos)
        if (p.ocrText != null && _sourceOf(p.label) != null)
          SourceText(_sourceOf(p.label)!, p.ocrText!),
    ];
    analysis = OfflineAnalyser.analyse(texts, extra: onlineMentions);
    decisions
      ..clear()
      ..addEntries(
        analysis!.rows.map((r) => MapEntry(r.id, MedicineDecision())),
      );
    pharmacyIssues = PharmacyCheck.find(
      rows: analysis!.rows,
      chemistWords: visit.chemistWords,
      unreadable: analysis!.unreadable,
    );
    // A new analysis asks again whatever is still unanswered, and the
    // answers already given are applied to the new cards.
    _asked.clear();
    _applyAnswers();
    _analysing = false;
    notifyListeners();
  }

  static SourceKind? _sourceOf(PhotoLabel l) => switch (l) {
    PhotoLabel.prescription => SourceKind.prescription,
    PhotoLabel.bill => SourceKind.bill,
    PhotoLabel.strip => SourceKind.strip,
    PhotoLabel.medicalOther => SourceKind.prescription,
    PhotoLabel.notMedical => null,
  };

  // ── Step 7: medicines ───────────────────────────────────────────────────

  final Map<String, MedicineDecision> decisions = {};

  List<MergedMedicine> get rows => analysis?.rows ?? const [];

  MedicineDecision decisionOf(MergedMedicine m) =>
      decisions.putIfAbsent(m.id, MedicineDecision.new);

  /// Every card confirmed or left out, and every unreadable line answered.
  bool get allDecided =>
      rows.every((r) => decisionOf(r).decided) &&
      unreadableLines.every(isSettled);

  List<MergedMedicine> get keptRows =>
      rows.where((r) => !decisionOf(r).leftOut).toList();

  /// Disagreements about *what* the medicine is. The rest are about *when*.
  static const _identityFields = {
    ConflictField.strength,
    ConflictField.notPrescribed,
  };

  /// A red card cannot be confirmed until a person has picked a side for
  /// every disagreement on it, and while any pharmacy question on it is still
  /// open. A person's own edit settles all of it.
  bool canConfirm(MergedMedicine m) {
    final d = decisionOf(m);
    if (d.editedSig != null) return true;
    if (openIssuesOf(m).isNotEmpty) return false;
    if (m.verdict != Verdict.red) return true;
    return m.conflicts.every(
      (c) => _identityFields.contains(c.field)
          ? d.identity != null
          : d.chosen != null,
    );
  }

  void confirm(MergedMedicine m) {
    if (!canConfirm(m)) return;
    final d = decisionOf(m);
    d
      ..confirmed = !d.confirmed
      ..leftOut = false;
    notifyListeners();
  }

  /// A side picked on the card. A reading of the strength settles what the
  /// medicine is; a reading of the timing settles when to take it.
  void choose(MergedMedicine m, Mention side) {
    final d = decisionOf(m);
    bool picks(bool Function(ConflictField) field) =>
        m.conflicts.any((c) => field(c.field) && c.sides.contains(side));
    final identity = picks(_identityFields.contains);
    final timing = picks((f) => !_identityFields.contains(f));
    if (identity) {
      d
        ..identity = side
        ..identityByAnswer = false;
    }
    if (timing || !identity) d.chosen = side;
    d
      ..leftOut = false
      ..outByAnswer = false
      ..confirmed = canConfirm(m);
    notifyListeners();
  }

  void leaveOut(MergedMedicine m) {
    final d = decisionOf(m);
    d
      ..leftOut = !d.leftOut
      ..outByAnswer = false
      ..foldedInto = null
      ..confirmed = false;
    notifyListeners();
  }

  void editRow(MergedMedicine m, String name, String instruction) {
    final parsed = SigParser.parseLine('$name $instruction');
    decisionOf(m)
      ..editedName = name.trim().toUpperCase()
      ..editedSig = parsed.sig.copyWith(unresolved: const [])
      ..confirmed = true
      ..leftOut = false;
    notifyListeners();
  }

  /// The Sig that will reach the schedule: a person's fix, else the side
  /// they chose, else what the evidence proposed — with the course shortened
  /// only when a person said the bill's count is right.
  Sig finalSig(MergedMedicine m) {
    final d = decisionOf(m);
    if (d.editedSig != null) return d.editedSig!;
    var sig = (d.chosen?.sig ?? m.sig).copyWith(unresolved: const []);
    if (d.courseDays != null) sig = sig.copyWith(durationDays: d.courseDays);
    return sig;
  }

  String finalName(MergedMedicine m) {
    final d = decisionOf(m);
    return d.editedName ?? d.identity?.name ?? m.name;
  }

  String? finalStrength(MergedMedicine m) {
    final d = decisionOf(m);
    return d.editedName == null && d.identity != null
        ? d.identity!.strength
        : m.strength;
  }

  // ── Step 7: pharmacy questions ──────────────────────────────────────────

  /// What the counter may have got wrong, found when the analysis ran.
  List<PharmacyIssue> pharmacyIssues = const [];

  /// Popped up once per analysis. Closing a pop-up answers nothing.
  final Set<String> _asked = {};

  List<PharmacyIssue> get unreadableLines => [
    for (final i in pharmacyIssues)
      if (i.kind == PharmacyIssueKind.unreadable) i,
  ];

  /// The latest answer to a question, or null if nobody answered it.
  PharmacyResolution? resolutionOf(PharmacyIssue i) {
    for (final r in visit.pharmacyResolutions.reversed) {
      if (r.key == i.key) return r;
    }
    return null;
  }

  /// Settled by an A or B answer, or by a person acting on the card itself:
  /// their own edit, or a pick of what the medicine is. "Not sure" and an
  /// explanation settle nothing.
  bool isSettled(PharmacyIssue i) {
    if (resolutionOf(i)?.settles ?? false) return true;
    final row = _row(i.medicineId);
    if (row == null) return false;
    final d = decisionOf(row);
    if (d.editedSig != null) return true;
    return (i.kind == PharmacyIssueKind.strength ||
            i.kind == PharmacyIssueKind.notPrescribed) &&
        d.identity != null;
  }

  List<PharmacyIssue> issuesOf(MergedMedicine m) => [
    for (final i in pharmacyIssues)
      if (i.medicineId == m.id || i.otherId == m.id) i,
  ];

  List<PharmacyIssue> openIssuesOf(MergedMedicine m) =>
      issuesOf(m).where((i) => !isSettled(i)).toList();

  /// Red while any question on the card is open — never quietly green.
  Verdict verdictOf(MergedMedicine m) =>
      openIssuesOf(m).isNotEmpty ? Verdict.red : m.verdict;

  /// The questions to pop up now, in order: never answered, not shown since
  /// the analysis ran, and not already settled on the card.
  List<PharmacyIssue> get questionsToAsk => [
    for (final i in pharmacyIssues)
      if (resolutionOf(i) == null && !_asked.contains(i.key) && !isSettled(i))
        i,
  ];

  void markAsked(PharmacyIssue i) => _asked.add(i.key);

  /// A person's answer. Kept on the visit whatever it is; only A or B
  /// changes a card, and it does so as a person's decision.
  Future<void> answer(
    PharmacyIssue i,
    PharmacyChoice choice, {
    String explanation = '',
    XFile? voiceNote,
    AnsweredBy answeredBy = AnsweredBy.patient,
  }) async {
    _asked.add(i.key);
    String? path;
    if (voiceNote != null) {
      path = await media.keep(
        visit.id,
        voiceNote,
        name: 'pharmacy_${i.kind.name}_${visit.pharmacyResolutions.length + 1}',
      );
    }
    visit.pharmacyResolutions.add(
      PharmacyResolution(
        kind: i.kind,
        medicineId: i.medicineId,
        choice: choice,
        explanation: explanation.trim(),
        voiceNotePath: path,
        answeredBy: answeredBy,
        answeredAt: _clock(),
      ),
    );
    _applyAnswers(touched: {i.medicineId, ?i.otherId});
    await repository.save(visit);
    notifyListeners();
  }

  MergedMedicine? _row(String id) =>
      rows.where((r) => r.id == id).firstOrNull;

  /// Undo what earlier answers did, then apply the latest answer to every
  /// question — so "not sure" after an A puts the card back to red.
  void _applyAnswers({Set<String>? touched}) {
    for (final d in decisions.values) {
      if (d.identityByAnswer) {
        d
          ..identity = null
          ..identityByAnswer = false;
      }
      if (d.outByAnswer) {
        d
          ..leftOut = false
          ..outByAnswer = false
          ..foldedInto = null;
      }
      d.courseDays = null;
    }

    void identify(MergedMedicine? m, Mention? side) {
      if (m == null || side == null) return;
      decisionOf(m)
        ..identity = side
        ..identityByAnswer = true;
    }

    void out(MergedMedicine? m, {String? into}) {
      if (m == null) return;
      decisionOf(m)
        ..leftOut = true
        ..outByAnswer = true
        ..confirmed = false
        ..foldedInto = into;
    }

    for (final i in pharmacyIssues) {
      final r = resolutionOf(i);
      if (r == null || !r.settles) continue;
      final pickA = r.choice == PharmacyChoice.a;
      final main = _row(i.medicineId);
      final other = i.otherId == null ? null : _row(i.otherId!);
      switch (i.kind) {
        case PharmacyIssueKind.strength:
          identify(main, pickA ? i.a : i.b);
        case PharmacyIssueKind.substitution:
          // One medicine, two readings of it. The bill's own row is either
          // the wrong medicine (A) or this one under another name (B) — in
          // neither case a second medicine to take.
          identify(main, pickA ? i.a : i.b);
          out(other, into: pickA ? null : main?.id);
        case PharmacyIssueKind.notPrescribed:
          if (pickA) {
            identify(main, i.a);
          } else {
            out(main);
          }
        case PharmacyIssueKind.quantity:
          if (!pickA && main != null) {
            decisionOf(main).courseDays = i.billDays;
          }
        case PharmacyIssueKind.unreadable:
          break;
      }
    }

    for (final m in rows) {
      if (touched != null && !touched.contains(m.id)) continue;
      final mine = issuesOf(m);
      if (mine.isEmpty) continue;
      final d = decisionOf(m);
      if (d.leftOut) continue;
      if (openIssuesOf(m).isNotEmpty) {
        d.confirmed = false;
      } else if (mine.any((i) => resolutionOf(i)?.settles ?? false)) {
        d.confirmed = canConfirm(m);
      }
    }
  }

  // ── Step 8: placement ───────────────────────────────────────────────────

  List<Placement> placements = const [];

  void _placeMedicines() {
    final today = dayOf(_clock());
    placements = PlacementAdvisor.advise(
      incoming: [
        for (final m in keptRows)
          ScheduledMedicine(
            id: MergedMedicine.idFor(finalName(m)),
            name: finalName(m),
            strength: finalStrength(m),
            sig: finalSig(m),
            startDate: today,
            purpose: m.purpose,
          ),
      ],
      existing: store.active(),
      today: today,
    );
  }

  /// Approve and add. Returns the medicines that went onto the schedule.
  Future<List<ScheduledMedicine>> approve() async {
    final approved = [for (final p in placements) p.medicine];
    await store.approve(
      visitId: visit.id,
      approved: approved,
      at: _clock(),
      evidence: [
        for (final s in analysis?.sourcesRead ?? const <SourceKind>{}) s.name,
      ],
      caretakerNote: visit.caretakerNote.trim().isEmpty
          ? null
          : visit.caretakerNote.trim(),
      notePriority: visit.notePriority.name,
    );
    await _queueOnlineRead();
    await repository.clear();
    return approved;
  }

  /// No signal at approval: the handwriting read waits in the queue. What it
  /// finds is attached to this prescription for review — never merged into
  /// the schedule on its own.
  Future<void> _queueOnlineRead() async {
    final s = sync;
    if (s == null || !_readOnlineLater || await s.network.isOnline()) return;
    final photos = [
      for (final p in visit.photosOf(PhotoLabel.prescription)) p.path,
    ];
    if (photos.isEmpty) return;
    await s.enqueue(
      SyncJob(
        id: 'gemini-${visit.id}',
        kind: 'gemini',
        payload: {'photos': photos},
        createdAt: _clock(),
        visitId: visit.id,
      ),
    );
  }

  @override
  void dispose() {
    _recogniser?.close();
    super.dispose();
  }
}
