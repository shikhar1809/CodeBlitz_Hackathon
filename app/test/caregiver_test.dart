import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/app_strings.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/caregiver/caregiver_home.dart';
import 'package:winger/features/caregiver/caregiver_notifier.dart';
import 'package:winger/features/caregiver/plan_summary.dart';
import 'package:winger/features/caregiver/whatsapp_alerts.dart';
import 'package:winger/features/doses/dose_log_store.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

const en = AppStrings(AppLanguage.en);
const hi = AppStrings(AppLanguage.hi);
const m = DoseSlot.morning;
const n = DoseSlot.night;

final now = DateTime(2026, 9, 26, 10, 30);
final start = DateTime(2026, 9, 26);

final telma = ScheduledMedicine(
  id: 'telma-40',
  name: 'TELMA 40',
  sig: const Sig(slots: [m], food: FoodTiming.after),
  startDate: start,
  purpose: 'BP',
);
final glycomet = ScheduledMedicine(
  id: 'glycomet-500',
  name: 'GLYCOMET 500',
  sig: const Sig(slots: [m, n], food: FoodTiming.after, durationDays: 30),
  startDate: start,
);

WhatsAppAlerts twilio(
  List<http.Request> sent, {
  int status = 201,
  bool throws = false,
}) => WhatsAppAlerts(
  accountSid: 'AC123',
  authToken: 'tok',
  fromNumber: '+14155238886',
  client: MockClient((req) async {
    sent.add(req);
    if (throws) throw http.ClientException('no signal');
    return http.Response('{}', status);
  }),
);

void main() {
  group('phone numbers', () {
    test('every way a person types one', () {
      expect(WhatsAppAlerts.normalise('9876543210'), '+919876543210');
      expect(WhatsAppAlerts.normalise('98765 - 43210'), '+919876543210');
      expect(WhatsAppAlerts.normalise('919876543210'), '+919876543210');
      expect(WhatsAppAlerts.normalise('+919876543210'), '+919876543210');
      expect(WhatsAppAlerts.normalise('09876543210'), '+919876543210');
    });

    test('a typo is a visible error, not a message to nobody', () {
      expect(WhatsAppAlerts.normalise('98765'), isNull);
      expect(WhatsAppAlerts.normalise(''), isNull);
      expect(WhatsAppAlerts.normalise('not a number'), isNull);
      expect(WhatsAppAlerts.normalise(null), isNull);
    });

    test('the wa.me link needs no credentials', () {
      final u = WhatsAppAlerts.deepLink('+919876543210', 'Taken — TELMA 40');
      expect(u.host, 'wa.me');
      expect(u.path, '/919876543210');
      expect(u.queryParameters['text'], 'Taken — TELMA 40');
    });
  });

  group('Twilio', () {
    test('the request: Basic auth, whatsapp: prefixes, form body', () async {
      final sent = <http.Request>[];
      final r = await twilio(sent).sendAutomatic('9876543210', 'hello');
      expect(r.sent, isTrue);
      final req = sent.single;
      expect(req.url.path, '/2010-04-01/Accounts/AC123/Messages.json');
      expect(
        req.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('AC123:tok'))}',
      );
      expect(req.bodyFields, {
        'From': 'whatsapp:+14155238886',
        'To': 'whatsapp:+919876543210',
        'Body': 'hello',
      });
    });

    test('no signal is worth retrying; a rejected number never is', () async {
      final noSignal = await twilio(
        [],
        throws: true,
      ).sendAutomatic('9876543210', 'x');
      expect(noSignal.retryable, isTrue);
      final busy = await twilio(
        [],
        status: 503,
      ).sendAutomatic('9876543210', 'x');
      expect(busy.retryable, isTrue);
      final bad = await twilio(
        [],
        status: 400,
      ).sendAutomatic('9876543210', 'x');
      expect(bad.retryable, isFalse);
    });

    test('without credentials a person sends it: WhatsApp opens', () async {
      Uri? opened;
      final alerts = WhatsAppAlerts(
        accountSid: '',
        authToken: '',
        fromNumber: '',
        launcher: (u) async {
          opened = u;
          return true;
        },
      );
      expect(
        await alerts.send('9876543210', 'status'),
        AlertDelivery.openedInWhatsApp,
      );
      expect(opened!.host, 'wa.me');
    });
  });

  group('the messages', () {
    test('the plan, in plain words, with the doctor quoted', () {
      final text = PlanSummary.plan(
        name: 'Ramesh',
        medicines: [telma, glycomet],
        today: now,
        s: en,
      );
      expect(text, startsWith('Medicine plan — Ramesh'));
      expect(
        text,
        contains(
          '• Take TELMA 40 in the morning, after food. '
          'The doctor said this is for "BP".',
        ),
      );
      expect(
        text,
        contains(
          '• Take GLYCOMET 500 in the morning and at night, after food, '
          'for 30 more days.',
        ),
      );
      expect(text, endsWith('This is not medical advice.'));
    });

    test('Hindi message, English medicine names', () {
      final text = PlanSummary.plan(
        name: 'रमेश',
        medicines: [telma],
        today: now,
        s: hi,
      );
      expect(text, contains('TELMA 40'));
      expect(text, contains('खाने के बाद'));
    });

    test('today\'s status, slot by slot', () async {
      SharedPreferences.setMockInitialValues({});
      final logs = await DoseLogStore.load();
      await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
      final text = PlanSummary.status(
        name: 'Ramesh',
        medicines: [telma, glycomet],
        logs: logs,
        now: now,
        s: en,
      );
      expect(text, contains('26/09/2026'));
      expect(text, contains('Morning: Taken — TELMA 40, GLYCOMET 500'));
      expect(text, contains('Night: Not yet — GLYCOMET 500'));
    });

    test('a miss found later names the day, never "right now"', () {
      expect(
        PlanSummary.alert(
          name: 'Ramesh',
          slot: n,
          taken: false,
          date: now.subtract(const Duration(days: 1)),
          now: now,
          s: en,
        ),
        'Ramesh: Night medicines on 25/09 were missed.',
      );
      expect(
        PlanSummary.alert(
          name: 'Ramesh',
          slot: m,
          taken: false,
          date: now,
          now: now,
          s: en,
        ),
        'Ramesh: Morning medicines were missed.',
      );
    });
  });

  group('CaregiverNotifier', () {
    late SharedPreferences prefs;
    late DoseLogStore logs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      logs = await DoseLogStore.load();
    });

    CaregiverNotifier notifier(
      WhatsAppAlerts a, {
      String? phone = '9812345678',
    }) => CaregiverNotifier(
      alerts: a,
      prefs: prefs,
      patientName: 'Ramesh',
      caregiverPhone: phone,
      strings: en,
    );

    test('once per slot per day: reopening never re-announces', () async {
      final sent = <http.Request>[];
      final c = notifier(twilio(sent));
      await c.checkMissed([telma], logs, now: now);
      await c.checkMissed([telma], logs, now: now);
      expect(sent, hasLength(1));
      expect(
        sent.single.bodyFields['Body'],
        'Ramesh: Morning medicines were missed.',
      );
    });

    test(
      'automatic only: with no Twilio, nothing opens on the patient\'s screen',
      () async {
        var opened = false;
        final c = notifier(
          WhatsAppAlerts(
            accountSid: '',
            authToken: '',
            fromNumber: '',
            launcher: (_) async => opened = true,
          ),
        );
        expect(await c.doseTaken(m, now, now: now), NotifyResult.notConfigured);
        expect(opened, isFalse);
      },
    );

    test('no family number: nothing is sent to nobody', () async {
      final sent = <http.Request>[];
      final c = notifier(twilio(sent), phone: null);
      expect(await c.doseTaken(m, now, now: now), NotifyResult.noNumber);
      expect(sent, isEmpty);
    });

    test('no signal: queued, remembered, and sent on the next drain', () async {
      final c = notifier(twilio([], throws: true));
      expect(await c.doseTaken(m, now, now: now), NotifyResult.queued);
      expect(c.outbox.all(), hasLength(1));
      // Reopening does not send it fresh as well.
      expect(await c.doseTaken(m, now, now: now), NotifyResult.alreadySent);

      final sent = <http.Request>[];
      final later = notifier(twilio(sent));
      expect(await later.drainOutbox(now: now), 1);
      expect(sent, hasLength(1));
      expect(later.outbox.all(), isEmpty);
    });

    test(
      'a rejected message is never queued: it would retry forever',
      () async {
        final c = notifier(twilio([], status: 400));
        expect(await c.doseTaken(m, now, now: now), NotifyResult.failed);
        expect(c.outbox.all(), isEmpty);
      },
    );

    test('yesterday\'s night miss is found this morning', () async {
      final sent = <http.Request>[];
      final c = notifier(twilio(sent));
      final morning = DateTime(2026, 9, 27, 7);
      await c.checkMissed([glycomet], logs, now: morning);
      expect(
        sent.map((r) => r.bodyFields['Body']),
        contains('Ramesh: Morning medicines on 26/09 were missed.'),
      );
    });
  });

  group('caregiver home', () {
    Future<void> shoot(
      WidgetTester tester,
      String name, {
      AppLanguage language = AppLanguage.en,
      bool filled = true,
    }) async {
      usePhoneSurface(tester);
      final state = await freshState(
        language: language,
        values: {
          'user_name': 'Ramesh',
          if (filled) 'backup_phone': '9876543210',
        },
      );
      final store = await MedicineStore.load();
      final logs = await DoseLogStore.load();
      if (filled) {
        await store.approve(
          visitId: 'v1',
          approved: [telma, glycomet],
          at: now,
        );
        await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
      }
      await tester.pumpWidget(
        themed(
          CaregiverHome(
            onRestart: () {},
            store: store,
            logs: logs,
            clock: () => now,
          ),
          language: language,
          state: state,
        ),
      );
      await precacheLogo(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('empty', (t) => shoot(t, 'caregiver_home_en', filled: false));
    testWidgets('populated', (t) => shoot(t, 'caregiver_home_full_en'));
    testWidgets(
      'Hindi',
      (t) => shoot(
        t,
        'caregiver_home_hi',
        language: AppLanguage.hi,
        filled: false,
      ),
    );
  });
}
