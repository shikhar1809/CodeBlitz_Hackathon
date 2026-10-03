import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/storage/app_prefs.dart';
import 'pairing_channel.dart';
import 'pairing_code.dart';

/// The caretaker a patient linked, as the patient's phone keeps it. Their
/// phone number is where WhatsApp alerts go (it replaces the old family
/// number).
class LinkedCaretaker {
  const LinkedCaretaker({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.linkedAt,
    this.pinHash,
  });

  final String id;
  final String name;

  /// Ten digits, OTP-verified on the caretaker's own phone.
  final String phone;
  final CaretakerType type;
  final DateTime linkedAt;

  /// A commercial caretaker's PIN, hashed like the patient's own
  /// ([AppPrefs.hashPin]). Null for family.
  final String? pinHash;

  bool checkPin(String pin) =>
      pinHash != null && pinHash == AppPrefs.hashPin(pin);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'type': type.name,
    'linkedAt': linkedAt.toIso8601String(),
    'pinHash': ?pinHash,
  };

  static LinkedCaretaker? fromJsonString(String? raw) {
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return LinkedCaretaker(
        id: j['id']! as String,
        name: j['name']! as String,
        phone: j['phone']! as String,
        type: CaretakerType.fromName(j['type'] as String?)!,
        linkedAt: DateTime.parse(j['linkedAt']! as String),
        pinHash: j['pinHash'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static LinkedCaretaker? of(AppPrefs prefs) =>
      fromJsonString(prefs.linkedCaretakerJson);
}

enum ScanStep {
  /// Point the camera, or type the code.
  scan,

  /// A valid code: "Sunita — Family member". Link them?
  found,

  /// A commercial caretaker: the patient sets their PIN.
  setPin,

  /// Linked. Show the confirmation code.
  done,
}

enum PinProblem { short, mismatch }

/// The patient's side of pairing: check a scanned or typed code, show who it
/// is, set a PIN for a paid caretaker, save the link, and produce the
/// 4-digit confirmation code. No widgets; the clock and channel are injected.
class PatientPairing extends ChangeNotifier {
  PatientPairing({
    required this.prefs,
    this.channel = const LocalPairingChannel(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppPrefs prefs;
  final PairingChannel channel;
  final DateTime Function() _clock;

  ScanStep _step = ScanStep.scan;
  ScanStep get step => _step;

  PairingError? _error;

  /// Why the last code was refused.
  PairingError? get error => _error;

  PairingPayload? _found;
  PairingPayload? get found => _found;

  PinProblem? _pinProblem;
  PinProblem? get pinProblem => _pinProblem;

  String? _confirmation;

  /// The 4 digits for the caretaker to type, once linked.
  String? get confirmationCode => _confirmation;

  bool _busy = false;

  /// A scanned or typed code. The camera reports the same code many times a
  /// second, so anything after the first good one is ignored.
  bool submit(String raw) {
    if (_step != ScanStep.scan || _busy) return false;
    final d = PairingCode.decode(raw, now: _clock());
    if (!d.ok) {
      _error = d.error;
      notifyListeners();
      return false;
    }
    _error = null;
    _found = d.payload;
    _step = ScanStep.found;
    notifyListeners();
    return true;
  }

  /// "Not them? Scan again."
  void rescan() {
    _found = null;
    _error = null;
    _pinProblem = null;
    _step = ScanStep.scan;
    notifyListeners();
  }

  /// The patient said yes to this caretaker. Family is linked at once; a
  /// commercial caretaker needs a PIN first.
  Future<void> accept() async {
    final c = _found;
    if (c == null) return;
    if (c.type == CaretakerType.commercial) {
      _step = ScanStep.setPin;
      notifyListeners();
      return;
    }
    await _link(c, pinHash: null);
  }

  /// Set a commercial caretaker's PIN, typed twice.
  Future<bool> setPin(String pin, String again) async {
    final c = _found;
    if (c == null || _step != ScanStep.setPin) return false;
    if (!RegExp(r'^\d{4}$').hasMatch(pin.trim())) {
      _pinProblem = PinProblem.short;
    } else if (pin.trim() != again.trim()) {
      _pinProblem = PinProblem.mismatch;
    } else {
      _pinProblem = null;
    }
    if (_pinProblem != null) {
      notifyListeners();
      return false;
    }
    await _link(c, pinHash: AppPrefs.hashPin(pin.trim()));
    return true;
  }

  Future<void> _link(PairingPayload c, {required String? pinHash}) async {
    _busy = true;
    await prefs.setLinkedCaretakerJson(
      jsonEncode(
        LinkedCaretaker(
          id: c.caretakerId,
          name: c.name,
          phone: c.phone,
          type: c.type,
          linkedAt: _clock(),
          pinHash: pinHash,
        ).toJson(),
      ),
    );
    _confirmation = await channel.patientLinked(
      c,
      patientName: prefs.name ?? '',
    );
    _busy = false;
    _step = ScanStep.done;
    notifyListeners();
  }
}

/// Forget the linked caretaker. Alerts stop going to them at once.
Future<void> unlinkCaretaker(AppPrefs prefs) =>
    prefs.setLinkedCaretakerJson(null);

/// Why a scanned code was refused, in the words on the screen.
String pairingErrorMessage(PairingError e, AppStrings s) => switch (e) {
  PairingError.malformed => s.codeMalformed,
  PairingError.unsupportedVersion => s.codeVersion,
  PairingError.checksum => s.codeChecksum,
  PairingError.expired => s.codeExpired,
  PairingError.clockWrong => s.codeClock,
};
