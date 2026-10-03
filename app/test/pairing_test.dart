import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/app_state.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/app_strings.dart';
import 'package:winger/core/l10n/strings_caretaker.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/features/pairing/caretaker_confirm_screen.dart';
import 'package:winger/features/pairing/caretaker_pairing.dart';
import 'package:winger/features/pairing/caretaker_qr_screen.dart';
import 'package:winger/features/pairing/caretaker_type_screen.dart';
import 'package:winger/features/pairing/pairing_channel.dart';
import 'package:winger/features/pairing/pairing_code.dart';
import 'package:winger/features/pairing/patient_pairing.dart';
import 'package:winger/features/pairing/patient_scan_screen.dart';
import 'package:winger/platform/qr_scanner_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_haptics.dart';

import 'support/golden_harness.dart';

final issued = DateTime(2026, 9, 26, 10, 0);

PairingPayload payload({
  String name = 'Sunita',
  CaretakerType type = CaretakerType.family,
  DateTime? at,
}) => PairingPayload(
  caretakerId: 'K7Q2XMPA3B',
  phone: '9812345678',
  name: name,
  type: type,
  issuedAt: PairingCode.epochSeconds(at ?? issued),
);

/// A code whose JSON is [json], with a correct checksum: what a newer app,
/// or a careful forger, would produce.
String rawCode(Map<String, Object?> json, {String prefix = 'RXC1'}) {
  final text = jsonEncode(json);
  final body = base64Url.encode(utf8.encode(text)).replaceAll('=', '');
  final sum = sha256.convert(utf8.encode(text)).toString().substring(0, 8);
  return '$prefix.$body.$sum';
}

void main() {
  group('PairingCode', () {
    final now = issued.add(const Duration(minutes: 3));

    test('encode → decode round-trips every field', () {
      final code = PairingCode.encode(payload());
      expect(code, startsWith('RXC1.'));
      final d = PairingCode.decode(code, now: now);
      expect(d.ok, isTrue);
      final p = d.payload!;
      expect(p.caretakerId, 'K7Q2XMPA3B');
      expect(p.phone, '9812345678');
      expect(p.name, 'Sunita');
      expect(p.type, CaretakerType.family);
      expect(p.issuedAt, PairingCode.epochSeconds(issued));
    });

    test('a Hindi name and a commercial type survive the trip', () {
      final code = PairingCode.encode(
        payload(name: 'सुनीता', type: CaretakerType.commercial),
      );
      final p = PairingCode.decode(code, now: now).payload!;
      expect(p.name, 'सुनीता');
      expect(p.type, CaretakerType.commercial);
    });

    test('the payload is versioned JSON with the agreed fields', () {
      final body = PairingCode.encode(payload()).split('.')[1];
      final j = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(body))),
      );
      expect(j, {
        'v': 1,
        'caretakerId': 'K7Q2XMPA3B',
        'phone': '9812345678',
        'name': 'Sunita',
        'type': 'family',
        'issuedAt': PairingCode.epochSeconds(issued),
      });
    });

    test('the checksum is the first 8 hex of SHA-256 over the JSON', () {
      final p = payload();
      final sum = sha256
          .convert(utf8.encode(p.canonicalJson()))
          .toString()
          .substring(0, 8);
      expect(PairingCode.encode(p).split('.').last, sum);
    });

    test('spaces and line breaks from typing or pasting are ignored', () {
      final code = PairingCode.encode(payload());
      final typed = ' ${code.substring(0, 20)}\n${code.substring(20)}  ';
      expect(PairingCode.decode(typed, now: now).ok, isTrue);
    });

    test('fifteen minutes, then expired', () {
      final code = PairingCode.encode(payload());
      expect(
        PairingCode.decode(
          code,
          now: issued.add(const Duration(minutes: 14, seconds: 59)),
        ).ok,
        isTrue,
      );
      expect(
        PairingCode.decode(
          code,
          now: issued.add(const Duration(minutes: 15, seconds: 1)),
        ).error,
        PairingError.expired,
      );
    });

    test('a code from the future means a phone has the wrong time', () {
      final code = PairingCode.encode(payload());
      expect(
        PairingCode.decode(
          code,
          now: issued.subtract(const Duration(minutes: 10)),
        ).error,
        PairingError.clockWrong,
      );
      // A little skew is normal.
      expect(
        PairingCode.decode(
          code,
          now: issued.subtract(const Duration(minutes: 2)),
        ).ok,
        isTrue,
      );
    });

    test('a tampered payload fails the checksum', () {
      final code = PairingCode.encode(payload());
      final parts = code.split('.');
      // Swap the phone number, keep the old checksum.
      final forged = payload().canonicalJson().replaceAll(
        '9812345678',
        '9000000000',
      );
      final body = base64Url.encode(utf8.encode(forged)).replaceAll('=', '');
      expect(
        PairingCode.decode('${parts[0]}.$body.${parts[2]}', now: now).error,
        PairingError.checksum,
      );
    });

    test('one changed character anywhere is refused', () {
      final code = PairingCode.encode(payload());
      for (final i in [10, 40, code.length - 3]) {
        final c = code[i] == 'A' ? 'B' : 'A';
        final typo = code.replaceRange(i, i + 1, c);
        final d = PairingCode.decode(typo, now: now);
        expect(d.ok, isFalse, reason: 'at $i');
      }
    });

    test('a changed checksum is refused', () {
      final code = PairingCode.encode(payload());
      final bad = '${code.substring(0, code.length - 8)}00000000';
      expect(PairingCode.decode(bad, now: now).error, PairingError.checksum);
    });

    test('a newer version is named, not mistaken for a typo', () {
      final v2 = rawCode({
        'v': 2,
        'caretakerId': 'K7Q2XMPA3B',
        'phone': '9812345678',
        'name': 'Sunita',
        'type': 'family',
        'issuedAt': PairingCode.epochSeconds(issued),
      }, prefix: 'RXC2');
      expect(
        PairingCode.decode(v2, now: now).error,
        PairingError.unsupportedVersion,
      );
    });

    test('not a RapidRX code at all', () {
      for (final junk in ['', 'hello', 'https://example.com', 'RXC1..x']) {
        expect(
          PairingCode.decode(junk, now: now).error,
          PairingError.malformed,
          reason: junk,
        );
      }
    });

    test('a well-formed code with a bad phone or a missing name', () {
      final base = {
        'v': 1,
        'caretakerId': 'K7Q2XMPA3B',
        'phone': '9812345678',
        'name': 'Sunita',
        'type': 'family',
        'issuedAt': PairingCode.epochSeconds(issued),
      };
      for (final broken in [
        {...base, 'phone': '12345'},
        {...base, 'name': ' '},
        {...base, 'type': 'robot'},
        {...base}..remove('caretakerId'),
      ]) {
        expect(
          PairingCode.decode(rawCode(broken), now: now).error,
          PairingError.malformed,
        );
      }
    });

    test('both phones derive the same 4-digit confirmation code', () {
      final a = PairingCode.confirmationCode('K7Q2XMPA3B');
      expect(a, matches(RegExp(r'^\d{4}$')));
      expect(PairingCode.confirmationCode('K7Q2XMPA3B'), a);
      expect(PairingCode.confirmationCode('K7Q2XMPA3C'), isNot(a));
    });

    test('caretaker ids: ten characters, nothing easily misread', () {
      final id = PairingCode.newCaretakerId(Random(1));
      expect(id, hasLength(10));
      expect(id, isNot(matches(RegExp('[01OI]'))));
    });
  });

  group('CaretakerPairing', () {
    late AppPrefs prefs;
    var clock = issued;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'phone_number': '9812345678',
        'user_name': 'Sunita',
        'caretaker_type': 'commercial',
      });
      prefs = await AppPrefs.load();
      clock = issued;
    });

    CaretakerPairing pairing() =>
        CaretakerPairing(prefs: prefs, clock: () => clock, random: Random(7));

    test('the code carries this phone\'s own number, name and type', () {
      final p = pairing().code();
      expect(p.phone, '9812345678');
      expect(p.name, 'Sunita');
      expect(p.type, CaretakerType.commercial);
    });

    test('the caretaker id is made once and kept', () {
      final first = pairing().code().caretakerId;
      expect(pairing().code().caretakerId, first);
      expect(prefs.caretakerId, first);
    });

    test('expiry, minutes left, and a new code', () async {
      final p = pairing();
      p.code();
      expect(p.minutesLeft, 15);
      clock = issued.add(const Duration(minutes: 10, seconds: 30));
      expect(p.minutesLeft, 5);
      expect(p.expired, isFalse);
      clock = issued.add(const Duration(minutes: 15));
      expect(p.expired, isTrue);
      expect(p.minutesLeft, 0);

      final id = p.code().caretakerId;
      await p.makeNewCode();
      expect(p.expired, isFalse);
      expect(p.code().caretakerId, id, reason: 'same caretaker');
      expect(
        PairingCode.decode(p.encoded(), now: clock).ok,
        isTrue,
        reason: 'the new code scans',
      );
    });

    test('the right code links and is kept; the wrong one does not', () async {
      final p = pairing();
      final id = p.code().caretakerId;
      expect(
        await p.confirm(patientName: 'Ramesh', code: '12'),
        ConfirmError.codeShort,
      );
      expect(
        await p.confirm(patientName: ' ', code: '1234'),
        ConfirmError.nameMissing,
      );
      final right = PairingCode.confirmationCode(id);
      final wrong = right == '0000' ? '1111' : '0000';
      expect(
        await p.confirm(patientName: 'Ramesh', code: wrong),
        ConfirmError.wrongCode,
      );
      expect(p.linked, isNull);

      expect(await p.confirm(patientName: 'Ramesh', code: right), isNull);
      expect(p.linked!.name, 'Ramesh');
      expect(p.linked!.caretakerId, id);
    });

    test('the patient phone and the caretaker phone agree offline', () async {
      final p = pairing();
      final scanned = PairingCode.decode(p.encoded(), now: clock).payload!;
      const channel = LocalPairingChannel();
      final shown = await channel.patientLinked(scanned, patientName: 'Ramesh');
      expect(await p.confirm(patientName: 'Ramesh', code: shown), isNull);
    });

    test('"later" is remembered; linking clears it', () async {
      final p = pairing();
      await p.later();
      expect(prefs.caretakerPairLater, isTrue);
      await p.confirm(
        patientName: 'Ramesh',
        code: PairingCode.confirmationCode(p.code().caretakerId),
      );
      expect(prefs.caretakerPairLater, isFalse);
    });

    test('forgetting who this is forgets the pairing too', () async {
      final p = pairing();
      await p.confirm(
        patientName: 'Ramesh',
        code: PairingCode.confirmationCode(p.code().caretakerId),
      );
      await prefs.clearIdentity();
      expect(prefs.caretakerType, isNull);
      expect(prefs.caretakerId, isNull);
      expect(prefs.linkedPatientJson, isNull);
    });
  });

  group('PatientPairing', () {
    late AppPrefs patientPrefs;
    final now = issued.add(const Duration(minutes: 3));

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'Ramesh',
        'phone_number': '9876543210',
        'app_role': 'patient',
      });
      patientPrefs = await AppPrefs.load();
    });

    PatientPairing scan() =>
        PatientPairing(prefs: patientPrefs, clock: () => now);

    test(
      'a family code is linked at once, and alerts go to their number',
      () async {
        final p = scan();
        expect(p.submit(PairingCode.encode(payload())), isTrue);
        expect(p.step, ScanStep.found);
        await p.accept();
        expect(p.step, ScanStep.done);
        expect(p.confirmationCode, PairingCode.confirmationCode('K7Q2XMPA3B'));
        expect(patientPrefs.alertPhone, '9812345678');
        final linked = LinkedCaretaker.of(patientPrefs)!;
        expect(linked.name, 'Sunita');
        expect(linked.type, CaretakerType.family);
        expect(linked.pinHash, isNull);
      },
    );

    test('a commercial caretaker needs a PIN before they are linked', () async {
      final p = scan();
      p.submit(PairingCode.encode(payload(type: CaretakerType.commercial)));
      await p.accept();
      expect(p.step, ScanStep.setPin);
      expect(patientPrefs.linkedCaretakerJson, isNull);
      expect(await p.setPin('12', '12'), isFalse);
      expect(p.pinProblem, PinProblem.short);
      expect(await p.setPin('1234', '4321'), isFalse);
      expect(p.pinProblem, PinProblem.mismatch);
      expect(await p.setPin('1234', '1234'), isTrue);
      expect(p.step, ScanStep.done);
      final linked = LinkedCaretaker.of(patientPrefs)!;
      expect(linked.type, CaretakerType.commercial);
      expect(linked.checkPin('1234'), isTrue);
      expect(linked.checkPin('0000'), isFalse);
    });

    test('a bad or expired code is refused, and nothing is saved', () {
      final p = scan();
      expect(p.submit('not-a-code'), isFalse);
      expect(p.error, PairingError.malformed);
      expect(
        p.submit(
          PairingCode.encode(
            payload(at: issued.subtract(const Duration(minutes: 20))),
          ),
        ),
        isFalse,
      );
      expect(p.error, PairingError.expired);
      expect(patientPrefs.linkedCaretakerJson, isNull);
    });

    test(
      'unlinking forgets them, and alerts stop going to their number',
      () async {
        final p = scan();
        p.submit(PairingCode.encode(payload()));
        await p.accept();
        await unlinkCaretaker(patientPrefs);
        expect(LinkedCaretaker.of(patientPrefs), isNull);
        expect(patientPrefs.alertPhone, isNull);
      },
    );

    test('each refusal has its own words', () {
      final s = AppStrings(AppLanguage.en);
      expect(pairingErrorMessage(PairingError.malformed, s), s.codeMalformed);
      expect(pairingErrorMessage(PairingError.expired, s), s.codeExpired);
      expect(pairingErrorMessage(PairingError.checksum, s), s.codeChecksum);
    });
  });

  group('screens', () {
    Future<(AppState, CaretakerPairing)> setup(
      AppLanguage language, {
      DateTime? now,
    }) async {
      final state = await freshState(
        language: language,
        values: {
          'phone_number': '9812345678',
          'user_name': 'Sunita',
          'app_role': 'caregiver',
          'caretaker_type': 'family',
          'caretaker_id': 'K7Q2XMPA3B',
          'caretaker_code_issued_at': PairingCode.epochSeconds(issued),
        },
      );
      return (
        state,
        CaretakerPairing(prefs: state.prefs, clock: () => now ?? issued),
      );
    }

    Future<void> shoot(
      WidgetTester tester,
      Widget screen,
      String name, {
      AppLanguage language = AppLanguage.en,
      AppState? state,
    }) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(themed(screen, language: language, state: state));
      await precacheLogo(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
      await tester.pumpWidget(const SizedBox());
    }

    for (final l in AppLanguage.values) {
      testWidgets('type ${l.code}', (t) async {
        await shoot(
          t,
          CaretakerTypeScreen(onChosen: (_) {}),
          'caretaker_1_type_${l.code}',
          language: l,
        );
      });

      testWidgets('qr ${l.code}', (t) async {
        final (state, p) = await setup(
          l,
          now: issued.add(const Duration(minutes: 2)),
        );
        await shoot(
          t,
          CaretakerQrScreen(pairing: p, onEnterCode: () {}, onLater: () {}),
          'pairing_1_qr_${l.code}',
          language: l,
          state: state,
        );
      });

      testWidgets('confirm ${l.code}', (t) async {
        final (state, p) = await setup(l);
        await shoot(
          t,
          CaretakerConfirmScreen(pairing: p, onLinked: () {}),
          'pairing_3_confirm_${l.code}',
          language: l,
          state: state,
        );
      });
    }

    testWidgets('an expired code says so and offers a new one', (t) async {
      final (state, p) = await setup(
        AppLanguage.en,
        now: issued.add(const Duration(minutes: 20)),
      );
      await shoot(
        t,
        CaretakerQrScreen(pairing: p, onEnterCode: () {}, onLater: () {}),
        'pairing_2_qr_expired_en',
        state: state,
      );
    });

    testWidgets('"Make a new code" brings the code back to life', (t) async {
      usePhoneSurface(t);
      final now = issued.add(const Duration(minutes: 20));
      final state = (await setup(AppLanguage.en)).$1;
      final p = CaretakerPairing(prefs: state.prefs, clock: () => now);
      await t.pumpWidget(
        themed(
          CaretakerQrScreen(pairing: p, onEnterCode: () {}, onLater: () {}),
          state: state,
        ),
      );
      expect(find.text('This code has expired. Make a new one.'), findsOne);
      await t.ensureVisible(find.text('Make a new code'));
      await t.tap(find.text('Make a new code'));
      await t.pump();
      expect(find.text('This code has expired. Make a new one.'), findsNothing);
      expect(find.text('Works for 15 more minutes'), findsOne);
      await t.pumpWidget(const SizedBox());
    });

    for (final l in AppLanguage.values) {
      testWidgets('the right code: "connection successful" ${l.code}', (
        t,
      ) async {
        usePhoneSurface(t);
        final (state, p) = await setup(l);
        var linked = false;
        await t.pumpWidget(
          themed(
            CaretakerConfirmScreen(pairing: p, onLinked: () => linked = true),
            language: l,
            state: state,
          ),
        );
        await precacheLogo(t);
        await t.enterText(find.byType(TextField).at(0), 'Ramesh');
        await t.enterText(
          find.byType(TextField).at(1),
          PairingCode.confirmationCode('K7Q2XMPA3B'),
        );
        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pairing_4_linked_${l.code}.png'),
        );
        expect(linked, isFalse, reason: 'not until the popup is closed');
        await t.tap(find.byType(FilledButton).last);
        await t.pumpAndSettle();
        expect(linked, isTrue);
        expect(p.linked!.name, 'Ramesh');
      });
    }

    testWidgets('the wrong code is an error, and nothing is linked', (t) async {
      usePhoneSurface(t);
      final (state, p) = await setup(AppLanguage.en);
      await t.pumpWidget(
        themed(
          CaretakerConfirmScreen(pairing: p, onLinked: () {}),
          state: state,
        ),
      );
      final right = PairingCode.confirmationCode('K7Q2XMPA3B');
      await t.enterText(find.byType(TextField).at(0), 'Ramesh');
      await t.enterText(
        find.byType(TextField).at(1),
        right == '0000' ? '1111' : '0000',
      );
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(
        find.text('That code does not match. Check the patient\'s phone.'),
        findsOne,
      );
      expect(p.linked, isNull);
    });

    Future<(AppState, PatientPairing)> patientSetup(
      AppLanguage language,
    ) async {
      final state = await freshState(
        language: language,
        values: {
          'phone_number': '9876543210',
          'user_name': 'Ramesh',
          'app_role': 'patient',
        },
      );
      return (
        state,
        PatientPairing(
          prefs: state.prefs,
          clock: () => issued.add(const Duration(minutes: 3)),
        ),
      );
    }

    Widget scanScreen(PatientPairing p) =>
        PatientScanScreen(pairing: p, scanner: UnsupportedQrScanner());

    for (final l in AppLanguage.values) {
      testWidgets('patient scan ${l.code}', (t) async {
        FakeHaptics.install();
        final (state, p) = await patientSetup(l);
        await shoot(
          t,
          scanScreen(p),
          'pairing_5_patient_scan_${l.code}',
          language: l,
          state: state,
        );
      });

      testWidgets('patient found ${l.code}', (t) async {
        FakeHaptics.install();
        final (state, p) = await patientSetup(l);
        p.submit(PairingCode.encode(payload()));
        await shoot(
          t,
          scanScreen(p),
          'pairing_6_patient_found_${l.code}',
          language: l,
          state: state,
        );
      });

      testWidgets('patient linked ${l.code}', (t) async {
        FakeHaptics.install();
        final (state, p) = await patientSetup(l);
        p.submit(PairingCode.encode(payload()));
        await p.accept();
        await shoot(
          t,
          scanScreen(p),
          'pairing_7_patient_linked_${l.code}',
          language: l,
          state: state,
        );
      });
    }

    testWidgets(
      'typing a family code links them and shows the confirm digits',
      (t) async {
        FakeHaptics.install();
        usePhoneSurface(t);
        final (state, p) = await patientSetup(AppLanguage.en);
        await t.pumpWidget(themed(scanScreen(p), state: state));
        expect(
          find.text(
            'This device cannot scan. Type or paste the code the caretaker sent you.',
          ),
          findsOne,
        );
        await t.enterText(
          find.byType(TextField),
          PairingCode.encode(payload()),
        );
        await t.tap(find.text('Check code'));
        await t.pump();
        expect(find.text('Sunita — Family member'), findsOne);
        await t.tap(find.text('Link Sunita'));
        await t.pumpAndSettle();
        expect(find.text('Caretaker connection successful'), findsOne);
        expect(p.confirmationCode, PairingCode.confirmationCode('K7Q2XMPA3B'));
      },
    );
  });
}
