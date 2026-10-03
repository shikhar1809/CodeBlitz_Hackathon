import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/medicine_catalog.dart';
import 'package:winger/features/medicines/catalog_loader.dart';

/// The generated asset itself: shape, size, and the curated facts the app
/// leans on. If a rebuild breaks one of these, the build script is wrong.
void main() {
  final medicines = File('assets/catalog/medicines.json');
  final lookAlikes = File('assets/catalog/lookalikes.json');
  final c = MedicineCatalog.fromJson(
    medicines.readAsStringSync(),
    lookAlikes: lookAlikes.readAsStringSync(),
  );

  test('small enough to bundle, large enough to matter', () {
    expect(medicines.lengthSync(), lessThan(5 * 1024 * 1024));
    expect(c.length, greaterThan(1000));
    final root = jsonDecode(medicines.readAsStringSync()) as Map;
    final counts = root['counts'] as Map;
    expect(counts['brands'] + counts['generics'], c.length);
  });

  test('every entry has salts, and no two share a lookup key', () {
    final keys = <String>{};
    for (final e in c.entries) {
      expect(e.salts, isNotEmpty, reason: e.name);
      expect(e.forms, isNotEmpty, reason: e.name);
      final k = CatalogKey(e.brandKey, e.variants, null).key;
      expect(keys.add(k), isTrue, reason: 'duplicate key for ${e.name}');
    }
  });

  test('brands come only from the curated seed, and say so', () {
    final brands = c.entries.where((e) => e.isBrand).toList();
    expect(brands, isNotEmpty);
    expect(brands.every((e) => e.isCurated), isTrue);
    expect(
      c.entries.where((e) => !e.isBrand).every((e) => !e.isCurated),
      isTrue,
    );
  });

  test('the chronic-care seed', () {
    expect(c.strengthsFor('TELMA'), ['20', '40', '80']);
    expect(c.saltOf('GLYCOMET'), ['metformin']);
    expect(c.saltOf('GLYCOMET GP 1'), ['metformin', 'glimepiride']);
    expect(c.saltOf('ECOSPRIN 75'), ['aspirin']);
    expect(c.saltOf('THYRONORM 50'), ['levothyroxine']);
    expect(c.lookup('THYRONORM')!.entry.unit, 'mcg');
    expect(c.saltOf('AMLOKIND 5'), ['amlodipine']);
    expect(c.saltOf('AMLONG 5'), ['amlodipine']);
    expect(c.saltOf('ROSUVAS 10'), ['rosuvastatin']);
    expect(c.saltOf('PAN 40'), ['pantoprazole']);
    expect(c.saltOf('DOLO 650'), ['paracetamol']);
  });

  test('brands meet their generics by salt', () {
    expect(c.sameSalt('TELMA 40', 'TELMISARTAN 40'), isTrue);
    expect(c.sameSaltAndStrength('TELMA 40', 'TELMISARTAN 40'), isTrue);
    expect(c.sameSaltAndStrength('ECOSPRIN 75', 'ASPIRIN 75'), isTrue);
    expect(c.sameSaltAndStrength('AMLOKIND 5', 'AMLODIPINE 5'), isTrue);
    expect(c.sameSalt('PAN 40', 'PANTOPRAZOLE'), isTrue);
    for (final b in c.entries.where((e) => e.isBrand)) {
      if (b.salts.length != 1) continue;
      expect(
        c.withSalt(b.salts.single).any((e) => !e.isBrand),
        isTrue,
        reason: '${b.name}: ${b.salts.single} is in no government list',
      );
    }
  });

  test('government strengths for common generics', () {
    expect(c.sellsStrength('TELMISARTAN 40'), isTrue);
    expect(c.sellsStrength('METFORMIN 500'), isTrue);
    expect(c.sellsStrength('METFORMIN SR 500'), isTrue);
    expect(c.sellsStrength('AMLODIPINE 5'), isTrue);
    expect(c.sellsStrength('AMLODIPINE 7'), isFalse);
  });

  test('OCR noise and spoken names on the real list', () {
    expect(c.lookup('TELNA 40')!.proposal, 'TELMA 40');
    expect(c.lookup('GLYCOMFT 500')!.entry.name, 'GLYCOMET');
    expect(c.lookup('Glycomate 500')!.entry.name, 'GLYCOMET');
    expect(c.lookup('ECOSPRlN 75')!.entry.name, 'ECOSPRIN');
    expect(c.lookup('Telmisartn 40')!.entry.name, 'TELMISARTAN');
  });

  test('every look-alike pair is two catalogue brands with different salts', () {
    expect(c.lookAlikes, isNotEmpty);
    for (final p in c.lookAlikes) {
      final a = c.lookup(p.a), b = c.lookup(p.b);
      expect(a?.exact, isTrue, reason: p.a);
      expect(b?.exact, isTrue, reason: p.b);
      expect(c.sameSalt(p.a, p.b), isFalse, reason: '${p.a}/${p.b}');
      expect(p.why, isNotEmpty);
    }
  });

  testWidgets('CatalogLoader reads both assets from the bundle', (t) async {
    final loaded = await t.runAsync(CatalogLoader.load);
    expect(loaded, isNotNull);
    expect(loaded!.length, c.length);
    expect(loaded.lookAlikes.length, c.lookAlikes.length);
  });
}
