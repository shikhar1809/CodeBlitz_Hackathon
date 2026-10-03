import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/mention_extractor.dart';
import 'package:winger/domain/offline_analyser.dart';
import 'package:winger/domain/pharmacy_check.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/domain/sig_parser.dart';
import 'package:winger/features/visit/visit.dart';

/// The pharmacy-side questions, found in plain Dart. One fixture per trigger,
/// each raising exactly one question.
void main() {
  List<PharmacyIssue> issues({
    String rx = '',
    String bill = '',
    String doctor = '',
    String chemist = '',
  }) {
    final result = OfflineAnalyser.analyse([
      SourceText(SourceKind.prescription, rx),
      SourceText(SourceKind.bill, bill),
      SourceText(SourceKind.doctor, doctor),
      SourceText(SourceKind.chemist, chemist),
    ]);
    return PharmacyCheck.find(
      rows: result.rows,
      chemistWords: chemist,
      unreadable: result.unreadable,
    );
  }

  group('pack quantities', () {
    test('30 NOS and 1x15 are kept as counts, not names or doses', () {
      final telma = SigParser.parseLine(
        '1 TELMA 40 TAB          30 NOS   255.00',
        printed: true,
      );
      expect(telma.name, 'TELMA 40');
      expect(telma.packQuantity, 30);
      expect(telma.sig, const Sig());

      final glycomet = SigParser.parseLine(
        '2 GLYCOMET 500 SR       1x15      45.50',
        printed: true,
      );
      expect(glycomet.name, 'GLYCOMET 500 SR');
      expect(glycomet.packQuantity, 15);
      expect(glycomet.sig, const Sig());
    });

    test("a strip size (10's) and a count of strips are not tablets", () {
      expect(
        SigParser.parseLine("TELMA 40 TAB 10's", printed: true).packQuantity,
        isNull,
      );
      expect(
        SigParser.parseLine(
          'TELMA 40 TAB 12 strips',
          printed: true,
        ).packQuantity,
        isNull,
      );
    });

    test('the count reaches the bill mention', () {
      final ms = MentionExtractor.extract(
        '1 TELMA 40 TAB  30 NOS  255.00\n2 GLYCOMET 500 SR  1x15  45.50',
        SourceKind.bill,
      );
      expect(ms.map((m) => m.packQuantity), [30, 15]);
    });
  });

  group('unreadable lines', () {
    test('a form with no readable name is asked about, not attached above', () {
      final x = MentionExtractor.extractWithNotes(
        'Rx\nTab Telma 40  1-0-1  p/c\n2) Tab .... 0-0-1',
        SourceKind.prescription,
      );
      expect(x.mentions.single.name, 'TELMA 40');
      expect(x.mentions.single.sig.slots, [DoseSlot.morning, DoseSlot.night]);
      expect(x.unreadable.single.text, '2) Tab .... 0-0-1');
      expect(x.unreadable.single.signals, contains('tab'));
    });

    test('headers, totals and addresses are never unreadable medicines', () {
      const billOcr = '''
SHREE GANESH MEDICAL STORE
GSTIN 09ABCDE1234F1Z5   Inv No 4471
Date 26/09/2026
Sr  Particulars           Qty    Rate    Amount
1   TELMA 40 TAB          30 NOS  8.50   255.00
TOTAL                                   307.50
Thank you''';
      const rxOcr = '''
Dr. A. K. Verma  MBBS MD
Patient: Ramesh   Age 64
Rx
1) Tab Telma 40      1-0-1  p/c''';
      expect(
        MentionExtractor.extractWithNotes(billOcr, SourceKind.bill).unreadable,
        isEmpty,
      );
      expect(
        MentionExtractor.extractWithNotes(
          rxOcr,
          SourceKind.prescription,
        ).unreadable,
        isEmpty,
      );
    });

    test('speech never produces an unreadable line', () {
      expect(
        MentionExtractor.extractWithNotes(
          'tablet 1-0-1 le lena',
          SourceKind.chemist,
        ).unreadable,
        isEmpty,
      );
    });
  });

  group('each trigger raises exactly one question', () {
    test('substitution on the bill: TELMA prescribed, TELMISARTAN sold', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c',
        bill: '1 TELMISARTAN 40 TAB  30 NOS  255.00',
      );
      expect(found, hasLength(1));
      final i = found.single;
      expect(i.kind, PharmacyIssueKind.substitution);
      expect(i.a!.name, 'TELMA 40');
      expect(i.a!.source, SourceKind.prescription);
      expect(i.b!.name, 'TELMISARTAN 40');
      expect(i.b!.source, SourceKind.bill);
      expect(i.medicineId, 'telma-40');
      expect(i.otherId, 'telmisartan-40');
    });

    test('substitution said at the counter: "Telma ki jagah Telmisartan"', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c',
        bill: '1 TELMA 40 TAB  30 NOS  255.00',
        chemist: 'Telma ki jagah Telmisartan de diya',
      );
      expect(found, hasLength(1));
      final i = found.single;
      expect(i.kind, PharmacyIssueKind.substitution);
      expect(i.a!.name, 'TELMA 40');
      expect(i.b!.name, 'TELMISARTAN');
      expect(i.b!.source, SourceKind.chemist);
      expect(i.b!.raw, 'Telma ki jagah Telmisartan de diya');
      expect(i.otherId, isNull);
    });

    test('"instead of" reads the other way round', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c',
        bill: '1 TELMA 40 TAB  30 NOS',
        chemist: 'Gave Telmisartan 40 instead of Telma',
      );
      expect(found.single.a!.name, 'TELMA 40');
      expect(found.single.b!.name, 'TELMISARTAN 40');
    });

    test('unrelated brands are not paired as a substitution', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c\nTab Pan 40 OD a/c',
        bill: '1 TELMA 40 TAB  30 NOS\n2 ECOSPRIN 75 TAB  14 NOS',
      );
      expect(found.single.kind, PharmacyIssueKind.notPrescribed);
    });

    test('strength: the prescription says 40, the bill says 80', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c',
        bill: '1 TELMA 80 TAB  30 NOS',
      );
      expect(found, hasLength(1));
      expect(found.single.kind, PharmacyIssueKind.strength);
      expect(found.single.a!.strength, '40');
      expect(found.single.a!.source, SourceKind.prescription);
      expect(found.single.b!.strength, '80');
      expect(found.single.b!.source, SourceKind.bill);
    });

    test('not prescribed: sold at the counter, nobody asked for it', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c',
        bill: '1 TELMA 40 TAB  30 NOS\n2 ECOSPRIN 75 TAB  14 NOS',
      );
      expect(found, hasLength(1));
      expect(found.single.kind, PharmacyIssueKind.notPrescribed);
      expect(found.single.a!.name, 'ECOSPRIN 75');
      expect(found.single.b, isNull);
    });

    test('quantity: 15 tablets for a 60-tablet course', () {
      final found = issues(
        rx: 'Rx\nTab Glycomet 500 SR  1-0-1  x 30 days',
        bill: '2 GLYCOMET 500 SR  1x15  45.50',
      );
      expect(found, hasLength(1));
      final q = found.single;
      expect(q.kind, PharmacyIssueKind.quantity);
      expect(q.needed, 60);
      expect(q.sold, 15);
      expect(q.courseDays, 30);
      expect(q.billDays, 7);
    });

    test(
      'quantity: a course the bill covers, with a strip to spare, is fine',
      () {
        expect(
          issues(
            rx: 'Rx\nTab Glycomet 500 SR  1-0-1  x 5 days',
            bill: '2 GLYCOMET 500 SR  1x15',
          ),
          isEmpty,
        );
      },
    );

    test('quantity: no duration given, so no course is computed', () {
      expect(
        issues(
          rx: 'Rx\nTab Telma 40  1-0-1  p/c',
          bill: '1 TELMA 40 TAB  30 NOS',
        ),
        isEmpty,
      );
    });

    test('unreadable: a line that looks like a medicine but gave none', () {
      final found = issues(
        rx: 'Rx\nTab Telma 40  1-0-1  p/c\n2) Tab .... 0-0-1',
        bill: '1 TELMA 40 TAB  30 NOS',
      );
      expect(found, hasLength(1));
      expect(found.single.kind, PharmacyIssueKind.unreadable);
      expect(found.single.line!.source, SourceKind.prescription);
      expect(found.single.medicineId, startsWith('line-'));
    });
  });

  test('a resolution survives the visit JSON, field for field', () {
    final visit = Visit(id: 'v1', createdAt: DateTime(2026, 9, 26));
    visit.pharmacyResolutions.addAll([
      PharmacyResolution(
        kind: PharmacyIssueKind.quantity,
        medicineId: 'glycomet-500-sr',
        choice: PharmacyChoice.neither,
        explanation: 'Bought half, will buy the rest next week',
        voiceNotePath: '/visits/v1/pharmacy_quantity_1.m4a',
        answeredBy: AnsweredBy.caretaker,
        answeredAt: DateTime(2026, 9, 26, 10, 5),
      ),
      PharmacyResolution(
        kind: PharmacyIssueKind.strength,
        medicineId: 'telma-40',
        choice: PharmacyChoice.b,
        answeredBy: AnsweredBy.patient,
        answeredAt: DateTime(2026, 9, 26, 10, 6),
      ),
    ]);
    final back = Visit.fromJson(
      (jsonDecode(jsonEncode(visit.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.pharmacyResolutions, hasLength(2));
    final q = back.pharmacyResolutions.first;
    expect(q.kind, PharmacyIssueKind.quantity);
    expect(q.medicineId, 'glycomet-500-sr');
    expect(q.choice, PharmacyChoice.neither);
    expect(q.explanation, startsWith('Bought half'));
    expect(q.voiceNotePath, '/visits/v1/pharmacy_quantity_1.m4a');
    expect(q.answeredBy, AnsweredBy.caretaker);
    expect(q.answeredAt, DateTime(2026, 9, 26, 10, 5));
    expect(q.settles, isFalse);
    expect(back.pharmacyResolutions.last.settles, isTrue);
    expect(back.pharmacyResolutions.last.voiceNotePath, isNull);
  });
}
