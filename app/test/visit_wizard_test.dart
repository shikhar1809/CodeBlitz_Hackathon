import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/pharmacy_check.dart';
import 'package:winger/domain/placement_advisor.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/visit/visit.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/features/wizard/wizard_models.dart';

import 'support/wizard_fakes.dart';

void main() {
  Future<void> to(VisitWizardController c, WizardStep step) async {
    while (c.step != step) {
      await c.next();
    }
  }

  test('the whole visit, end to end, onto the schedule', () async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, 'Telma chalu rakhiye, BP ke liye');
    await c.next(); // takeaways
    final telmaRow = c.takeaways(SourceKind.doctor).single;
    expect(telmaRow.name, 'Telma');
    // No time was said, so the row waits for a person — who ticks it.
    expect(telmaRow.ticked, isFalse);
    c.toggleTakeaway(SourceKind.doctor, 0);

    await c.next(); // photos
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    expect(c.candidates.map((x) => x.label), [
      PhotoLabel.bill,
      PhotoLabel.prescription,
    ]);
    await c.next(); // pharmacy words
    await c.skip(); // → processing, chemist skipped
    expect(c.step, WizardStep.processing);
    expect(c.rows.map((r) => r.name), ['TELMA 40', 'GLYCOMET 500 SR']);
    expect(c.rows.every((r) => r.verdict == Verdict.green), isTrue);

    await c.next(); // medicines
    expect(c.canGoNext, isFalse, reason: 'every card must be decided');
    // The bill sold 15 GLYCOMET for a 60-tablet course: a person is asked,
    // and says the course is right (they will buy the rest).
    final question = c.questionsToAsk.single;
    expect(question.kind, PharmacyIssueKind.quantity);
    await c.answer(question, PharmacyChoice.a);
    for (final r in c.rows) {
      if (!c.decisionOf(r).confirmed) c.confirm(r);
    }
    expect(c.canGoNext, isTrue);

    await c.next(); // placement
    expect(
      c.placements.every((p) => p.reasons.contains(PlacementReason.kept)),
      isTrue,
    );
    final approved = await c.approve();
    expect(approved.map((m) => m.name), ['TELMA 40', 'GLYCOMET 500 SR']);
    expect(c.store.active(), hasLength(2));
    expect(c.store.records().single.id, 'v1');
    expect(c.repository.loadDraft(), isNull, reason: 'draft cleared');
    expect(c.store.active().first.purpose, 'BP');
  });

  test('OCR runs once: the text read while labelling is reused', () async {
    final c = await wizard();
    await to(c, WizardStep.photos);
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    await to(c, WizardStep.processing);
    await c.runAnalysis();
    await c.runAnalysis();
    expect((c.recogniser as FakeRecogniser).reads, hasLength(2));
    expect(c.ocrReads, 2);
  });

  test(
    'only ticked photos enter the visit, and only when the step is left',
    () async {
      final c = await wizard();
      await to(c, WizardStep.photos);
      await c.addPhotos([
        XFile('bill.jpg'),
        XFile('rx.jpg'),
        XFile('beach.jpg'),
      ]);
      expect(c.visit.photos, isEmpty, reason: 'scanning is not an import');

      await c.next();
      expect(c.visit.photos.map((p) => p.path), ['bill.jpg', 'rx.jpg']);
    },
  );

  test(
    'a holiday photo arrives unticked, with its reason, never hidden',
    () async {
      final c = await wizard();
      await to(c, WizardStep.photos);
      await c.addPhotos([XFile('beach.jpg')]);
      final beach = c.candidates.single;
      expect(beach.selected, isFalse);
      expect(beach.reason, isNotNull);

      c.toggleSelected(beach); // use it anyway
      expect(beach.selected, isTrue);
    },
  );

  test('Next is locked until a prescription photo is ticked', () async {
    final c = await wizard();
    await to(c, WizardStep.photos);
    expect(c.canGoNext, isFalse);
    await c.addPhotos([XFile('bill.jpg')]);
    expect(c.canGoNext, isFalse, reason: 'a bill alone is not enough');
    await c.addPhotos([XFile('rx.jpg')]);
    expect(c.canGoNext, isTrue);
  });

  test(
    'where photos cannot be read, they are kept and the screen says so',
    () async {
      final c = await wizard(ocrSupported: false);
      await to(c, WizardStep.photos);
      await c.addPhotos([XFile('rx.jpg')]);
      final x = c.candidates.single;
      expect(x.unreadable, isTrue);
      expect(x.selected, isTrue);
      expect(x.ocrText, isNull);
    },
  );

  test('an unticked takeaway never reaches the analysis', () async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, 'Telma 40 subah. Shelcal raat ko.');
    await c.next();
    final rows = c.takeaways(SourceKind.doctor);
    expect(rows.map((r) => r.name), ['Telma 40', 'Shelcal']);
    c.toggleTakeaway(SourceKind.doctor, 1); // untick Shelcal
    await to(c, WizardStep.photos);
    await c.addPhotos([XFile('rx.jpg')]);
    await to(c, WizardStep.processing);
    expect(c.rows.map((r) => r.name), isNot(contains('SHELCAL')));
  });

  test('ticks and edits survive going back and forward again', () async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, 'Telma 40 subah');
    await c.next();
    c.editTakeaway(SourceKind.doctor, 0, 'Telma 40', 'raat ko');
    c.back();
    await c.next();
    expect(c.takeaways(SourceKind.doctor).single.sig.slots, [DoseSlot.night]);
  });

  test('advice from the doctor is a note, not a medicine', () async {
    final c = await wizard();
    c.setWords(
      SourceKind.doctor,
      'Telma 40 subah. Come back after ten days for review.',
    );
    await c.next();
    final rows = c.takeaways(SourceKind.doctor);
    expect(
      rows.where((r) => r.isNote).single.name,
      'Come back after ten days for review',
    );
    expect(rows.firstWhere((r) => !r.isNote).sig.durationDays, isNull);
  });

  group('a red card', () {
    late VisitWizardController c;
    late MergedMedicine telma;

    setUp(() async {
      c = await wizard(
        ocr: {'rx.jpg': 'Rx\nTab Telma 40  1-0-1', 'bill.jpg': billText},
      );
      c.setWords(SourceKind.doctor, 'Telma 40 sirf raat ko');
      await to(c, WizardStep.photos);
      await c.addPhotos([XFile('rx.jpg'), XFile('bill.jpg')]);
      await to(c, WizardStep.medicines);
      telma = c.rows.firstWhere((r) => r.name == 'TELMA 40');
    });

    test('cannot be confirmed until a person picks a side', () {
      expect(telma.verdict, Verdict.red);
      expect(c.canConfirm(telma), isFalse);
      c.confirm(telma);
      expect(c.decisionOf(telma).confirmed, isFalse);
    });

    test('the side a person picks is what reaches the schedule', () {
      final doctor = telma.conflicts.first.sides.firstWhere(
        (m) => m.source == SourceKind.doctor,
      );
      c.choose(telma, doctor);
      expect(c.decisionOf(telma).confirmed, isTrue);
      expect(c.finalSig(telma).slots, [DoseSlot.night]);
    });

    test('a person\'s own fix beats every source', () {
      c.editRow(telma, 'TELMA 40', '1-0-0 after food');
      expect(c.finalSig(telma).slots, [DoseSlot.morning]);
      expect(c.finalSig(telma).food, FoodTiming.after);
    });

    test('a card left out stays off the schedule', () async {
      c.leaveOut(telma);
      for (final r in c.rows.where((r) => r != telma)) {
        c.confirm(r);
      }
      await c.next();
      expect(
        c.placements.map((p) => p.medicine.name),
        isNot(contains('TELMA 40')),
      );
    });
  });
}
