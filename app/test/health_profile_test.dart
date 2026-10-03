import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/features/health/health_profile.dart';
import 'package:winger/features/health/health_profile_controller.dart';
import 'package:winger/features/health/health_profile_screen.dart';
import 'package:winger/features/health/pmjay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

void main() {
  group('validation', () {
    test('age is required, 1–120', () {
      expect(HealthProfile.checkAge(''), HealthError.missing);
      expect(HealthProfile.checkAge('0'), HealthError.outOfRange);
      expect(HealthProfile.checkAge('121'), HealthError.outOfRange);
      expect(HealthProfile.checkAge('64'), isNull);
    });

    test('height and weight are optional, but not nonsense', () {
      expect(HealthProfile.checkOptional('', 50, 250), isNull);
      expect(
        HealthProfile.checkOptional('20', 50, 250),
        HealthError.outOfRange,
      );
      expect(HealthProfile.checkOptional('165', 50, 250), isNull);
    });
  });

  group('PM-JAY mock', () {
    final pmjay = MockPmjayClient(delay: Duration.zero);

    test('found: deterministic per ID, and marked as demo data', () async {
      final a = await pmjay.fetch(MockPmjayClient.demoId);
      final b = await pmjay.fetch('pmj 4k7q-2x');
      expect(a, isA<PmjayFound>());
      final ca = (a as PmjayFound).card, cb = (b as PmjayFound).card;
      expect(ca.demo, isTrue);
      expect(ca.name, cb.name);
      expect(ca.familyId, cb.familyId);
      expect(ca.cover, '₹5 lakh');
    });

    test('not found', () async {
      expect(
        await pmjay.fetch(MockPmjayClient.notFoundId),
        isA<PmjayNotFound>(),
      );
    });

    test('bad format', () async {
      expect(await pmjay.fetch('12345'), isA<PmjayBadFormat>());
      expect(
        await pmjay.fetch('123456789'),
        isA<PmjayBadFormat>(),
        reason: 'digits only is not an ID',
      );
    });

    test('it waits, like a real lookup would', () async {
      final slow = MockPmjayClient(delay: const Duration(milliseconds: 30));
      final sw = Stopwatch()..start();
      await slow.fetch(MockPmjayClient.demoId);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(25));
    });
  });

  group('controller', () {
    late AppPrefs prefs;
    late HealthProfileController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPrefs.load();
      c = HealthProfileController(
        prefs: prefs,
        pmjay: MockPmjayClient(delay: Duration.zero),
      );
    });

    Future<bool> submit({String age = '64', String id = ''}) =>
        c.submit(age: age, height: '', weight: '', ayushmanId: id);

    test('nothing is saved while the age is missing', () async {
      expect(await submit(age: ''), isFalse);
      expect(c.ageError, HealthError.missing);
      expect(prefs.age, isNull);
    });

    test('a bad ID is an inline error, and nothing is fetched', () async {
      await c.fetch('abc');
      expect(c.state, PmjayState.badFormat);
      expect(c.card, isNull);
    });

    test('a card is only saved once the patient says it is theirs', () async {
      await c.fetch(MockPmjayClient.demoId);
      expect(c.state, PmjayState.found);
      await submit(id: MockPmjayClient.demoId);
      expect(prefs.ayushmanCardJson, isNull, reason: 'not confirmed');

      c.confirmCard();
      await submit(id: MockPmjayClient.demoId);
      final saved = jsonDecode(prefs.ayushmanCardJson!) as Map;
      expect(saved['pmjayId'], MockPmjayClient.demoId);
      expect(saved['demo'], isTrue);
    });

    test('"not me" throws the card away', () async {
      await c.fetch(MockPmjayClient.demoId);
      c.rejectCard();
      expect(c.card, isNull);
      expect(c.state, PmjayState.idle);
    });
  });

  group('goldens', () {
    Future<void> shoot(
      WidgetTester tester,
      String name, {
      AppLanguage language = AppLanguage.en,
      bool withCard = false,
    }) async {
      usePhoneSurface(tester, size: const Size(412, 1100));
      SharedPreferences.setMockInitialValues({});
      final c = HealthProfileController(
        prefs: await AppPrefs.load(),
        pmjay: MockPmjayClient(delay: Duration.zero),
      );
      // A real delay, even a zero one, never fires under fake time.
      if (withCard) {
        await tester.runAsync(() => c.fetch(MockPmjayClient.demoId));
      }
      await tester.pumpWidget(
        themed(
          HealthProfileScreen(controller: c, onDone: () {}),
          language: language,
        ),
      );
      await precacheLogo(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('health · en', (t) => shoot(t, 'onboarding_12_health_en'));
    testWidgets(
      'health · hi',
      (t) => shoot(t, 'onboarding_13_health_hi', language: AppLanguage.hi),
    );
    testWidgets(
      'health · PM-JAY card · en',
      (t) => shoot(t, 'onboarding_14_health_card_en', withCard: true),
    );
    testWidgets(
      'health · PM-JAY card · hi',
      (t) => shoot(
        t,
        'onboarding_15_health_card_hi',
        language: AppLanguage.hi,
        withCard: true,
      ),
    );
  });
}
