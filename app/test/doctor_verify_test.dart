import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/caregiver/caregiver_home.dart';
import 'package:winger/features/doses/dose_log_store.dart';
import 'package:winger/features/visit/visit.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/features/wizard/wizard_models.dart';
import 'package:winger/features/wizard/wizard_screen.dart';
import 'package:winger/platform/gallery_scanner.dart';

import 'support/golden_harness.dart';
import 'support/wizard_fakes.dart';

const speech =
    'Telma 40 subah khane ke baad, BP ke liye. Shelcal raat ko. '
    'Come back after ten days for review.';

void main() {
  Future<VisitWizardController> atVerification() async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, speech);
    await c.next();
    return c;
  }

  Future<void> toMedicines(VisitWizardController c) async {
    await c.next(); // photos
    await c.addPhotos([XFile('bill.jpg')]);
    await c.addPhotos([XFile('rx.jpg')]);
    while (c.step != WizardStep.processing) {
      await c.next();
    }
  }

  void confirmAll(VisitWizardController c, int i) {
    final row = c.takeaways(SourceKind.doctor)[i];
    for (final p in CheckPoint.values) {
      if (row.checks[p] == CheckState.unchecked) {
        c.setCheck(SourceKind.doctor, i, p, CheckState.confirmed);
      }
    }
  }

  test('me is the default; the choice is remembered on the visit', () async {
    final c = await atVerification();
    expect(c.verifier, Verifier.me);
    c.setVerifier(Verifier.doctor);
    expect(c.visit.verifiedBy, Verifier.doctor);
    expect(c.repository.loadDraft()!.verifiedBy, Verifier.doctor);
  });

  test('what was not heard starts as "not provided" — never a guess', () async {
    final c = await atVerification();
    final shelcal = c.takeaways(SourceKind.doctor)[1];
    expect(shelcal.checks[CheckPoint.food], CheckState.notProvided);
    expect(shelcal.checks[CheckPoint.duration], CheckState.notProvided);
    expect(shelcal.checks[CheckPoint.timing], CheckState.unchecked);
    expect(shelcal.checks[CheckPoint.name], CheckState.unchecked);
  });

  test('an unverified row is left out, exactly like an unticked one', () async {
    final c = await atVerification();
    c.setVerifier(Verifier.doctor);
    confirmAll(c, 0); // Telma only
    await toMedicines(c);
    final doctorRows = c.rows.where(
      (r) => r.sources.contains(SourceKind.doctor),
    );
    expect(doctorRows.map((r) => r.name), ['TELMA 40']);
  });

  test('a point marked "not provided" reaches the merge as missing', () async {
    final c = await atVerification();
    c.setVerifier(Verifier.doctor);
    confirmAll(c, 0);
    c.setCheck(SourceKind.doctor, 0, CheckPoint.timing, CheckState.notProvided);
    final line = VisitWizardController.doctorLine(
      c.takeaways(SourceKind.doctor)[0],
    );
    expect(line, isNot(contains('morning')));
    expect(line, contains('after food'));
    expect(line, contains('BP ke liye'));
  });

  test('a fully verified row carries every confirmed point', () async {
    final c = await atVerification();
    c.setVerifier(Verifier.doctor);
    confirmAll(c, 0);
    expect(c.takeaways(SourceKind.doctor)[0].doctorVerified, isTrue);
    await toMedicines(c);
    final telma = c.rows.firstWhere((r) => r.name == 'TELMA 40');
    final doctor = telma.evidence.firstWhere(
      (m) => m.source == SourceKind.doctor,
    );
    expect(doctor.sig.slots, [DoseSlot.morning]);
    expect(doctor.sig.food, FoodTiming.after);
    expect(telma.purpose, 'BP');
    // The prescription says 1-0-1; the doctor confirmed the morning only.
    // Verification does not quietly win: the card goes red for a person.
    expect(telma.verdict, Verdict.red);
    expect(telma.conflicts.first.field, ConflictField.timing);
  });

  test('a skipped step is recorded as not provided', () async {
    final c = await wizard();
    await c.skip();
    expect(
      c.visit.notProvided,
      containsAll(['doctorWords', 'doctorTakeaways']),
    );
  });

  test('the caretaker note and its priority reach the record', () async {
    final c = await atVerification();
    c.setCaretakerNote('Sugar was high today, watch the evening dose');
    c.setNotePriority(NotePriority.high);
    await toMedicines(c);
    for (final r in c.rows) {
      if (c.canConfirm(r)) {
        c.confirm(r);
      } else {
        c.leaveOut(r);
      }
    }
    await c.next();
    await c.approve();
    final record = c.store.records().single;
    expect(record.caretakerNote, startsWith('Sugar was high'));
    expect(record.notePriority, 'high');
  });

  group('screens', () {
    Future<void> shoot(
      WidgetTester tester,
      VisitWizardController c,
      String name, {
      AppLanguage language = AppLanguage.en,
    }) async {
      usePhoneSurface(tester, size: const Size(412, 1900));
      await tester.pumpWidget(
        themed(
          WizardScreen(
            controller: c,
            consent: (_) async => true,
            scanner: FakeScanner(const ScanOutcome.unsupported()),
            photos: FakePhotos(const []),
          ),
          language: language,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
      await tester.pumpWidget(const SizedBox());
    }

    Future<VisitWizardController> doctorMode() async {
      final c = await atVerification();
      c.setVerifier(Verifier.doctor);
      confirmAll(c, 0);
      c.setCaretakerNote('Sugar was high today');
      c.setNotePriority(NotePriority.high);
      return c;
    }

    testWidgets('doctor mode · en', (t) async {
      await shoot(t, await doctorMode(), 'wizard_12_doctor_verify_en');
    });

    testWidgets('doctor mode · hi', (t) async {
      await shoot(
        t,
        await doctorMode(),
        'wizard_13_doctor_verify_hi',
        language: AppLanguage.hi,
      );
    });

    testWidgets('tapping Not provided marks the point', (tester) async {
      final c = await atVerification();
      c.setVerifier(Verifier.doctor);
      usePhoneSurface(tester, size: const Size(412, 1900));
      await tester.pumpWidget(
        themed(
          WizardScreen(
            controller: c,
            consent: (_) async => true,
            scanner: FakeScanner(const ScanOutcome.unsupported()),
            photos: FakePhotos(const []),
          ),
        ),
      );
      await tester.pump();
      // The first "Not provided" belongs to Telma's name point.
      await tester.tap(find.text('Not provided').first);
      await tester.pump();
      expect(
        c.takeaways(SourceKind.doctor)[0].checks[CheckPoint.name],
        CheckState.notProvided,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a High note is pinned to the top of the caretaker home', (
      tester,
    ) async {
      final c = await atVerification();
      c.setCaretakerNote('Sugar was high today');
      c.setNotePriority(NotePriority.high);
      await c.store.approve(
        visitId: 'v1',
        approved: const [],
        caretakerNote: 'Sugar was high today',
        notePriority: 'high',
      );
      await c.store.approve(
        visitId: 'v0',
        approved: const [],
        caretakerNote: 'Bought the new strip',
        notePriority: 'low',
      );
      usePhoneSurface(tester, size: const Size(412, 1400));
      final state = await freshState(values: const {'user_name': 'Ramesh'});
      await tester.pumpWidget(
        themed(
          CaregiverHome(
            onRestart: () {},
            store: c.store,
            logs: await DoseLogStore.load(),
          ),
          state: state,
        ),
      );
      await tester.pump();
      final high = tester.getTopLeft(find.text('Sugar was high today')).dy;
      final doses = tester.getTopLeft(find.text("Today's doses")).dy;
      final low = tester.getTopLeft(find.text('Bought the new strip')).dy;
      expect(high, lessThan(doses));
      expect(low, greaterThan(doses));
    });
  });
}
