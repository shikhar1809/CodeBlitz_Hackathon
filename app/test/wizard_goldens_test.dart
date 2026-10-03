import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/pharmacy_check.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/features/wizard/wizard_screen.dart';
import 'package:winger/platform/gallery_scanner.dart';

import 'support/golden_harness.dart';
import 'support/wizard_fakes.dart';

/// Goldens driven by the real controller: every row on these screens is what
/// the parser, the gate and the merge engine actually produced.
void main() {
  Future<void> shoot(
    WidgetTester tester,
    VisitWizardController c,
    String name, {
    AppLanguage language = AppLanguage.en,
    double height = 892,
  }) async {
    usePhoneSurface(tester, size: Size(412, height));
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

  const doctorSpeech =
      'Telma 40 subah khane ke baad. Glycomet 500 subah aur raat khane ke '
      'baad, ek mahina. Meftal SOS. Shelcal tab kabhi kabhi. Come back after '
      'ten days for review.';

  testWidgets('step 1 · doctor words · en', (t) async {
    final c = await wizard();
    await shoot(t, c, 'wizard_1_doctor_words_en');
  });

  testWidgets('step 1 · doctor words · hi', (t) async {
    final c = await wizard();
    await shoot(t, c, 'wizard_2_doctor_words_hi', language: AppLanguage.hi);
  });

  testWidgets('step 2 · takeaways · en', (t) async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, doctorSpeech);
    await c.next();
    await shoot(t, c, 'wizard_3_takeaways_en', height: 1100);
  });

  testWidgets('step 2 · takeaways · hi', (t) async {
    final c = await wizard();
    c.setWords(SourceKind.doctor, doctorSpeech);
    await c.next();
    await shoot(
      t,
      c,
      'wizard_4_takeaways_hi',
      language: AppLanguage.hi,
      height: 1100,
    );
  });

  testWidgets('step 3 · photos, labelled', (t) async {
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg'), XFile('beach.jpg')]);
    await shoot(t, c, 'wizard_8_photos_en', height: 1100);
  });

  testWidgets('step 4 · pharmacy page', (t) async {
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile('rx.jpg')]);
    await c.next();
    c.setWords(SourceKind.chemist, 'Telma ki jagah Telmisartan de diya');
    await shoot(t, c, 'wizard_9_pharmacy_page_en');
  });

  testWidgets('step 5 · chemist takeaways', (t) async {
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile('rx.jpg')]);
    await c.next();
    c.setWords(
      SourceKind.chemist,
      'Telma ki jagah Telmisartan de diya. Glycomet 500 SR subah aur raat.',
    );
    await c.next();
    await shoot(t, c, 'wizard_10_chemist_takeaways_en');
  });

  testWidgets('step 6 · processing, on the device', (t) async {
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    await c.next();
    await c.skip();
    await shoot(t, c, 'wizard_11_processing_en');
  });

  testWidgets('step 7 · medicine cards', (t) async {
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    await c.next();
    await c.skip();
    await c.next();
    await shoot(t, c, 'wizard_5_medicines_en', height: 1000);
  });

  testWidgets('step 7 · cards with the sources disagreeing', (t) async {
    final c = await wizard(
      ocr: {
        'bill.jpg':
            '${billText.split('TOTAL').first}3 AMLONG 5 TAB  30 NOS  60.00',
        'rx.jpg': 'Rx\nTab Telma 40  1-0-0  p/c',
      },
    );
    c.setWords(SourceKind.doctor, 'Glycomet 500 BD p/c x 30 days. Meftal SOS.');
    await c.next();
    await c.next();
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    await c.next();
    await c.skip();
    await c.next();
    for (final r in c.rows) {
      if (c.canConfirm(r)) c.confirm(r);
    }
    await shoot(t, c, 'wizard_7_medicine_cards_sources_en', height: 1500);
  });

  testWidgets('step 8 · placement, then approve', (t) async {
    final c = await wizard();
    await c.store.approve(
      visitId: 'old',
      approved: [
        ScheduledMedicine(
          id: 'telma-40',
          name: 'TELMA 40',
          sig: const Sig(slots: [DoseSlot.morning]),
          startDate: DateTime(2026, 9, 1),
        ),
      ],
    );
    c.setWords(SourceKind.doctor, 'Ecosprin 75 tab');
    await c.next();
    c.toggleTakeaway(SourceKind.doctor, 0);
    await c.next();
    await c.addPhotos([XFile('bill.jpg'), XFile('rx.jpg')]);
    await c.next();
    await c.skip();
    await c.next();
    // The bill's 15 GLYCOMET against a 60-tablet course: the course stands.
    for (final q in c.questionsToAsk) {
      await c.answer(q, PharmacyChoice.a);
    }
    for (final r in c.rows) {
      if (!c.decisionOf(r).confirmed) c.confirm(r);
    }
    await c.next();
    await shoot(t, c, 'wizard_6_placement_en', height: 1000);
  });
}
