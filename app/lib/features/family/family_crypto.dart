import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The family code and everything derived from it. Byte for byte the same as
/// the Home Vault (vault/src/family_crypto.js) and the family portal, so all
/// three agree.
///
///   family code   16 random bytes, shown as 26 Crockford base32 characters
///   household id  HKDF-SHA256(code, "winger", "household-id"), 8 bytes, hex
///   access token  HKDF-SHA256(code, "winger", "access"), 32 bytes, base64url
///   data key      HKDF-SHA256(code, "winger", "data"), 32 bytes, AES-256-GCM
///
/// The phone encrypts before anything leaves it; a server only ever holds the
/// household id, a hash of the token, and ciphertext.
class FamilyKeys {
  const FamilyKeys(this.householdId, this.accessToken, this.dataKey);

  final String householdId;
  final String accessToken;
  final List<int> dataKey;
}

class SealedBox {
  const SealedBox(this.iv, this.ct);
  final String iv;
  final String ct;

  Map<String, String> toJson() => {'iv': iv, 'ct': ct};
}

abstract final class FamilyCrypto {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static String newCode([Random? random]) {
    final r = random ?? Random.secure();
    return encode(List.generate(16, (_) => r.nextInt(256)));
  }

  static String encode(List<int> bytes) {
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final b in bytes) {
      value = ((value << 8) | b) & 0xFFFF;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(_alphabet[(value << (5 - bits)) & 31]);
    return out.toString();
  }

  /// Accepts dashes, spaces, lower case, and O/I/L typed for 0/1.
  static Uint8List decode(String code) {
    final clean = code
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1');
    if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(clean)) {
      throw const FormatException('bad family code');
    }
    var bits = 0, value = 0;
    final out = <int>[];
    for (final ch in clean.split('')) {
      value = ((value << 5) | _alphabet.indexOf(ch)) & 0xFFFF;
      bits += 5;
      if (bits >= 8) {
        out.add((value >> (bits - 8)) & 255);
        bits -= 8;
      }
    }
    return Uint8List.fromList(out.take(16).toList());
  }

  /// "ABCD-EFGH-…", for reading out over the phone.
  static String pretty(String code) => code
      .replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]}-');

  static Future<List<int>> _hkdf(List<int> secret, String info, int length) async {
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: length).deriveKey(
      secretKey: SecretKey(secret),
      nonce: utf8.encode('winger'),
      info: utf8.encode(info),
    );
    return key.extractBytes();
  }

  static Future<FamilyKeys> derive(String code) async {
    final secret = decode(code);
    final id = await _hkdf(secret, 'household-id', 8);
    final token = await _hkdf(secret, 'access', 32);
    final data = await _hkdf(secret, 'data', 32);
    return FamilyKeys(
      id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      base64Url.encode(token).replaceAll('=', ''),
      data,
    );
  }

  static final _aes = AesGcm.with256bits();

  /// AES-256-GCM, with the household and record kind bound in as AAD.
  /// The tag is appended to the ciphertext, as WebCrypto and Node expect.
  static Future<SealedBox> seal(List<int> key, String plaintext, String aad) async {
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return SealedBox(
      base64.encode(box.nonce),
      base64.encode([...box.cipherText, ...box.mac.bytes]),
    );
  }

  static Future<String> open(List<int> key, SealedBox box, String aad) async {
    final body = base64.decode(box.ct);
    final clear = await _aes.decrypt(
      SecretBox(
        body.sublist(0, body.length - 16),
        nonce: base64.decode(box.iv),
        mac: Mac(body.sublist(body.length - 16)),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return utf8.decode(clear);
  }
}
