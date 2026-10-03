import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/storage/app_prefs.dart' show CaretakerType;

/// What a caretaker's QR code carries: who they are, how to reach them, and
/// when the code was made.
class PairingPayload {
  const PairingPayload({
    required this.caretakerId,
    required this.phone,
    required this.name,
    required this.type,
    required this.issuedAt,
  });

  static const version = 1;

  /// Random, made once per caretaker. It is also what both phones derive the
  /// 4-digit confirmation code from, so they agree without a network.
  final String caretakerId;

  /// The caretaker's own OTP-verified number, ten digits. Alerts go here.
  final String phone;
  final String name;
  final CaretakerType type;

  /// Epoch seconds.
  final int issuedAt;

  DateTime get issuedTime =>
      DateTime.fromMillisecondsSinceEpoch(issuedAt * 1000);

  /// Fixed key order, no whitespace: the exact bytes the checksum covers.
  String canonicalJson() => jsonEncode({
    'v': version,
    'caretakerId': caretakerId,
    'phone': phone,
    'name': name,
    'type': type.name,
    'issuedAt': issuedAt,
  });
}

/// Why a code was refused. Each has its own plain message on the screen.
enum PairingError {
  /// Not a RapidRX code at all, or a piece is missing.
  malformed,

  /// Made by a newer (or older) app than this one understands.
  unsupportedVersion,

  /// A character changed on the way: mistyped, or altered.
  checksum,

  /// Older than [PairingCode.validFor]. The caretaker makes a new one.
  expired,

  /// Issued in the future: one of the two phones has the wrong time.
  clockWrong,
}

class PairingDecode {
  const PairingDecode.ok(PairingPayload this.payload) : error = null;
  const PairingDecode.error(PairingError this.error) : payload = null;

  final PairingPayload? payload;
  final PairingError? error;

  bool get ok => payload != null;
}

/// Encode, decode and check a caretaker pairing code. Pure: no widgets, no
/// storage, the clock passed in.
///
/// The text form is `RXC1.<base64url of the canonical JSON>.<checksum>`, where
/// the checksum is the first 8 hex characters of SHA-256 over that JSON. The
/// same text is the QR content and the code a patient can type or paste.
///
/// The checksum catches a typo or a corrupted scan. It is not a signature —
/// anyone can compute SHA-256 — so it does not stop a forged code. With a
/// backend, the server would sign codes (ADR-45).
abstract final class PairingCode {
  static const prefix = 'RXC';
  static const validFor = Duration(minutes: 15);

  /// How far in the future a code may claim to be from, before the phones'
  /// clocks are called out as wrong.
  static const clockSkew = Duration(minutes: 5);

  static String checksum(String canonicalJson) =>
      sha256.convert(utf8.encode(canonicalJson)).toString().substring(0, 8);

  static String encode(PairingPayload p) {
    final json = p.canonicalJson();
    final body = base64Url.encode(utf8.encode(json)).replaceAll('=', '');
    return '$prefix${PairingPayload.version}.$body.${checksum(json)}';
  }

  static PairingDecode decode(String raw, {required DateTime now}) {
    // A typed or pasted code may carry spaces and line breaks.
    final text = raw.replaceAll(RegExp(r'\s'), '');
    final parts = text.split('.');
    if (parts.length != 3 ||
        !parts[0].toUpperCase().startsWith(prefix) ||
        parts[1].isEmpty) {
      return const PairingDecode.error(PairingError.malformed);
    }
    final Map<String, Object?> j;
    try {
      final body = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(body)));
      if (decoded is! Map) throw const FormatException();
      j = decoded.cast<String, Object?>();
    } catch (_) {
      // A changed character usually breaks the base64 or the JSON first.
      return const PairingDecode.error(PairingError.checksum);
    }

    // The version decides how the rest is read, so it is checked first.
    if (j['v'] != PairingPayload.version ||
        parts[0].toUpperCase() != '$prefix${PairingPayload.version}') {
      return const PairingDecode.error(PairingError.unsupportedVersion);
    }

    final id = j['caretakerId'], phone = j['phone'], name = j['name'];
    final typeName = j['type'];
    final type = CaretakerType.fromName(typeName is String ? typeName : null);
    final issuedAt = j['issuedAt'];
    if (id is! String ||
        id.isEmpty ||
        phone is! String ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phone) ||
        name is! String ||
        name.trim().isEmpty ||
        type == null ||
        issuedAt is! int) {
      return const PairingDecode.error(PairingError.malformed);
    }
    final payload = PairingPayload(
      caretakerId: id,
      phone: phone,
      name: name,
      type: type,
      issuedAt: issuedAt,
    );
    if (checksum(payload.canonicalJson()) != parts[2].toLowerCase()) {
      return const PairingDecode.error(PairingError.checksum);
    }

    final age = now.difference(payload.issuedTime);
    if (age > validFor) return const PairingDecode.error(PairingError.expired);
    if (-age > clockSkew) {
      return const PairingDecode.error(PairingError.clockWrong);
    }
    return PairingDecode.ok(payload);
  }

  /// When a code issued at [issuedAt] (epoch seconds) stops working.
  static DateTime expiresAt(int issuedAt) =>
      DateTime.fromMillisecondsSinceEpoch(issuedAt * 1000).add(validFor);

  /// The 4 digits the patient's phone shows after a successful scan. Derived
  /// from the caretaker id alone, so the caretaker's phone can check it with
  /// no network.
  static String confirmationCode(String caretakerId) {
    final hex = sha256
        .convert(utf8.encode('rapidrx:pair-confirm:$caretakerId'))
        .toString();
    final n = int.parse(hex.substring(0, 8), radix: 16) % 10000;
    return n.toString().padLeft(4, '0');
  }

  /// No 0/O or 1/I: someone may read it aloud.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String newCaretakerId([Random? random]) {
    final r = random ?? Random.secure();
    return [for (var i = 0; i < 10; i++) _alphabet[r.nextInt(_alphabet.length)]]
        .join();
  }

  static int epochSeconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
}
