import '../../domain/mention.dart';
import '../../domain/sig.dart';
import '../visit/visit.dart';

enum WizardStep {
  doctorWords,
  doctorTakeaways,
  photos,
  pharmacyWords,
  chemistTakeaways,
  processing,
  medicines,
  placement,
}

/// The points a doctor confirms for one medicine, in seconds.
enum CheckPoint { name, dose, timing, food, duration, purpose }

enum CheckState { unchecked, confirmed, notProvided }

/// One row a person validates on the takeaways steps.
class Takeaway {
  Takeaway({
    required this.name,
    required this.sig,
    required this.sourceText,
    required this.ticked,
    required this.clear,
    this.isNote = false,
    this.purpose,
  }) : checks = {
         CheckPoint.name: CheckState.unchecked,
         // The amount is always asked: the default of one tablet is the
         // parser's, not the doctor's.
         CheckPoint.dose: CheckState.unchecked,
         CheckPoint.timing: sig.hasTiming
             ? CheckState.unchecked
             : CheckState.notProvided,
         CheckPoint.food: sig.food != FoodTiming.unspecified
             ? CheckState.unchecked
             : CheckState.notProvided,
         CheckPoint.duration: sig.durationDays != null || sig.everyNDays != null
             ? CheckState.unchecked
             : CheckState.notProvided,
         CheckPoint.purpose: purpose != null
             ? CheckState.unchecked
             : CheckState.notProvided,
       };

  factory Takeaway.note(String text) => Takeaway(
    name: text,
    sig: Sig.empty,
    sourceText: '',
    ticked: false,
    clear: true,
    isNote: true,
  );

  /// As it was said — "Telma 40".
  String name;
  Sig sig;

  /// What goes to the analyser. The original words until a person edits the
  /// row; after that, the name and the edited instruction.
  String sourceText;
  bool ticked;

  /// Parsed with nothing left over, and with a time.
  bool clear;

  /// Advice, not a medicine. Kept visible; never becomes a dose.
  final bool isNote;

  /// The raw instruction when the parser could not make sense of it, so the
  /// row shows the words themselves rather than a confident guess.
  String? rawInstruction;

  /// Quoted from the doctor, never inferred.
  String? purpose;

  /// Doctor mode: one answer per point. A point with nothing extracted
  /// starts as "not provided" — that is what was heard, not a guess.
  final Map<CheckPoint, CheckState> checks;

  /// Every point answered, and the medicine itself confirmed. Anything less
  /// is an unverified row, and is treated exactly like an unticked one.
  bool get doctorVerified =>
      checks[CheckPoint.name] == CheckState.confirmed &&
      checks.values.every((c) => c != CheckState.unchecked);

  bool get anyUnchecked => checks.values.contains(CheckState.unchecked);
}

/// A photo in the photo step, before it becomes part of the visit.
class PhotoCandidate {
  PhotoCandidate({
    required this.path,
    required this.label,
    this.selected = true,
    this.ocrText,
    this.evidence = const [],
    this.reason,
  });

  final String path;
  PhotoLabel label;

  /// Only ticked photos enter the visit, and only when the step is left.
  bool selected;

  /// Read once, and reused by extraction.
  String? ocrText;
  bool reading = false;
  bool unreadable = false;

  /// The words that decided the label — shown, so the label can be checked.
  List<String> evidence;

  /// Why it was turned away, when it was.
  String? reason;
}

/// What a person decided about one medicine card.
class MedicineDecision {
  bool confirmed = false;
  bool leftOut = false;

  /// On a red card, the side the person picked for *when* to take it.
  Mention? chosen;

  /// The reading a person picked for *what* the medicine is — its name and
  /// strength. Set by a pick on the card or an answer to a pharmacy question;
  /// the timing still comes from the doctor and the prescription.
  Mention? identity;

  /// A person said the bill's count is right, so the course is as many days
  /// as the tablets sold last.
  int? courseDays;

  /// This bill row is the same medicine as another card — the stand-in a
  /// person accepted — and is counted there, not twice.
  String? foldedInto;

  /// Set by an answer rather than a tap, so a later answer can undo it.
  bool identityByAnswer = false;
  bool outByAnswer = false;

  /// A person's own fix, which beats every source.
  String? editedName;
  Sig? editedSig;

  bool get decided => confirmed || leftOut;
}
