import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/scheduled_medicine.dart';
import 'caregiver_notifier.dart';
import 'plan_summary.dart';
import 'whatsapp_alerts.dart';

/// Builds the notifier for this phone: the patient's name, the family number
/// given at onboarding (or changed later), in the app's language.
CaregiverNotifier familyNotifier(AppState state, {WhatsAppAlerts? alerts}) =>
    CaregiverNotifier(
      alerts: alerts ?? WhatsAppAlerts(),
      prefs: state.prefs.raw,
      patientName: state.prefs.name ?? '',
      caregiverPhone: state.prefs.alertPhone,
      strings: AppStrings(state.language),
    );

/// The whole plan, as plain text, into any app the person picks.
Future<void> sharePlan(
  BuildContext context,
  Iterable<ScheduledMedicine> medicines,
) async {
  final state = AppScope.of(context);
  final text = PlanSummary.plan(
    name: state.prefs.name ?? '',
    medicines: medicines,
    today: DateTime.now(),
    s: AppStrings(state.language),
  );
  await SharePlus.instance.share(ShareParams(text: text));
}
