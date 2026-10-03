import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

enum PinResult { wrong, real, duress, code }

/// PIN, duress PIN and optional keypad code, stored only as salted hashes.
class PinVault {
  final String salt;
  String? pinHash;
  String? duressHash;
  String? codeHash;

  PinVault({String? salt, this.pinHash, this.duressHash, this.codeHash})
      : salt = salt ?? _newSalt();

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
  }

  String hash(String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool validPin(String p) => RegExp(r'^\d{4,8}$').hasMatch(p);
  static bool validCode(String p) => RegExp(r'^\d{3,8}$').hasMatch(p);

  bool get isSet => pinHash != null;
  bool get hasCode => codeHash != null;

  void setPins(String pin, String duress) {
    if (!validPin(pin) || !validPin(duress)) {
      throw ArgumentError('PINs must be 4 to 8 digits');
    }
    if (pin == duress) throw ArgumentError('PIN and duress PIN must differ');
    pinHash = hash(pin);
    duressHash = hash(duress);
  }

  void setCode(String? code) {
    if (code == null) {
      codeHash = null;
      return;
    }
    if (!validCode(code)) throw ArgumentError('Code must be 3 to 8 digits');
    if (hash(code) == duressHash) {
      throw ArgumentError('Code cannot be the duress PIN');
    }
    codeHash = hash(code);
  }

  PinResult check(String entry) {
    if (entry.isEmpty) return PinResult.wrong;
    final h = hash(entry);
    if (h == pinHash) return PinResult.real;
    if (h == duressHash) return PinResult.duress;
    if (codeHash != null && h == codeHash) return PinResult.code;
    return PinResult.wrong;
  }

  Map<String, dynamic> toJson() =>
      {'salt': salt, 'pin': pinHash, 'duress': duressHash, 'code': codeHash};

  factory PinVault.fromJson(Map<String, dynamic> j) => PinVault(
        salt: j['salt'] as String?,
        pinHash: j['pin'] as String?,
        duressHash: j['duress'] as String?,
        codeHash: j['code'] as String?,
      );
}
