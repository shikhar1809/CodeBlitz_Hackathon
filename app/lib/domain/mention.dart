import 'sig.dart';

/// Where a mention of a medicine came from.
enum SourceKind {
  /// What the doctor said, dictated or written.
  doctor,

  /// The prescription photo.
  prescription,

  /// The printed pharmacy bill.
  bill,

  /// A medicine strip or pack.
  strip,

  /// What the chemist said at the counter.
  chemist,
}

/// One source saying one thing about one medicine.
class Mention {
  const Mention({
    required this.source,
    required this.name,
    required this.raw,
    this.strength,
    this.sig = Sig.empty,
    this.purpose,
    this.uncertain = false,
    this.readOnline = false,
    this.needsCorroboration = false,
    this.packQuantity,
  });

  final SourceKind source;

  /// Upper case, English letters, as printed.
  final String name;
  final String? strength;
  final Sig sig;

  /// The exact words it came from. Shown on the card as evidence.
  final String raw;
  final String? purpose;

  /// The reader was not sure. A missing field beats a wrong one.
  final bool uncertain;

  /// Read by the online handwriting model. A better reader, not a higher
  /// authority: it lands in the same merge, against the same printed sources.
  final bool readOnline;

  /// A spoken name with nothing else — "Telma chalu rakhiye". Real evidence
  /// when another source names the same medicine; noise ("namaste") when not.
  final bool needsCorroboration;

  /// How many tablets a bill or strip line says were sold (`30 NOS`, `1x15`).
  /// Checked against the course; never turned into a dose.
  final int? packQuantity;

  Mention copyWith({
    Sig? sig,
    String? raw,
    String? purpose,
    bool? needsCorroboration,
    int? packQuantity,
  }) => Mention(
    source: source,
    name: name,
    raw: raw ?? this.raw,
    strength: strength,
    sig: sig ?? this.sig,
    purpose: purpose ?? this.purpose,
    uncertain: uncertain,
    readOnline: readOnline,
    needsCorroboration: needsCorroboration ?? this.needsCorroboration,
    packQuantity: packQuantity ?? this.packQuantity,
  );

  @override
  String toString() => 'Mention(${source.name}: $name "$raw")';
}
