import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/features/hub/booking_progress_screen.dart';
import 'package:winger/features/hub/hub_client.dart';
import 'package:winger/features/hub/hub_pairing_code.dart';

import 'support/golden_harness.dart';

const hubUrl = 'http://192.168.1.20:8787';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<AppPrefs> pairedPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await AppPrefs.load();
  await prefs.setHubLink(
    url: hubUrl,
    token: 'tok-1',
    deviceId: 'dev-1',
    name: 'Study laptop',
  );
  return prefs;
}

Map<String, Object?> jobJson(
  String status, {
  Object? question,
  Object? approval,
  Object? result,
  Object? error,
}) => {
  'id': 'job-7',
  'status': status,
  'steps': [
    {'at': 1760000000000, 'text': 'Opened the clinic website'},
  ],
  'question': question,
  'approval': approval,
  'result': result,
  'error': error,
};

void main() {
  group('pairing QR', () {
    test('a good code gives the address, the code and the name', () {
      final c = HubPairingCode.parse(
        'winger-hub:1?u=${Uri.encodeComponent(hubUrl)}&c=482913'
        '&n=${Uri.encodeComponent("Ramesh's laptop")}',
      )!;
      expect(c.baseUrl, hubUrl);
      expect(c.code, '482913');
      expect(c.hubName, "Ramesh's laptop");
    });

    test('a missing name falls back; a trailing slash is dropped', () {
      final c = HubPairingCode.parse(
        'winger-hub:1?u=${Uri.encodeComponent('$hubUrl/')}&c=000111',
      )!;
      expect(c.baseUrl, hubUrl);
      expect(c.hubName, 'Winger Hub');
    });

    test('anything else is refused', () {
      for (final raw in [
        '',
        'hello',
        'RXC1.abc.def',
        // Missing fields.
        'winger-hub:1?c=482913',
        'winger-hub:1?u=${Uri.encodeComponent(hubUrl)}',
        // A code that is not six digits.
        'winger-hub:1?u=${Uri.encodeComponent(hubUrl)}&c=4829',
        'winger-hub:1?u=${Uri.encodeComponent(hubUrl)}&c=48291a',
        // Another version, another scheme, a non-web address.
        'winger-hub:2?u=${Uri.encodeComponent(hubUrl)}&c=482913',
        'https://example.com/?u=x&c=482913',
        'winger-hub:1?u=${Uri.encodeComponent('ftp://1.2.3.4')}&c=482913',
        // A broken percent-escape.
        'winger-hub:1?u=%E0%A4&c=482913',
      ]) {
        expect(HubPairingCode.parse(raw), isNull, reason: raw);
      }
    });

    test('a typed address gets a scheme and the default port', () {
      expect(normaliseHubUrl('192.168.1.20'), hubUrl);
      expect(
        normaliseHubUrl(' 192.168.1.20:9000 '),
        'http://192.168.1.20:9000',
      );
      expect(
        normaliseHubUrl('http://localhost:8787/'),
        'http://localhost:8787',
      );
      expect(normaliseHubUrl(''), isNull);
      final typed = HubPairingCode.typed(
        address: '192.168.1.20',
        code: '482 913',
      );
      expect(typed!.code, '482913');
      expect(HubPairingCode.typed(address: '192.168.1.20', code: '12'), isNull);
    });
  });

  group('HubClient', () {
    test('pairing sends the code and name, and returns the token', () async {
      late http.Request sent;
      final client = HubClient(
        baseUrl: hubUrl,
        client: MockClient((req) async {
          sent = req;
          return json({
            'deviceId': 'dev-9',
            'token': 'secret',
            'hub': {'name': 'Study laptop', 'version': '0.1.0'},
          });
        }),
      );
      final r = await client.pair(code: '482913', deviceName: "Ramesh's phone");
      expect(sent.method, 'POST');
      expect(sent.url.toString(), '$hubUrl/api/pair');
      expect(sent.headers['Authorization'], isNull);
      expect(jsonDecode(sent.body), {
        'code': '482913',
        'name': "Ramesh's phone",
      });
      expect(r.token, 'secret');
      expect(r.deviceId, 'dev-9');
      expect(r.hubName, 'Study laptop');
    });

    test('a wrong code is a 403, too many tries a 429', () async {
      HubClient replying(int status) => HubClient(
        baseUrl: hubUrl,
        client: MockClient((_) async => json({'error': 'nope'}, status)),
      );
      await expectLater(
        replying(403).pair(code: '000000', deviceName: 'x'),
        throwsA(
          isA<HubException>().having(
            (e) => e.problem,
            'problem',
            HubProblem.wrongCode,
          ),
        ),
      );
      await expectLater(
        replying(429).pair(code: '000000', deviceName: 'x'),
        throwsA(
          isA<HubException>().having(
            (e) => e.problem,
            'problem',
            HubProblem.tooManyTries,
          ),
        ),
      );
    });

    test('no answer is "unreachable", not a crash', () async {
      final client = HubClient(
        baseUrl: hubUrl,
        client: MockClient((_) async => throw http.ClientException('no route')),
      );
      await expectLater(
        client.health(),
        throwsA(
          isA<HubException>().having(
            (e) => e.problem,
            'problem',
            HubProblem.unreachable,
          ),
        ),
      );
    });

    test('a 401 forgets the link and says so', () async {
      final prefs = await pairedPrefs();
      final client = HubClient.fromPrefs(
        prefs,
        client: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer tok-1');
          return json({'error': 'unknown device'}, 401);
        }),
      )!;
      await expectLater(
        client.me(),
        throwsA(
          isA<HubException>().having(
            (e) => e.problem,
            'problem',
            HubProblem.unlinked,
          ),
        ),
      );
      expect(prefs.hasHub, isFalse);
      expect(prefs.hubToken, isNull);
      expect(prefs.hubName, isNull);
      expect(HubClient.fromPrefs(prefs), isNull);
    });

    test('a booking request is the contract, word for word', () async {
      late http.Request sent;
      final client = HubClient(
        baseUrl: hubUrl,
        token: 'tok-1',
        client: MockClient((req) async {
          sent = req;
          return json({'id': 'job-7'});
        }),
      );
      final id = await client.startBooking(
        BookingRequest(
          url: 'https://wingercodeblitz.web.app/clinic/',
          patientName: 'Ramesh',
          patientAge: 67,
          patientGender: 'Male',
          patientPhone: '9876543210',
          department: 'Cardiology',
          date: DateTime(2026, 10, 5),
          timeOfDay: TimeOfDayChoice.morning,
          reason: 'BP check',
        ),
      );
      expect(id, 'job-7');
      expect(sent.url.path, '/api/agent/jobs');
      expect(sent.headers['Authorization'], 'Bearer tok-1');
      expect(jsonDecode(sent.body), {
        'kind': 'book_appointment',
        'url': 'https://wingercodeblitz.web.app/clinic/',
        'patient': {
          'name': 'Ramesh',
          'age': 67,
          'gender': 'Male',
          'phone': '9876543210',
        },
        'request': {
          'department': 'Cardiology',
          'doctor': '',
          'date': '2026-10-05',
          'timeOfDay': 'morning',
          'reason': 'BP check',
        },
      });
    });

    test('polling a job reads every state the Hub can be in', () async {
      final replies = [
        jobJson('queued'),
        jobJson('running'),
        jobJson('needs_input', question: 'Type the OTP sent to 98XXXXXX10'),
        jobJson(
          'needs_approval',
          approval: {
            'summary': 'Dr. Mehta, Cardiology',
            'fields': [
              {'label': 'Date', 'value': '5 Oct 2026, 10:30'},
            ],
          },
        ),
        jobJson('done', result: 'Booked: token 14'),
        jobJson('failed', error: 'No slots left'),
        jobJson('cancelled'),
        jobJson('something_new'),
      ];
      var i = 0;
      final client = HubClient(
        baseUrl: hubUrl,
        token: 'tok-1',
        client: MockClient((req) async {
          expect(req.url.path, '/api/agent/jobs/job-7');
          return json(replies[i++]);
        }),
      );
      final jobs = [for (final _ in replies) await client.job('job-7')];
      expect(jobs.map((j) => j.status), [
        HubJobStatus.queued,
        HubJobStatus.running,
        HubJobStatus.needsInput,
        HubJobStatus.needsApproval,
        HubJobStatus.done,
        HubJobStatus.failed,
        HubJobStatus.cancelled,
        // Unknown: keep watching.
        HubJobStatus.running,
      ]);
      expect(jobs.map((j) => j.status.isFinal), [
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
      ]);
      expect(jobs[0].steps.single.text, 'Opened the clinic website');
      expect(jobs[2].question, 'Type the OTP sent to 98XXXXXX10');
      expect(jobs[3].approval!.summary, 'Dr. Mehta, Cardiology');
      expect(jobs[3].approval!.fields.single.value, '5 Oct 2026, 10:30');
      expect(jobs[4].result, 'Booked: token 14');
      expect(jobs[5].error, 'No slots left');
    });

    test('answer, approve and cancel post to their routes', () async {
      final sent = <http.Request>[];
      final client = HubClient(
        baseUrl: hubUrl,
        token: 'tok-1',
        client: MockClient((req) async {
          sent.add(req);
          return json({'ok': true});
        }),
      );
      await client.answer('job-7', '123456');
      await client.approve('job-7', approve: false);
      await client.cancel('job-7');
      expect(sent.map((r) => r.url.path), [
        '/api/agent/jobs/job-7/answer',
        '/api/agent/jobs/job-7/approve',
        '/api/agent/jobs/job-7/cancel',
      ]);
      expect(jsonDecode(sent[0].body), {'text': '123456'});
      expect(jsonDecode(sent[1].body), {'approve': false});
      expect(jsonDecode(sent[2].body), <String, Object?>{});
    });
  });

  group('BookingProgressScreen', () {
    testWidgets('the approval gate shows two buttons and only a tap approves', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final state = await freshState();
      var status = 'needs_approval';
      final approvals = <Object?>[];
      final client = HubClient(
        baseUrl: hubUrl,
        token: 'tok-1',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/approve')) {
            approvals.add(jsonDecode(req.body)['approve']);
            status = 'done';
            return json({'ok': true});
          }
          return json(
            jobJson(
              status,
              approval: status == 'needs_approval'
                  ? {
                      'summary': 'Dr. Mehta, Cardiology',
                      'fields': [
                        {'label': 'Date', 'value': '5 Oct 2026, 10:30'},
                      ],
                    }
                  : null,
              result: status == 'done' ? 'Booked: token 14' : null,
            ),
          );
        }),
      );

      await tester.pumpWidget(
        themed(
          BookingProgressScreen(client: client, jobId: 'job-7'),
          state: state,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Check before booking'), findsOneWidget);
      expect(find.text('Dr. Mehta, Cardiology'), findsOneWidget);
      expect(find.text('5 Oct 2026, 10:30'), findsOneWidget);
      expect(find.text('Yes, book it'), findsOneWidget);
      expect(find.text('No, stop'), findsOneWidget);

      // Polling on its own never says yes.
      await tester.pump(const Duration(seconds: 5));
      expect(approvals, isEmpty);

      await tester.ensureVisible(find.text('Yes, book it'));
      await tester.tap(find.text('Yes, book it'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(approvals, [true]);
      expect(find.text('Your visit is booked'), findsOneWidget);
      expect(find.text('Booked: token 14'), findsOneWidget);
      expect(find.text('Yes, book it'), findsNothing);

      // Let the poll timer go with the screen.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed booking offers to try again', (tester) async {
      usePhoneSurface(tester);
      final state = await freshState();
      final client = HubClient(
        baseUrl: hubUrl,
        token: 'tok-1',
        client: MockClient(
          (_) async => json(jobJson('failed', error: 'No slots left')),
        ),
      );
      await tester.pumpWidget(
        themed(
          BookingProgressScreen(client: client, jobId: 'job-7'),
          state: state,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('The booking did not go through'), findsOneWidget);
      expect(find.text('No slots left'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
