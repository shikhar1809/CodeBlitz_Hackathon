import 'dart:async';

/// An Ayushman Bharat (PM-JAY) beneficiary card, as a lookup returned it.
class AyushmanCard {
  const AyushmanCard({
    required this.name,
    required this.pmjayId,
    required this.familyId,
    required this.state,
    required this.cover,
    required this.validTill,
    this.demo = true,
  });

  final String name;
  final String pmjayId;
  final String familyId;
  final String state;

  /// "₹5 lakh" — the family's annual cover.
  final String cover;
  final String validTill;

  /// Returned by the mock. The screen says "Demo data" while this is true.
  final bool demo;

  Map<String, Object?> toJson() => {
    'name': name,
    'pmjayId': pmjayId,
    'familyId': familyId,
    'state': state,
    'cover': cover,
    'validTill': validTill,
    'demo': demo,
  };

  factory AyushmanCard.fromJson(Map<String, Object?> j) => AyushmanCard(
    name: j['name']! as String,
    pmjayId: j['pmjayId']! as String,
    familyId: j['familyId']! as String,
    state: j['state']! as String,
    cover: j['cover']! as String,
    validTill: j['validTill']! as String,
    demo: j['demo'] as bool? ?? true,
  );
}

sealed class PmjayResult {
  const PmjayResult();
}

class PmjayFound extends PmjayResult {
  const PmjayFound(this.card);
  final AyushmanCard card;
}

class PmjayNotFound extends PmjayResult {
  const PmjayNotFound();
}

class PmjayBadFormat extends PmjayResult {
  const PmjayBadFormat();
}

/// Looks up an Ayushman Bharat card.
///
/// There is no PM-JAY integration in this build, and there must not be one
/// without the proper agreements. [MockPmjayClient] stands in behind this
/// interface so a real client can drop in later without touching a screen.
abstract class PmjayClient {
  /// Upper case, spaces and dashes removed.
  static String clean(String id) =>
      id.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// The format the mock accepts: nine letters and digits, at least one
  /// letter — the shape of a PM-JAY beneficiary ID on the printed card.
  static bool validFormat(String id) {
    final c = clean(id);
    return RegExp(r'^[A-Z0-9]{9}$').hasMatch(c) && RegExp('[A-Z]').hasMatch(c);
  }

  Future<PmjayResult> fetch(String id);
}

/// Deterministic demo data: the same ID always returns the same card, so
/// tests and screenshots never change under us.
class MockPmjayClient implements PmjayClient {
  MockPmjayClient({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;

  /// The one ID that is well-formed but has no card behind it.
  static const notFoundId = 'PMJ000000';

  /// A known-good ID for demos.
  static const demoId = 'PMJ4K7Q2X';

  static const _names = [
    'Ramesh Kumar',
    'Sunita Devi',
    'Mohammad Irfan',
    'Kamla Yadav',
    'Suresh Verma',
    'Geeta Mishra',
  ];
  static const _states = [
    'Uttar Pradesh',
    'Bihar',
    'Madhya Pradesh',
    'Rajasthan',
  ];

  @override
  Future<PmjayResult> fetch(String id) async {
    await Future<void>.delayed(delay);
    if (!PmjayClient.validFormat(id)) return const PmjayBadFormat();
    final c = PmjayClient.clean(id);
    if (c == notFoundId) return const PmjayNotFound();

    final h = c.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    return PmjayFound(
      AyushmanCard(
        name: _names[h % _names.length],
        pmjayId: c,
        familyId: 'F${(h % 900000000 + 100000000)}',
        state: _states[(h ~/ 7) % _states.length],
        cover: '₹5 lakh',
        validTill: '31/03/2027',
      ),
    );
  }
}
