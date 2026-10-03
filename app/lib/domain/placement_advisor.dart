import 'name_matcher.dart';
import 'schedule_engine.dart';
import 'scheduled_medicine.dart';
import 'sig.dart';

/// Why a new medicine sits where it does.
enum PlacementReason {
  /// The prescription said when. Not moving it.
  kept,

  /// Nobody said when. This is a proposal, and it says so.
  suggested,

  /// Something with a very similar name is already on the schedule.
  duplicate,

  /// This slot already carries several medicines.
  busy,

  /// An empty-stomach medicine landing among after-food ones.
  foodClash,

  /// A fixed course; it will stop on its own.
  course,
}

class Placement {
  const Placement({
    required this.medicine,
    required this.reasons,
    this.duplicateOf,
  });

  /// The medicine with its slots — suggested ones filled in.
  final ScheduledMedicine medicine;
  final Set<PlacementReason> reasons;
  final ScheduledMedicine? duplicateOf;

  bool get isSuggestion => reasons.contains(PlacementReason.suggested);
}

/// Where each new medicine sits next to what is already being taken.
///
/// Two rules keep it safe. A timing the doctor gave is never moved: if the
/// prescription says 1-0-1 it stays 1-0-1 — "optimising" a prescribed
/// schedule is exactly the kind of help that gets someone hurt. And a timing
/// nobody gave is a suggestion, labelled as one, so approving it is a real
/// decision rather than a rubber stamp.
abstract final class PlacementAdvisor {
  /// A slot with this many medicines already is busy.
  static const busyAt = 3;

  static List<Placement> advise({
    required List<ScheduledMedicine> incoming,
    required List<ScheduledMedicine> existing,
    required DateTime today,
  }) {
    final active = existing.where((m) => m.active).toList();
    final placed = <ScheduledMedicine>[];
    final out = <Placement>[];

    for (final m in incoming) {
      final reasons = <PlacementReason>{};
      var sig = m.sig;

      if (sig.sos || sig.stat) {
        // As needed or once: no slot to choose.
      } else if (sig.slots.isNotEmpty) {
        reasons.add(PlacementReason.kept);
      } else {
        sig = sig.copyWith(
          slots: [
            _suggest(sig, [...active, ...placed]),
          ],
        );
        reasons.add(PlacementReason.suggested);
      }
      final medicine = m.copyWith(sig: sig);

      final alongside = [
        for (final other in [...active, ...placed])
          if (other.id != m.id &&
              ScheduleEngine.isDueOn(other, today) &&
              other.sig.slots.any(sig.slots.contains))
            other,
      ];
      for (final slot in sig.slots) {
        final inSlot = alongside.where((o) => o.sig.slots.contains(slot));
        if (inSlot.length >= busyAt) reasons.add(PlacementReason.busy);
        if (sig.food == FoodTiming.before &&
            inSlot.any((o) => o.sig.food == FoodTiming.after)) {
          reasons.add(PlacementReason.foodClash);
        }
      }

      final dup = active
          .where((e) => NameMatcher.same(e.name, m.name))
          .firstOrNull;
      if (dup != null) reasons.add(PlacementReason.duplicate);
      if (sig.durationDays != null) reasons.add(PlacementReason.course);

      placed.add(medicine);
      out.add(
        Placement(medicine: medicine, reasons: reasons, duplicateOf: dup),
      );
    }
    return out;
  }

  /// The least crowded of morning and night. An empty-stomach medicine goes
  /// in the morning, before breakfast, which is where one usually is.
  static DoseSlot _suggest(Sig sig, List<ScheduledMedicine> around) {
    if (sig.food == FoodTiming.before) return DoseSlot.morning;
    int load(DoseSlot s) => around.where((m) => m.sig.slots.contains(s)).length;
    return load(DoseSlot.night) < load(DoseSlot.morning)
        ? DoseSlot.night
        : DoseSlot.morning;
  }
}
