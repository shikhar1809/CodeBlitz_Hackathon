import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/mention_extractor.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/sig.dart';

/// Whole sources, as they really arrive, through the extractor and the merge.
/// These are the tests that forced the four parser fixes out.
void main() {
  const billOcr = '''
SHREE GANESH MEDICAL STORE
GSTIN 09ABCDE1234F1Z5   Inv No 4471
Date 26/09/2026
Sr  Particulars           Qty    Rate    Amount
1   TELMA 40 TAB          30 NOS  8.50   255.00
2   GLYCOMET 500 SR       1x15    3.03    45.50
3   ECOSPRIN 75 TAB       14 NOS  0.50     7.00
TOTAL                                   307.50
Thank you
''';

  const rxOcr = '''
Dr. A. K. Verma  MBBS MD
Patient: Ramesh   Age 64
Rx
1) Tab Telma 40      1-0-1  p/c
2) Tab Glycomet 500 SR
     1-0-1  x 30 days
3) Tab Pan 40  OD a/c
''';

  const doctorSpeech =
      'Telma chalu rakhiye, BP ke liye. Glycomet five hundred SR subah aur raat '
      'khane ke baad, ek mahina. Ecosprin raat ko.';

  List<Mention> read(String text, SourceKind s) =>
      MentionExtractor.extract(text, s);

  group('the extractor', () {
    test('reads every medicine on a real-looking bill, and nothing else', () {
      final names = read(billOcr, SourceKind.bill).map((m) => m.name);
      expect(names, ['TELMA 40', 'GLYCOMET 500 SR', 'ECOSPRIN 75']);
    });

    test('joins a sig written on the line below', () {
      final ms = read(rxOcr, SourceKind.prescription);
      final glycomet = ms.firstWhere((m) => m.name.startsWith('GLYCOMET'));
      expect(glycomet.sig.slots, [DoseSlot.morning, DoseSlot.night]);
      expect(glycomet.sig.durationDays, 30);
    });

    test('skips the doctor and the patient headers', () {
      final names = read(rxOcr, SourceKind.prescription).map((m) => m.name);
      expect(names, ['TELMA 40', 'GLYCOMET 500 SR', 'PAN 40']);
    });

    test('splits a dictated visit at its pauses', () {
      final ms = read(doctorSpeech, SourceKind.doctor);
      expect(ms.map((m) => m.name), ['TELMA', 'GLYCOMET 500 SR', 'ECOSPRIN']);
      expect(ms.first.purpose, 'BP');
      expect(ms.first.needsCorroboration, isTrue);
      expect(ms[1].sig.durationDays, 30);
      expect(ms[2].sig.slots, [DoseSlot.night]);
    });

    test('a spoken name gets its evidence from the instruction after it', () {
      final ms = read('Telma, subah ek', SourceKind.doctor);
      expect(ms.single.needsCorroboration, isFalse);
      expect(ms.single.sig.slots, [DoseSlot.morning]);
    });
  });

  group('four sources, cross-questioned', () {
    late List<MergedMedicine> rows;

    setUp(() {
      rows = MergeEngine.merge([
        ...read(billOcr, SourceKind.bill),
        ...read(rxOcr, SourceKind.prescription),
        ...read(doctorSpeech, SourceKind.doctor),
      ]);
    });

    MergedMedicine row(String prefix) =>
        rows.firstWhere((r) => r.name.startsWith(prefix));

    test('TELMA 40: bill, prescription and doctor agree', () {
      final r = row('TELMA');
      expect(r.name, 'TELMA 40');
      expect(r.sources, {
        SourceKind.bill,
        SourceKind.prescription,
        SourceKind.doctor,
      });
      expect(r.verdict, Verdict.green);
      expect(r.purpose, 'BP');
    });

    test('GLYCOMET 500 SR: green, with the doctor\'s month', () {
      final r = row('GLYCOMET');
      expect(r.verdict, Verdict.green);
      expect(r.sig.durationDays, 30);
      expect(r.sig.food, FoodTiming.after);
    });

    test('ECOSPRIN 75: bill identity, doctor timing', () {
      final r = row('ECOSPRIN');
      expect(r.name, 'ECOSPRIN 75');
      expect(r.sig.slots, [DoseSlot.night]);
      expect(r.verdict, Verdict.green);
    });

    test('PAN 40: on the prescription only, so a person looks', () {
      final r = row('PAN');
      expect(r.verdict, Verdict.amber);
      expect(r.reasons, contains(AmberReason.singleSource));
    });
  });

  test('no medicine on a bill is ever silently dropped', () {
    final names = read(
      '1 TELMA 40 TAB  30 NOS  255.00\n'
      '2 AMLONG 5 TAB  30 NOS  60.00\n'
      '3 ECOSPRIN 75 TAB  14 NOS  7.00',
      SourceKind.bill,
    ).map((m) => m.name);
    expect(names, ['TELMA 40', 'AMLONG 5', 'ECOSPRIN 75']);
  });

  test('advice is a note, and never changes a course', () {
    final x = MentionExtractor.extractWithNotes(
      'Glycomet 500 subah aur raat. Come back after ten days for review.',
      SourceKind.doctor,
    );
    expect(x.mentions.single.sig.durationDays, isNull);
    expect(x.notes, ['Come back after ten days for review']);
  });

  test('a substitution at the counter becomes a row a person ticks', () {
    final rows = MergeEngine.merge([
      ...read('TELMA 40 TAB  30 NOS', SourceKind.bill),
      ...read('Telma ki jagah Telmisartan de diya', SourceKind.chemist),
    ]);
    final telma = rows.single;
    expect(telma.verdict, isNot(Verdict.green));
    expect(
      telma.evidence.map((m) => m.raw),
      contains('Telma ki jagah Telmisartan de diya'),
    );
  });
}
