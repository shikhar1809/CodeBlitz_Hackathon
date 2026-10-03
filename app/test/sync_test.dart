import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winger/ai/gemini_client.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/app_strings.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/features/health/health_profile_controller.dart';
import 'package:winger/features/health/pmjay_client.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:winger/features/patient/prescriptions_screen.dart';
import 'package:winger/features/sync/sync_queue.dart';
import 'package:winger/features/sync/sync_service.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/features/wizard/wizard_models.dart';
import 'package:winger/features/wizard/wizard_screen.dart';
import 'package:winger/platform/gallery_scanner.dart';
import 'package:winger/platform/network_status.dart';
import 'package:winger/platform/notices.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';
import 'support/wizard_fakes.dart';

const en = AppStrings(AppLanguage.en);

SyncJob job(String id, {String kind = 'x', DateTime? at}) => SyncJob(
  id: id,
  kind: kind,
  payload: const {},
  createdAt: at ?? DateTime(2026, 9, 26, 9),
);

String geminiReply() => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {
            'text': jsonEncode({
              'medicines': [
                {
                  'name': 'Telma 40',
                  'strength': '',
                  'instruction': '1-0-1',
                  'raw': 'Tab Telma 40 1-0-1',
                  'uncertain': false,
                },
              ],
              'notes': [],
            }),
          },
        ],
      },
    },
  ],
});

void main() {
  late SharedPreferences prefs;
  final now = DateTime(2026, 9, 26, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SyncQueue', () {
    test('drains in order, and survives a restart', () async {
      final q = SyncQueue(prefs);
      await q.add(job('b', at: DateTime(2026, 9, 26, 9, 5)));
      await q.add(job('a', at: DateTime(2026, 9, 26, 9, 1)));
      final order = <String>[];
      final again = SyncQueue(prefs); // a fresh process
      final r = await again.drain({
        'x': (j) async {
          order.add(j.id);
          return JobResult.done;
        },
      }, now: now);
      expect(order, ['a', 'b']);
      expect(r.allSynced, isTrue);
      expect(again.isEmpty, isTrue);
    });

    test('a retry backs off; a permanent failure is dropped', () async {
      final q = SyncQueue(prefs);
      await q.add(job('retry'));
      await q.add(job('fail'));
      final r = await q.drain({
        'x': (j) async => j.id == 'retry' ? JobResult.retry : JobResult.failed,
      }, now: now);
      expect(r.failed, 1);
      expect(r.remaining, 1);
      final left = q.all().single;
      expect(left.attempts, 1);
      expect(left.notBefore, now.add(const Duration(seconds: 15)));

      var ran = false;
      await q.drain({
        'x': (_) async {
          ran = true;
          return JobResult.done;
        },
      }, now: now.add(const Duration(seconds: 5)));
      expect(ran, isFalse, reason: 'still backing off');
    });

    test('backoff doubles and is capped', () {
      expect(SyncQueue.backoff(1), const Duration(seconds: 15));
      expect(SyncQueue.backoff(3), const Duration(seconds: 60));
      expect(SyncQueue.backoff(30), const Duration(minutes: 30));
    });

    test('a visit waiting for a job says so', () async {
      final q = SyncQueue(prefs);
      await q.add(
        SyncJob(
          id: 'g',
          kind: 'gemini',
          payload: const {},
          createdAt: now,
          visitId: 'v1',
        ),
      );
      expect(q.waitingFor('v1'), isTrue);
      expect(q.waitingFor('v2'), isFalse);
    });
  });

  group('offline → saved → queued → drained on reconnect', () {
    late FakeNetworkStatus net;
    late FakeNotices notices;
    late MedicineStore store;
    late Directory tmp;
    late String photo;

    setUp(() async {
      net = FakeNetworkStatus(online: false);
      notices = FakeNotices();
      store = MedicineStore(prefs);
      tmp = Directory.systemTemp.createTempSync('rx');
      photo = '${tmp.path}/rx.jpg';
      File(photo).writeAsBytesSync([1, 2, 3]);
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    SyncService service({List<String>? calls}) => SyncService(
      queue: SyncQueue(prefs),
      network: net,
      notices: notices,
      strings: en,
      store: store,
      clock: () => now,
      gemini: () => GeminiClient(
        apiKey: 'k',
        client: MockClient((_) async {
          calls?.add('gemini');
          return http.Response(geminiReply(), 200);
        }),
      ),
    );

    test('a capture with no signal: banner flag and one notice', () async {
      final sync = service();
      final c = await wizard();
      final withSync = VisitWizardController(
        visit: c.visit,
        repository: c.repository,
        store: c.store,
        media: c.media,
        recogniser: c.recogniser,
        sync: sync,
      );
      withSync.setWords(SourceKind.doctor, 'Telma 40 subah');
      await Future<void>.delayed(Duration.zero);
      withSync.setWords(SourceKind.doctor, 'Telma 40 subah, raat');
      await Future<void>.delayed(Duration.zero);
      expect(withSync.offline, isTrue);
      expect(notices.shown.map((n) => n.$1), [NoticeIds.offline]);
      expect(notices.shown.single.$3, en.offlineSaved);
      expect(
        withSync.repository.loadDraft()!.doctorWords,
        'Telma 40 subah, raat',
        reason: 'saved on the phone, nothing blocked',
      );
    });

    test(
      'approval offline queues the handwriting read; reconnect drains it, '
      'and the reading waits for review without touching the schedule',
      () async {
        final calls = <String>[];
        final sync = service(calls: calls)..start();
        final base = await wizard(ocr: {'rx.jpg': 'Rx\nTab Telma 40 1-0-1'});
        final c = VisitWizardController(
          visit: base.visit,
          repository: base.repository,
          store: store,
          media: base.media,
          recogniser: base.recogniser,
          clock: () => now,
          sync: sync,
          readOnlineLater: true,
        );
        await c.skip();
        await c.addPhotos([XFile(photo)]);
        while (c.step != WizardStep.medicines) {
          c.step == WizardStep.pharmacyWords ? await c.skip() : await c.next();
        }
        for (final r in c.rows) {
          c.canConfirm(r) ? c.confirm(r) : c.leaveOut(r);
        }
        await c.next();
        await c.approve();

        expect(sync.queue.waitingFor('v1'), isTrue);
        expect(calls, isEmpty, reason: 'offline: nothing was sent');
        final before = store.active().map((m) => m.toJson()).toList();

        net.online = true;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await sync.drainNow();

        expect(calls, ['gemini']);
        expect(sync.queue.isEmpty, isTrue);
        final record = store.records().single;
        expect(record.onlineReading, contains('Telma 40'));
        expect(
          store.active().map((m) => m.toJson()).toList(),
          before,
          reason: 'a late reading never changes the schedule on its own',
        );
        expect(
          notices.shown.map((n) => n.$1),
          containsAll([NoticeIds.newReading, NoticeIds.synced]),
        );
        await sync.dispose();
      },
    );

    test('online at approval: nothing is queued', () async {
      net.online = true;
      final sync = service();
      final base = await wizard();
      final c = VisitWizardController(
        visit: base.visit,
        repository: base.repository,
        store: store,
        media: base.media,
        recogniser: base.recogniser,
        sync: sync,
        readOnlineLater: true,
      );
      await c.approve();
      expect(sync.queue.isEmpty, isTrue);
    });

    test('a PM-JAY lookup with no signal is queued, then found later '
        'and kept unconfirmed', () async {
      String? found;
      final sync = SyncService(
        queue: SyncQueue(prefs),
        network: net,
        notices: notices,
        strings: en,
        pmjay: MockPmjayClient(delay: Duration.zero),
        onPmjayCard: (card) async => found = card.pmjayId,
        clock: () => now,
      );
      final health = HealthProfileController(
        prefs: AppPrefs(prefs),
        pmjay: MockPmjayClient(delay: Duration.zero),
        sync: sync,
      );
      await health.fetch(MockPmjayClient.demoId);
      expect(health.state, PmjayState.queued);
      expect(found, isNull);

      net.online = true;
      await sync.drainNow();
      expect(found, MockPmjayClient.demoId);
    });
  });

  group('screens', () {
    testWidgets('the wizard shows the offline banner, and carries on', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final c = await wizard();
      c.offline = true;
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
      expect(find.text(en.offlineSaved), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sync_1_offline_banner_en.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });

    for (final lang in AppLanguage.values) {
      testWidgets('prescriptions show their sync state · ${lang.code}', (
        tester,
      ) async {
        usePhoneSurface(tester);
        final records = [
          PrescriptionRecord(
            id: 'v2',
            addedAt: DateTime(2026, 9, 26),
            medicineNames: const ['TELMA 40', 'GLYCOMET 500'],
            evidence: const ['doctor', 'bill'],
            onlineReading: '[]',
          ),
          PrescriptionRecord(
            id: 'v1',
            addedAt: DateTime(2026, 9, 20),
            medicineNames: const ['ECOSPRIN 75'],
          ),
        ];
        await tester.pumpWidget(
          themed(
            PrescriptionsScreen(records: records, waiting: const {'v2'}),
            language: lang,
          ),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/sync_2_prescriptions_${lang.code}.png'),
        );
      });
    }
  });
}
