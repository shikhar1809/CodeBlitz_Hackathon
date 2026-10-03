import 'pairing_code.dart';

/// What happened when a caretaker typed the patient's code.
enum ConfirmOutcome {
  /// The code matches: the two phones saw the same QR code.
  linked,

  /// Not the code the patient's phone shows.
  wrongCode,
}

/// How the two phones agree that a pairing happened.
///
/// There is no backend in this build (ADR-45). A real one replaces
/// [LocalPairingChannel] behind this interface: the patient's phone posts the
/// link, and the caretaker's phone is told — no code to type. Until then the
/// patient's phone shows a 4-digit code and the caretaker types it, which
/// proves the patient really scanned *this* caretaker's QR.
abstract class PairingChannel {
  /// Patient phone: the patient accepted [caretaker]. Returns the 4-digit
  /// code to show the caretaker.
  Future<String> patientLinked(
    PairingPayload caretaker, {
    required String patientName,
  });

  /// Caretaker phone: check the code the patient's phone shows.
  Future<ConfirmOutcome> caretakerConfirm({
    required String caretakerId,
    required String code,
  });
}

/// No network: both phones derive the code from the caretaker id.
class LocalPairingChannel implements PairingChannel {
  const LocalPairingChannel();

  @override
  Future<String> patientLinked(
    PairingPayload caretaker, {
    required String patientName,
  }) async => PairingCode.confirmationCode(caretaker.caretakerId);

  @override
  Future<ConfirmOutcome> caretakerConfirm({
    required String caretakerId,
    required String code,
  }) async => code.trim() == PairingCode.confirmationCode(caretakerId)
      ? ConfirmOutcome.linked
      : ConfirmOutcome.wrongCode;
}
