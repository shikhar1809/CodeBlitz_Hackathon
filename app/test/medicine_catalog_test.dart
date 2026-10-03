import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/medicine_catalog.dart';

import 'support/catalog_fixture.dart';

void main() {
  final c = fixtureCatalog();

  group('lookup — exact', () {
    test('a clean name, with dosage form and strength around it', () {
      final m = c.lookup('TAB TELMA 40')!;
      expect(m.entry.name, 'TELMA');
      expect(m.kind, MatchKind.exact);
      expect(m.strength, '40');
      expect(m.proposal, 'TELMA 40');
    });
    test('case and punctuation do not matter', () {
      expect(c.lookup('Tab. Telma-40')!.entry.name, 'TELMA');
      expect(c.lookup('telma')!.exact, isTrue);
    });
    test('a variant suffix is its own product', () {
      expect(c.lookup('TELMA H 40')!.entry.name, 'TELMA H');
      expect(c.lookup('TELMA-H')!.entry.name, 'TELMA H');
      expect(c.lookup('GLYCOMET 500')!.entry.name, 'GLYCOMET');
      expect(c.lookup('GLYCOMET GP 2')!.entry.name, 'GLYCOMET GP');
    });
    test('a number stuck to the variant is the strength: GP1 is GP 1', () {
      final m = c.lookup('GLYCOMET GP1')!;
      expect(m.entry.name, 'GLYCOMET GP');
      expect(m.strength, '1');
      expect(c.lookup('GLYCOMET-GP2')!.strength, '2');
    });
    test('generics are found by salt', () {
      expect(c.lookup('Tab Telmisartan 40')!.entry.isBrand, isFalse);
      expect(c.lookup('METFORMIN SR 500')!.entry.name, 'METFORMIN SR');
    });
    test('an unknown variant is not quietly read as the plain brand', () {
      expect(c.lookup('TELMA AM 40'), isNull);
    });
  });

  group('lookup — OCR noise', () {
    test('one wrong letter still finds the brand, as a proposal', () {
      final m = c.lookup('TELNA 40')!;
      expect(m.entry.name, 'TELMA');
      expect(m.kind, MatchKind.fuzzy);
      expect(m.exact, isFalse);
      expect(m.proposal, 'TELMA 40');
      expect(m.score, greaterThanOrEqualTo(MedicineCatalog.threshold));
    });
    test('common OCR swaps', () {
      expect(c.lookup('GLYCOMFT 500')!.entry.name, 'GLYCOMET');
      expect(c.lookup('ECOSPRlN 75')!.entry.name, 'ECOSPRIN');
      expect(c.lookup('THYR0NORM 50')?.entry.name, 'THYRONORM');
      expect(c.lookup('ROSUVA5 10')?.entry.name, 'ROSUVAS');
    });
    test('noise on a variant product keeps the variant', () {
      expect(c.lookup('GLYCOMFT GP 1')!.entry.name, 'GLYCOMET GP');
    });
    test('a brand is not its generic, and not a longer brand', () {
      // TELMA and TELMISARTAN share a prefix and are different entries.
      expect(c.lookup('TELMISARTAN')!.entry.name, 'TELMISARTAN');
      expect(c.lookup('TELMA')!.entry.name, 'TELMA');
    });
    test('far from anything is unknown', () {
      expect(c.lookup('ZORBAXIL 20'), isNull);
      expect(c.lookup('NAMASTE'), isNull);
      expect(c.lookup(''), isNull);
      expect(c.lookup('40 mg'), isNull);
    });
    test('the closest of two candidates wins', () {
      expect(c.lookup('AMLOKIMD 5')!.entry.name, 'AMLOKIND');
      expect(c.lookup('AMLONQ 5')!.entry.name, 'AMLONG');
    });
  });

  group('lookup — spoken names', () {
    test('the phonetic key folds what speech gets wrong', () {
      final k = MedicineCatalog.phoneticKey;
      expect(k('glycomet'), k('glycomate'));
      expect(k('thyronorm'), k('thaironorm'));
      expect(k('ecosprin'), k('ekosprin'));
      expect(k('telma'), isNot(k('dolo')));
    });
    test('a spoken spelling finds the brand by sound', () {
      final m = c.lookup('Glycomate 500')!;
      expect(m.entry.name, 'GLYCOMET');
      expect(m.exact, isFalse);
      expect(c.lookup('Thairo norm 50')!.entry.name, 'THYRONORM');
      expect(c.lookup('Ekosprin 75')!.entry.name, 'ECOSPRIN');
    });
    test('short names never match by sound alone', () {
      expect(c.lookup('PEN 40'), isNull);
    });
  });

  group('strengths, salts', () {
    test('strengthsFor lists what is sold, smallest first', () {
      expect(c.strengthsFor('TELMA'), ['20', '40', '80']);
      expect(c.strengthsFor('telna 40'), ['20', '40', '80']);
      expect(c.strengthsFor('PARACETAMOL'), ['125', '500', '650']);
      expect(c.strengthsFor('ZORBAXIL'), isEmpty);
      expect(c.strengthsFor('TELMA H'), isEmpty);
    });
    test('sellsStrength: yes, no, or cannot say', () {
      expect(c.sellsStrength('TELMA 40'), isTrue);
      expect(c.sellsStrength('TELMA 40.0'), isTrue);
      expect(c.sellsStrength('TELMA 400'), isFalse);
      expect(c.sellsStrength('GLYCOMET GP 3'), isFalse);
      expect(c.sellsStrength('GLYCOMET GP1'), isTrue);
      expect(c.sellsStrength('TELMA'), isNull);
      expect(c.sellsStrength('TELMA H 40'), isNull);
      expect(c.sellsStrength('ZORBAXIL 10'), isNull);
      expect(c.sellsStrength('METFORMIN + GLIMEPIRIDE 500'), isNull);
    });
    test('saltOf and sameSalt', () {
      expect(c.saltOf('TELMA 40'), ['telmisartan']);
      expect(c.saltOf('ZORBAXIL'), isNull);
      expect(c.sameSalt('TELMA 40', 'TELMIKIND 40'), isTrue);
      expect(c.sameSalt('TELMA', 'Telmisartan'), isTrue);
      expect(c.sameSalt('AMLOKIND 5', 'AMLONG 5'), isTrue);
      expect(c.sameSalt('TELMA', 'TELMA H'), isFalse);
      expect(c.sameSalt('GLYCOMET', 'GLYCOMET GP'), isFalse);
      expect(c.sameSalt('ROSUVAS', 'STORVAS'), isFalse);
      expect(c.sameSalt('TELMA', 'ZORBAXIL'), isFalse);
    });
    test('sameSaltAndStrength compares what is inside', () {
      expect(c.sameSaltAndStrength('TELMA 40', 'TELMIKIND 40'), isTrue);
      expect(c.sameSaltAndStrength('TELMA 40', 'TELMIKIND 80'), isFalse);
      expect(c.sameSaltAndStrength('TELMA 40', 'TELMISARTAN 40'), isTrue);
      expect(c.sameSaltAndStrength('TELMA', 'TELMIKIND 40'), isFalse);
      expect(c.sameSaltAndStrength('AMLOKIND 5', 'AMLONG 5'), isTrue);
      expect(c.doseOf('GLYCOMET GP 2'), {'metformin': 500, 'glimepiride': 2});
    });
    test('withSalt finds every product containing a salt', () {
      expect(c.withSalt('telmisartan').map((e) => e.name), [
        'TELMA',
        'TELMA H',
        'TELMIKIND',
        'TELMISARTAN',
      ]);
    });
    test('curated entries say so', () {
      expect(c.lookup('TELMA')!.entry.isCurated, isTrue);
      expect(c.lookup('TELMISARTAN')!.entry.isCurated, isFalse);
      expect(c.lookup('THYRONORM')!.entry.unit, 'mcg');
    });
  });

  group('look-alikes', () {
    test('either side of a pair finds the pair', () {
      expect(c.lookAlikeOf('ROSUVAS')!.b, 'STORVAS');
      expect(c.lookAlikeOf('storvas')!.a, 'ROSUVAS');
      expect(c.lookAlikeOf('TELMA'), isNull);
    });
  });

  group('scale', () {
    test('ten thousand entries: built and searched quickly', () {
      const letters = 'abcdefghijklmnopqrstuvwxyz';
      String brand(int i) {
        final b = StringBuffer();
        var n = i * 7919 + 13;
        for (var k = 0; k < 7; k++) {
          b.write(letters[n % 26]);
          n = n ~/ 26 + k * 31;
        }
        return b.toString().toUpperCase();
      }

      final entries = [
        for (var i = 0; i < 10000; i++)
          CatalogEntry(
            name: brand(i),
            salts: ['salt$i'],
            forms: const {
              'tablet': [CatalogStrength('10', {})],
            },
            isBrand: true,
            source: 'curated',
          ),
        ...c.entries,
      ];
      final sw = Stopwatch()..start();
      final big = MedicineCatalog(entries);
      final built = sw.elapsedMilliseconds;
      sw.reset();
      for (var i = 0; i < 200; i++) {
        big.lookup('TELNA 40');
        big.lookup('GLYCOMFT 500');
        big.lookup('ZORBAXIL');
      }
      final perLookup = sw.elapsedMicroseconds / 600;
      expect(big.lookup('TELNA 40')!.entry.name, 'TELMA');
      expect(big.length, 10000 + c.length);
      expect(built, lessThan(2000));
      expect(perLookup, lessThan(5000), reason: '$perLookup µs per lookup');
    });
  });
}
