import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/name_matcher.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/domain/sig_parser.dart';

Mention mention(SourceKind source, String line) {
  final p = SigParser.parseLine(line);
  return Mention(
    source: source,
    name: p.name!,
    strength: p.strength,
    sig: p.sig,
    raw: line,
    purpose: p.purpose,
  );
}

const bill = SourceKind.bill;
const rx = SourceKind.prescription;
const doctor = SourceKind.doctor;
const chemist = SourceKind.chemist;
const strip = SourceKind.strip;

void main() {
  group('NameMatcher', () {
    test('OCR noise still lines up', () {
      expect(NameMatcher.same('TELMA 40', 'TELNA 40'), isTrue);
      expect(NameMatcher.same('GLYCOMET 500', 'GLYCOMFT 500'), isTrue);
    });
    test('a missing strength does not block a match', () {
      expect(NameMatcher.same('TELMA', 'TELMA 40'), isTrue);
    });
    test('a variant suffix is a different product', () {
      expect(NameMatcher.same('GLYCOMET 500', 'GLYCOMET GP1'), isFalse);
      expect(NameMatcher.same('GLYCOMET 500 SR', 'GLYCOMET 500'), isFalse);
    });
    test('a brand is not its generic: the substitution stays visible', () {
      expect(NameMatcher.same('TELMA', 'TELMISARTAN'), isFalse);
    });
    test('different medicines do not match', () {
      expect(NameMatcher.same('PAN 40', 'PANTOCID 40'), isFalse);
      expect(NameMatcher.same('ECOSPRIN 75', 'TELMA 40'), isFalse);
    });
    test('a dosage form word is not part of the brand', () {
      expect(NameMatcher.parse('TAB TELMA 40').brand, 'telma');
    });
  });

  group('verdicts', () {
    test('green: two sources agree and someone said when', () {
      final r = MergeEngine.merge([
        mention(bill, 'TELMA 40 TAB  30 NOS'),
        mention(rx, 'Tab Telma 40 1-0-1 p/c'),
      ]).single;
      expect(r.verdict, Verdict.green);
      expect(r.name, 'TELMA 40');
      expect(r.sig.slots, [DoseSlot.morning, DoseSlot.night]);
      expect(r.sig.food, FoodTiming.after);
    });

    test('a bill has no timing, and that alone does not block green', () {
      // Once, "timing from a single source" blocked green. A bill never
      // carries timing, so green became unreachable with the best evidence
      // present. The rule was dropped.
      final r = MergeEngine.merge([
        mention(bill, 'GLYCOMET 500 TAB'),
        mention(doctor, 'Glycomet 500 subah aur raat khane ke baad'),
      ]).single;
      expect(r.verdict, Verdict.green);
    });

    test('amber: only one source', () {
      final r = MergeEngine.merge([mention(rx, 'Tab Pan 40 OD a/c')]).single;
      expect(r.verdict, Verdict.amber);
      expect(r.reasons, contains(AmberReason.singleSource));
    });

    test('amber: nobody said when', () {
      final r = MergeEngine.merge([
        mention(rx, 'Tab Ecosprin 75'),
        mention(bill, 'ECOSPRIN 75 TAB'),
      ]).single;
      expect(r.verdict, Verdict.amber);
      expect(r.reasons, [AmberReason.noTiming]);
    });

    test('red: on the bill, but nobody prescribed it', () {
      final r = MergeEngine.merge([
        mention(bill, 'AMLONG 5 TAB  30 NOS'),
        mention(strip, 'AMLONG 5'),
      ]).single;
      expect(r.verdict, Verdict.red);
      expect(r.conflicts.single.field, ConflictField.notPrescribed);
    });

    test('amber: words the parser could not place', () {
      final r = MergeEngine.merge([
        mention(bill, 'TELMA 40 TAB'),
        mention(chemist, 'Telma ki jagah Telmisartan de diya'),
      ]).first;
      expect(r.reasons, contains(AmberReason.unresolved));
    });

    test('red: the prescription and the doctor disagree on timing', () {
      final r = MergeEngine.merge([
        mention(rx, 'Tab Telma 40 1-0-1'),
        mention(doctor, 'Telma 40 sirf subah'),
      ]).single;
      expect(r.verdict, Verdict.red);
      expect(r.conflicts.single.field, ConflictField.timing);
      expect(r.conflicts.single.sides, hasLength(2));
    });

    test('red: the bill and the prescription disagree on strength', () {
      final r = MergeEngine.merge([
        mention(bill, 'TELMA 80 TAB'),
        mention(rx, 'Tab Telma 40 OD'),
      ]).single;
      expect(r.verdict, Verdict.red);
      expect(r.conflicts.map((c) => c.field), contains(ConflictField.strength));
    });

    test('red: before food against after food', () {
      final r = MergeEngine.merge([
        mention(rx, 'Tab Pan 40 OD a/c'),
        mention(chemist, 'Pan 40 subah khane ke baad'),
      ]).single;
      expect(r.conflicts.map((c) => c.field), contains(ConflictField.food));
    });

    test('red: as needed against a fixed time', () {
      final r = MergeEngine.merge([
        mention(rx, 'Tab Dolo 650 SOS'),
        mention(chemist, 'Dolo 650 subah shaam'),
      ]).single;
      expect(r.conflicts.map((c) => c.field), contains(ConflictField.asNeeded));
    });

    test('a different duration is not a conflict', () {
      final r = MergeEngine.merge([
        mention(doctor, 'Glycomet 500 subah raat ek mahina'),
        mention(rx, 'Tab Glycomet 500 BD x 10 days'),
      ]).single;
      expect(r.conflicts, isEmpty);
      expect(r.sig.durationDays, 30, reason: 'the doctor decides timing');
    });
  });

  group('never picks a side, never hides anything', () {
    test('a conflict keeps both readings', () {
      final r = MergeEngine.merge([
        mention(rx, 'Tab Telma 40 1-0-1'),
        mention(doctor, 'Telma 40 raat ko'),
      ]).single;
      final raws = r.conflicts.single.sides.map((m) => m.raw);
      expect(raws, containsAll(['Tab Telma 40 1-0-1', 'Telma 40 raat ko']));
    });

    test('the same source twice stays apart', () {
      final rows = MergeEngine.merge([
        mention(bill, 'TELMA 40 TAB'),
        mention(bill, 'TELMA 40 TAB'),
      ]);
      expect(rows, hasLength(2));
      expect(
        rows.every((r) => r.reasons.contains(AmberReason.sameSourceTwice)),
        isTrue,
      );
      expect(rows.map((r) => r.id).toSet(), hasLength(2), reason: 'unique ids');
    });

    test('the bill decides identity, the doctor decides timing', () {
      final r = MergeEngine.merge([
        mention(doctor, 'Telma raat ko'),
        mention(bill, 'TELMA 40 TAB'),
      ]).single;
      expect(r.name, 'TELMA 40');
      expect(r.sig.slots, [DoseSlot.night]);
    });

    test('a purpose is taken only from the doctor', () {
      final fromChemist = MergeEngine.merge([
        mention(bill, 'TELMA 40 TAB'),
        mention(chemist, 'Telma 40 subah BP ke liye'),
      ]).single;
      expect(fromChemist.purpose, isNull);

      final fromDoctor = MergeEngine.merge([
        mention(bill, 'TELMA 40 TAB'),
        mention(doctor, 'Telma 40 subah BP ke liye'),
      ]).single;
      expect(fromDoctor.purpose, 'BP');
    });

    test('the same input gives the same answer every time', () {
      List<Mention> input() => [
        mention(bill, 'TELMA 40 TAB'),
        mention(rx, 'Tab Telma 40 1-0-1 p/c'),
        mention(doctor, 'Glycomet 500 subah'),
      ];
      final a = MergeEngine.merge(input());
      final b = MergeEngine.merge(input());
      expect(
        a.map((r) => '${r.id}${r.verdict}${r.sig}'),
        b.map((r) => '${r.id}${r.verdict}${r.sig}'),
      );
    });

    test('an SOS medicine never borrows a time from a lower source', () {
      final r = MergeEngine.merge([
        mention(doctor, 'Dolo 650 SOS'),
        mention(bill, 'DOLO 650 TAB'),
      ]).single;
      expect(r.sig.sos, isTrue);
      expect(r.sig.slots, isEmpty);
    });
  });
}
