import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/storage/app_prefs.dart';
import '../pairing/caretaker_pairing.dart';
import 'book_appointment_screen.dart';
import 'hub_connect_screen.dart';

/// The Home Hub screen: pair, or see the paired Hub and let it go.
Future<void> openHubConnect(BuildContext context) {
  final prefs = AppScope.of(context).prefs;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => HubConnectScreen(prefs: prefs)),
  );
}

/// "Book a doctor's visit", from the patient's menu or the caretaker's home.
///
/// Not paired yet: the Home Hub screen first, and the form only once it is
/// paired. A patient books for themselves, so their name, number and age are
/// filled in; a caretaker books for the patient they are linked to, whose
/// name is all this phone knows.
Future<void> openBookAppointment(BuildContext context) async {
  final prefs = AppScope.of(context).prefs;
  final navigator = Navigator.of(context);
  if (!prefs.hasHub) {
    final paired = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => HubConnectScreen(prefs: prefs, popWhenConnected: true),
      ),
    );
    if (paired != true) return;
  }
  final caretaker = prefs.role == AppRole.caregiver;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => caretaker
          ? BookAppointmentScreen(
              prefs: prefs,
              patientName: LinkedPatient.fromJsonString(prefs.linkedPatientJson)
                  ?.name,
            )
          : BookAppointmentScreen(
              prefs: prefs,
              patientName: prefs.name,
              patientPhone: prefs.phoneNumber,
              patientAge: prefs.age,
            ),
    ),
  );
}
