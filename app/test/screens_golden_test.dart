import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/features/onboarding/language_screen.dart';
import 'package:winger/features/onboarding/phone_screens.dart';
import 'package:winger/features/onboarding/role_screen.dart';
import 'package:winger/features/onboarding/saving_screen.dart';
import 'package:winger/features/onboarding/splash_screen.dart';
import 'package:winger/features/onboarding/voice_help_screen.dart';
import 'package:winger/features/patient/patient_menu.dart';
import 'package:winger/features/patient/prescriptions_screen.dart';

import 'support/golden_harness.dart';

const en = AppLanguage.en;
const hi = AppLanguage.hi;

void main() {
  Future<void> golden(
    WidgetTester tester,
    Widget screen,
    String name, {
    AppLanguage language = en,
    bool withState = false,
  }) async {
    usePhoneSurface(tester);
    final state = withState
        ? await freshState(
            language: language,
            values: const {'user_name': 'Ramesh'},
          )
        : null;
    await tester.pumpWidget(themed(screen, language: language, state: state));
    await precacheLogo(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    // Let any screen timers finish so the test ends clean.
    await tester.pumpWidget(const SizedBox());
  }

  group('onboarding goldens', () {
    testWidgets(
      'splash en',
      (t) => golden(
        t,
        SplashScreen(onDone: () {}, language: en),
        'onboarding_1_splash_en',
      ),
    );
    testWidgets(
      'splash hi',
      (t) => golden(
        t,
        SplashScreen(onDone: () {}, language: hi),
        'onboarding_2_splash_hi',
      ),
    );
    testWidgets(
      'language',
      (t) =>
          golden(t, LanguageScreen(onChosen: (_) {}), 'onboarding_3_language'),
    );
    testWidgets(
      'saving hi',
      (t) => golden(
        t,
        SavingScreen(onDone: () {}),
        'onboarding_4_saving_hi',
        language: hi,
      ),
    );
    testWidgets(
      'voice hi',
      (t) => golden(
        t,
        VoiceHelpScreen(onChosen: (_) {}),
        'onboarding_5_voice_hi',
        language: hi,
      ),
    );
    testWidgets(
      'phone en',
      (t) =>
          golden(t, PhoneScreen(onSubmitted: (_) {}), 'onboarding_6_phone_en'),
    );
    testWidgets(
      'otp en',
      (t) => golden(
        t,
        OtpScreen(phone: '9876543210', onVerified: () {}),
        'onboarding_7_otp_en',
      ),
    );
    testWidgets(
      'profile hi',
      (t) => golden(
        t,
        ProfileScreen(onSubmitted: (_) {}),
        'onboarding_8_profile_hi',
        language: hi,
      ),
    );
    testWidgets(
      'pin en',
      (t) => golden(t, PinScreen(onSubmitted: (_) {}), 'onboarding_9_pin_en'),
    );
    testWidgets(
      'role en',
      (t) => golden(t, RoleScreen(onChosen: (_) {}), 'onboarding_10_role_en'),
    );
    testWidgets(
      'role hi',
      (t) => golden(
        t,
        RoleScreen(onChosen: (_) {}),
        'onboarding_11_role_hi',
        language: hi,
      ),
    );
  });

  group('patient goldens', () {
    testWidgets(
      'menu hi',
      (t) => golden(
        t,
        PatientMenu(onRestart: () {}),
        'patient_1_menu_hi',
        language: hi,
        withState: true,
      ),
    );
    testWidgets(
      'menu en',
      (t) => golden(
        t,
        PatientMenu(onRestart: () {}),
        'patient_2_menu_en',
        withState: true,
      ),
    );
    testWidgets(
      'prescriptions empty hi',
      (t) => golden(
        t,
        const PrescriptionsScreen(),
        'patient_4_prescriptions_hi',
        language: hi,
      ),
    );
  });

  group('onboarding behaviour', () {
    testWidgets('choosing a role reports it', (tester) async {
      usePhoneSurface(tester);
      AppRole? chosen;
      await tester.pumpWidget(themed(RoleScreen(onChosen: (r) => chosen = r)));
      await tester.tap(find.text('CAREGIVER'));
      expect(chosen, AppRole.caregiver);
    });

    testWidgets('the wrong OTP is refused, the demo code is accepted', (
      tester,
    ) async {
      usePhoneSurface(tester);
      var verified = false;
      await tester.pumpWidget(
        themed(
          OtpScreen(phone: '9876543210', onVerified: () => verified = true),
        ),
      );
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(verified, isFalse);
      expect(find.text('That code is not right. Try again.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), demoOtp);
      await tester.tap(find.text('Verify'));
      expect(verified, isTrue);
    });

    testWidgets('a short phone number is an error, not a submission', (
      tester,
    ) async {
      usePhoneSurface(tester);
      String? submitted;
      await tester.pumpWidget(
        themed(PhoneScreen(onSubmitted: (p) => submitted = p)),
      );
      await tester.enterText(find.byType(TextField), '98765');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(submitted, isNull);
      expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    });

    testWidgets('the menu shows every tile without scrolling', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final state = await freshState();
      await tester.pumpWidget(
        themed(PatientMenu(onRestart: () {}), state: state),
      );
      for (final label in [
        'New prescription',
        'My prescriptions',
        'Medicine schedule',
        'Scan caretaker QR',
      ]) {
        final box = tester.getRect(find.text(label));
        expect(box.bottom, lessThan(phoneSize.height), reason: label);
      }
      expect(find.byType(ListView), findsNothing);
      // The demo link sits under the tiles, on screen too.
      expect(
        tester.getRect(find.text('Dose demo')).bottom,
        lessThan(phoneSize.height),
      );
    });

    testWidgets('the demo link is gone when the demo tools are off', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final state = await freshState();
      await tester.pumpWidget(
        themed(PatientMenu(onRestart: () {}, demoTools: false), state: state),
      );
      expect(find.text('Dose demo'), findsNothing);
    });

    testWidgets('the dose demo shows the alarm, and saves nothing', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final state = await freshState();
      await tester.pumpWidget(
        themed(PatientMenu(onRestart: () {}), state: state),
      );
      await tester.tap(find.text('Dose demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show the alarm now'));
      await tester.pumpAndSettle();

      // An empty schedule: the clearly named demo medicine.
      expect(find.text('DEMO MEDICINE 500'), findsOneWidget);
      expect(find.text('Demo — nothing on this screen is saved'), findsOne);
      await tester.tap(find.text('Yes, taken'));
      await tester.pumpAndSettle();
      expect(find.text('Demo finished. Nothing was saved.'), findsOneWidget);
      expect(state.prefs.raw.getString('dose_logs'), isNull);
    });

    testWidgets('ringing the demo says where it works', (tester) async {
      usePhoneSurface(tester);
      final state = await freshState();
      await tester.pumpWidget(
        themed(PatientMenu(onRestart: () {}), state: state),
      );
      await tester.tap(find.text('Dose demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ring in 15 seconds'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ringing only works in the Android app.'),
        findsOneWidget,
      );
    });
  });
}
