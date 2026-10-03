import 'dart:math' as math;

import 'sig_parser.dart';

/// Decides whether two sources are talking about the same medicine.
///
/// Jaro-Winkler on the brand letters, at 0.86 or better, so OCR noise
/// (TELNA for TELMA) still lines up. Two rules stop it being too generous:
/// a variant suffix must match exactly — GLYCOMET is not GLYCOMET GP — and a
/// strength only counts against a match when both sides have one, because a
/// doctor saying "Telma" has not contradicted a bill saying "TELMA 40".
abstract final class NameMatcher {
  static const threshold = 0.86;

  static bool same(String a, String b) => similarity(a, b) >= threshold;

  static double similarity(String a, String b) {
    final x = parse(a), y = parse(b);
    if (x.brand.isEmpty || y.brand.isEmpty) return 0;
    if (!_sameSet(x.variants, y.variants)) return 0;
    // A shared prefix is not a shared medicine. Jaro-Winkler scores TELMA
    // against TELMISARTAN at 0.89, which would fold a counter substitution
    // into one quiet row — the exact thing the chemist step exists to catch.
    final shorter = math.min(x.brand.length, y.brand.length);
    final longer = math.max(x.brand.length, y.brand.length);
    if (shorter / longer < .75) return 0;
    return jaroWinkler(x.brand, y.brand);
  }

  /// Brand letters, strength digits, and variant suffixes.
  static ({String brand, String? strength, Set<String> variants}) parse(
    String name,
  ) {
    final tokens = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9. ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final brand = StringBuffer();
    String? strength;
    final variants = <String>{};
    for (final t in tokens) {
      if (RegExp(r'^\d').hasMatch(t)) {
        strength ??= t.replaceAll(RegExp(r'[a-z]+$'), '');
      } else if (SigParser.variants.contains(t) && brand.isNotEmpty) {
        variants.add(t);
      } else if (!SigParser.forms.contains(t)) {
        brand.write(t);
      }
    }
    return (brand: brand.toString(), strength: strength, variants: variants);
  }

  /// Both have a strength and they differ.
  static bool strengthsDiffer(String a, String b) {
    final x = parse(a).strength, y = parse(b).strength;
    return x != null && y != null && double.tryParse(x) != double.tryParse(y);
  }

  static double jaroWinkler(String s, String t) {
    if (s == t) return 1;
    final range = math.max(0, math.max(s.length, t.length) ~/ 2 - 1);
    final sMatch = List.filled(s.length, false);
    final tMatch = List.filled(t.length, false);
    var matches = 0;
    for (var i = 0; i < s.length; i++) {
      final lo = math.max(0, i - range);
      final hi = math.min(i + range + 1, t.length);
      for (var j = lo; j < hi; j++) {
        if (tMatch[j] || s[i] != t[j]) continue;
        sMatch[i] = tMatch[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0;
    var k = 0, transpositions = 0;
    for (var i = 0; i < s.length; i++) {
      if (!sMatch[i]) continue;
      while (!tMatch[k]) {
        k++;
      }
      if (s[i] != t[k]) transpositions++;
      k++;
    }
    final m = matches.toDouble();
    final jaro =
        (m / s.length + m / t.length + (m - transpositions / 2) / m) / 3;
    var prefix = 0;
    while (prefix < math.min(4, math.min(s.length, t.length)) &&
        s[prefix] == t[prefix]) {
      prefix++;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
