import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/placement_advisor.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';

const m = DoseSlot.morning;
const n = DoseSlot.night;
final today = DateTime(2026, 9, 26);

ScheduledMedicine med(String name, Sig sig) => ScheduledMedicine(
  id: name.toLowerCase().replaceAll(' ', '-'),
  name: name,
  sig: sig,
  startDate: today,
);

void main() {
  Placement one(ScheduledMedicine x, [List<ScheduledMedicine> e = const []]) =>
      PlacementAdvisor.advise(incoming: [x], existing: e, today: today).single;

  test('a prescribed timing is never moved', () {
    final p = one(med('TELMA 40', const Sig(slots: [m, n])), [
      med('A', const Sig(slots: [m])),
      med('B', const Sig(slots: [m])),
      med('C', const Sig(slots: [m])),
    ]);
    expect(p.medicine.sig.slots, [m, n]);
    expect(p.reasons, contains(PlacementReason.kept));
    expect(p.reasons, isNot(contains(PlacementReason.suggested)));
  });

  test('a timing nobody gave is a labelled suggestion', () {
    final p = one(med('ECOSPRIN 75', const Sig()));
    expect(p.medicine.sig.slots, hasLength(1));
    expect(p.isSuggestion, isTrue);
  });

  test('the suggestion goes to the quieter slot', () {
    final p = one(med('ECOSPRIN 75', const Sig()), [
      med('A', const Sig(slots: [m])),
      med('B', const Sig(slots: [m])),
    ]);
    expect(p.medicine.sig.slots, [n]);
  });

  test('an empty-stomach medicine is suggested for the morning', () {
    final p = one(med('PAN 40', const Sig(food: FoodTiming.before)), [
      med('A', const Sig(slots: [m])),
      med('B', const Sig(slots: [m])),
    ]);
    expect(p.medicine.sig.slots, [m]);
  });

  test('a busy slot is flagged', () {
    final p = one(med('NEW', const Sig(slots: [m])), [
      med('A', const Sig(slots: [m])),
      med('B', const Sig(slots: [m])),
      med('C', const Sig(slots: [m])),
    ]);
    expect(p.reasons, contains(PlacementReason.busy));
  });

  test('before food among after-food medicines is a clash', () {
    final p = one(
      med('PAN 40', const Sig(slots: [m], food: FoodTiming.before)),
      [
        med('TELMA 40', const Sig(slots: [m], food: FoodTiming.after)),
      ],
    );
    expect(p.reasons, contains(PlacementReason.foodClash));
  });

  test('a near-duplicate already on the schedule is flagged', () {
    final existing = med('TELMA 40', const Sig(slots: [m]));
    final p = one(med('TELNA 40', const Sig(slots: [m])), [existing]);
    expect(p.reasons, contains(PlacementReason.duplicate));
    expect(p.duplicateOf, same(existing));
  });

  test('a fixed course says it will stop', () {
    final p = one(med('AUGMENTIN', const Sig(slots: [m, n], durationDays: 5)));
    expect(p.reasons, contains(PlacementReason.course));
  });

  test('SOS gets no slot, suggested or otherwise', () {
    final p = one(med('DOLO 650', const Sig(sos: true)));
    expect(p.medicine.sig.slots, isEmpty);
    expect(p.isSuggestion, isFalse);
  });

  test('medicines in the same approval count toward each other', () {
    final ps = PlacementAdvisor.advise(
      incoming: [
        med('A', const Sig(slots: [m])),
        med('B', const Sig(slots: [m])),
        med('C', const Sig(slots: [m])),
        med('D', const Sig(slots: [m])),
      ],
      existing: const [],
      today: today,
    );
    expect(ps.last.reasons, contains(PlacementReason.busy));
  });
}
