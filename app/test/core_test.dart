import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/companion.dart';
import 'package:winger/core/evidence_chain.dart';
import 'package:winger/core/geo.dart';
import 'package:winger/core/journey_monitor.dart';
import 'package:winger/core/ladder.dart';
import 'package:winger/core/pin_vault.dart';
import 'package:winger/core/threat_judge.dart';

void main() {
  final t0 = DateTime(2026, 10, 3, 22);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  group('Ladder', () {
    test('climbs through every rung when nobody answers', () {
      final seen = <Rung>[];
      final l = Ladder(onClimb: (_, to) => seen.add(to));
      l.raise(at(0));
      for (var s = 1; s < 200; s++) {
        l.tick(at(s));
      }
      expect(seen, [
        Rung.nudge,
        Rung.ask,
        Rung.guardian,
        Rung.countdown112,
        Rung.called112
      ]);
    });

    test('help jumps to guardian, safe goes back to idle', () {
      final l = Ladder();
      l.help(at(0));
      expect(l.rung, Rung.guardian);
      expect(l.isAlerting, isTrue);
      l.safe(at(1));
      expect(l.rung, Rung.idle);
    });

    test('sos skips to 112 and raise never moves down', () {
      final l = Ladder()..sos(at(0));
      l.raise(at(1));
      expect(l.rung, Rung.called112);
    });

    test('remaining counts down', () {
      final l = Ladder()..raise(at(0), to: Rung.ask);
      expect(l.remaining(at(2)), 28);
    });
  });

  group('PinVault', () {
    test('tells real, duress, code and wrong apart', () {
      final v = PinVault()..setPins('2580', '1379');
      v.setCode('999');
      expect(v.check('2580'), PinResult.real);
      expect(v.check('1379'), PinResult.duress);
      expect(v.check('999'), PinResult.code);
      expect(v.check('0000'), PinResult.wrong);
    });

    test('rejects equal PINs and a code equal to duress', () {
      expect(() => PinVault().setPins('1234', '1234'), throwsArgumentError);
      final v = PinVault()..setPins('2580', '1379');
      expect(() => v.setCode('1379'), throwsArgumentError);
    });

    test('round-trips through json without storing the PIN', () {
      final v = PinVault()..setPins('2580', '1379');
      final s = jsonEncode(v.toJson());
      expect(s.contains('2580'), isFalse);
      expect(PinVault.fromJson(jsonDecode(s)).check('2580'), PinResult.real);
    });
  });

  group('EvidenceChain', () {
    test('verifies, decrypts, and detects tampering', () async {
      final c = await EvidenceChain.create();
      await c.append(ChunkKind.gps, utf8.encode('26.848,80.942'));
      await c.append(ChunkKind.audio, [1, 2, 3]);
      expect(EvidenceChain.verify(c.chunks), isTrue);
      expect(utf8.decode(await c.open(c.chunks.first)), '26.848,80.942');

      final j = c.chunks[0].toJson();
      j['t'] = DateTime(2020).toIso8601String();
      final tampered = [EvidenceChunk.fromJson(j), c.chunks[1]];
      expect(EvidenceChain.verify(tampered), isFalse);
      expect(EvidenceChain.verify([c.chunks[1]]), isFalse);
    });
  });

  group('Journey', () {
    const a = LatLon(26.8500, 80.9450), b = LatLon(26.8320, 80.9220);
    test('off route and late are flagged once', () {
      final m = JourneyMonitor(
          route: [a, b], eta: const Duration(minutes: 10), startedAt: t0);
      expect(m.update(a, at(10)), isEmpty);
      expect(m.update(const LatLon(26.87, 80.97), at(20)),
          [JourneyTrouble.offRoute]);
      expect(m.update(const LatLon(26.87, 80.97), at(25)), isEmpty);
      expect(m.update(a, at(16 * 60)), contains(JourneyTrouble.late));
    });
    test('distance to route is small on the line', () {
      expect(distanceToRoute(a, [a, b]), lessThan(1));
      expect(haversine(a, b), closeTo(3000, 400));
    });
  });

  group('ThreatJudge', () {
    test('scream asks, two screams alert, score fades', () {
      final j = ThreatJudge();
      expect(j.hearSound('Screaming', 0.9, at(0)), Verdict.ask);
      expect(j.hearSound('Screaming', 0.9, at(1)), Verdict.alert);
      expect(j.score(at(200)), lessThan(0.01));
    });
    test('unknown sounds and low confidence are ignored', () {
      final j = ThreatJudge();
      expect(j.hearSound('Music', 1, at(0)), Verdict.calm);
      expect(j.hearSound('Screaming', 0.1, at(0)), Verdict.calm);
    });
    test('safe phrase is a silent alert', () {
      expect(ThreatJudge().hearSafePhrase(), Verdict.silentAlert);
    });
  });

  group('Companion', () {
    test('says hello, answers turns, and asks after two silences', () {
      final s = CompanionScript();
      expect(s.next(at(0)), CompanionScript.hello);
      expect(s.next(at(1)), isNull);
      expect(s.next(at(3), herTurnEnded: true), CompanionScript.lines[0]);
      s.next(at(5), herTurnEnded: true, heardHer: false);
      expect(s.wantsCheckIn, isFalse);
      s.next(at(7), herTurnEnded: true, heardHer: false);
      expect(s.wantsCheckIn, isTrue);
    });
    test('loudness meter ends a turn after quiet', () {
      final m = LoudnessMeter();
      final now = DateTime(2026);
      expect(m.feed(0.5, now), isFalse);
      expect(m.feed(0.0, now.add(const Duration(milliseconds: 500))), isFalse);
      expect(m.feed(0.0, now.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
