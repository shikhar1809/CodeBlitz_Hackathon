import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/storage/app_prefs.dart';
import 'pairing_channel.dart';
import 'pairing_code.dart';

/// The patient a caretaker is linked to, as the caretaker's phone keeps it.
class LinkedPatient {
  const LinkedPatient({
    required this.name,
    required this.caretakerId,
    required this.pairedAt,
  });

  /// As the caretaker typed it beside the code: the 4-digit code cannot
  /// carry a name (ADR-45).
  final String name;
  final String caretakerId;
  final DateTime pairedAt;

  Map<String, Object?> toJson() => {
    'name': name,
    'caretakerId': caretakerId,
    'pairedAt': pairedAt.toIso8601String(),
  };

  static LinkedPatient? fromJsonString(String? raw) {
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return LinkedPatient(
        name: j['name']! as String,
        caretakerId: j['caretakerId']! as String,
        pairedAt: DateTime.parse(j['pairedAt']! as String),
      );
    } catch (_) {
      return null;
    }
  }
}

enum ConfirmError { nameMissing, codeShort, wrongCode }

/// The caretaker's side of pairing: their QR code, its expiry, and checking
/// the code the patient's phone shows. No widgets; the clock and the channel
/// are injected so tests drive it.
class CaretakerPairing extends ChangeNotifier {
  CaretakerPairing({
    required this.prefs,
    this.channel = const LocalPairingChannel(),
    DateTime Function()? clock,
    this.random,
  }) : _clock = clock ?? DateTime.now;

  final AppPrefs prefs;
  final PairingChannel channel;
  final DateTime Function() _clock;

  /// Injected by tests, for a known caretaker id.
  final Random? random;

  DateTime now() => _clock();

  /// The current code. The caretaker id is made once and kept; the first
  /// call also stamps the issue time. Writes are cached by
  /// SharedPreferences at once, so this is safe to call from a build.
  PairingPayload code() {
    var id = prefs.caretakerId;
    if (id == null) {
      id = PairingCode.newCaretakerId(random);
      prefs.setCaretakerId(id);
    }
    var issued = prefs.caretakerCodeIssuedAt;
    if (issued == null) {
      issued = PairingCode.epochSeconds(_clock());
      prefs.setCaretakerCodeIssuedAt(issued);
    }
    return PairingPayload(
      caretakerId: id,
      phone: prefs.phoneNumber ?? '',
      name: prefs.name ?? '',
      type: prefs.caretakerType ?? CaretakerType.family,
      issuedAt: issued,
    );
  }

  String encoded() => PairingCode.encode(code());

  DateTime get expiresAt => PairingCode.expiresAt(code().issuedAt);

  bool get expired => !_clock().isBefore(expiresAt);

  /// Whole minutes left, rounded up, never below zero.
  int get minutesLeft {
    final left = expiresAt.difference(_clock());
    if (left.isNegative) return 0;
    return (left.inSeconds / 60).ceil();
  }

  /// Same caretaker id, a fresh fifteen minutes.
  Future<void> makeNewCode() async {
    await prefs.setCaretakerCodeIssuedAt(PairingCode.epochSeconds(_clock()));
    notifyListeners();
  }

  /// "I'll do this later": the home screen offers it again.
  Future<void> later() => prefs.setCaretakerPairLater(true);

  LinkedPatient? get linked =>
      LinkedPatient.fromJsonString(prefs.linkedPatientJson);

  /// Check the code the patient's phone shows. On a match the link is kept
  /// on this phone and null comes back.
  Future<ConfirmError?> confirm({
    required String patientName,
    required String code,
  }) async {
    final name = patientName.trim();
    if (name.isEmpty) return ConfirmError.nameMissing;
    final digits = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(digits)) return ConfirmError.codeShort;
    final id = this.code().caretakerId;
    final outcome = await channel.caretakerConfirm(
      caretakerId: id,
      code: digits,
    );
    if (outcome != ConfirmOutcome.linked) return ConfirmError.wrongCode;
    await prefs.setLinkedPatientJson(
      jsonEncode(
        LinkedPatient(name: name, caretakerId: id, pairedAt: _clock()).toJson(),
      ),
    );
    await prefs.setCaretakerPairLater(false);
    notifyListeners();
    return null;
  }
}
