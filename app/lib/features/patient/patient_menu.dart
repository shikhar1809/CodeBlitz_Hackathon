import 'package:flutter/material.dart';

import '../../core/dev_flags.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_alarm.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/app_bar_actions.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../ai/ai_config.dart';
import '../../ai/gemini_client.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../platform/dose_reminders.dart';
import '../doses/alarm_launcher.dart';
import '../doses/reminder_sync.dart';
import '../caregiver/family.dart';
import '../doses/dose_log_store.dart';
import '../health/found_card_banner.dart';
import '../sync/sync_queue.dart';
import '../doses/schedule_screen.dart';
import '../medicines/medicine_store.dart';
import '../visit/visit.dart';
import '../visit/visit_repository.dart';
import '../wizard/online_read_card.dart';
import '../pairing/patient_pairing.dart';
import '../pairing/patient_scan_screen.dart';
import '../wizard/wizard_controller.dart';
import '../wizard/wizard_screen.dart';
import 'prescriptions_screen.dart';

/// Where the patient lands: three things they can do, all visible at once.
///
/// A menu, not today's doses (ADR-19). The first thing a new user needs is to
/// add a prescription, and the first thing a returning user needs depends on
/// the time of day — so the app asks rather than guessing.
class PatientMenu extends StatelessWidget {
  const PatientMenu({
    super.key,
    required this.onRestart,
    this.onNewPrescription,
    this.onSchedule,
    this.demoTools = DevFlags.demoTools,
  });

  final VoidCallback onRestart;
  final VoidCallback? onNewPrescription;
  final VoidCallback? onSchedule;

  /// The small "Demo" link under the tiles (DevFlags.demoTools).
  final bool demoTools;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final tiles = <Widget>[
      _MenuTile(
        icon: Icons.add_a_photo_outlined,
        title: s.newPrescription,
        subtitle: s.newPrescriptionWhy,
        onTap: onNewPrescription ?? () => openWizard(context),
      ),
      _MenuTile(
        icon: Icons.description_outlined,
        title: s.myPrescriptions,
        subtitle: s.myPrescriptionsWhy,
        onTap: () => openPrescriptions(context),
      ),
      _MenuTile(
        icon: Icons.schedule_rounded,
        title: s.medicineSchedule,
        subtitle: s.medicineScheduleWhy,
        onTap: onSchedule ?? () => openSchedule(context),
      ),
      _MenuTile(
        icon: Icons.qr_code_scanner_rounded,
        title: s.scanCaretakerQr,
        subtitle: s.scanCaretakerQrWhy,
        onTap: () => openScanCaretaker(context),
      ),
    ];

    return VoicePrompt(
      text:
          '${s.menuQuestion} 1. ${s.newPrescription}. '
          '2. ${s.myPrescriptions}. 3. ${s.medicineSchedule}. '
          '4. ${s.scanCaretakerQr}.',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            s.hello(AppScope.maybeOf(context)?.prefs.name),
            overflow: TextOverflow.ellipsis,
          ),
          actions: appBarActions(context, onRestart: onRestart),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // All tiles must fit without scrolling. Below this height
                // they would squash their text, so scroll instead.
                const minTile = 132.0;
                const header = 56.0;
                // The demo link sits below the tiles, and must not push them
                // off the screen.
                final footer = demoTools ? _DemoLink.height : 0.0;
                final n = tiles.length;
                final fits =
                    (constraints.maxHeight - header - footer - 16 * (n - 1)) /
                        n >=
                    minTile;
                final heading = Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A PM-JAY card found after an offline lookup.
                      const FoundCardBanner(),
                      Text(
                        s.menuQuestion,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                );
                if (!fits) {
                  return ListView(
                    children: [
                      heading,
                      for (final t in tiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(height: minTile, child: t),
                        ),
                      if (demoTools) const _DemoLink(),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Expanded(child: tiles[i]),
                    ],
                    if (demoTools) const _DemoLink(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openPrescriptions(BuildContext context) async {
  final navigator = Navigator.of(context);
  final store = await MedicineStore.load();
  final queue = await SyncQueue.load();
  final records = store.records();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PrescriptionsScreen(
        records: records,
        waiting: {
          for (final r in records)
            if (queue.waitingFor(r.id)) r.id,
        },
      ),
    ),
  );
}

Future<void> openSchedule(BuildContext context) async {
  final navigator = Navigator.of(context);
  final state = AppScope.of(context);
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  final family = familyNotifier(state);
  final strings = AppStrings(state.language);
  final reminders = DoseReminders();
  // Every open is a full re-sync, and the banner shows what really happened.
  final status = await syncReminders(
    reminders: reminders,
    medicines: store.active(),
    logs: logs,
    strings: strings,
  );
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (routeContext) => ScheduleScreen(
        store: store,
        logs: logs,
        reminderBanner: reminderBanner(status, strings),
        // Nothing runs in the background, so opening the schedule is when
        // missed doses are found and queued alerts get another go.
        onOpened: (meds, now) async {
          await family.drainOutbox(now: now);
          await family.checkMissed(meds, logs, now: now);
        },
        onConfirmed: (slot, date) async {
          // The nudge must never fire for a dose already taken.
          await reminders.cancelSlot(slot);
          await family.doseTaken(slot, date, now: DateTime.now());
          await syncReminders(
            reminders: reminders,
            medicines: store.active(),
            logs: logs,
            strings: strings,
          );
        },
        onShare: () => sharePlan(routeContext, store.active()),
      ),
    ),
  );
}

Future<void> openScanCaretaker(BuildContext context) {
  final prefs = AppScope.of(context).prefs;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PatientScanScreen(pairing: PatientPairing(prefs: prefs)),
    ),
  );
}

/// Start (or resume) a new prescription. A visit left half-way is picked up
/// where it was, because it was saved after every capture.
Future<void> openWizard(BuildContext context) async {
  final navigator = Navigator.of(context);
  final strings = AppStrings(AppScope.of(context).language);
  final sync = AppScope.maybeOf(context)?.sync;
  final repository = await VisitRepository.load();
  final store = await MedicineStore.load();
  // One client per visit: its budget of calls is per visit.
  final gemini = GeminiClient();
  final controller = VisitWizardController(
    visit: repository.loadDraft() ?? Visit.start(),
    repository: repository,
    store: store,
    sync: sync,
  );
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => WizardScreen(
        controller: controller,
        // Only with a key. The card also hides itself when offline.
        onlineCard: AiConfig.hasGeminiKey
            ? (c) => OnlineReadCard(controller: c, client: gemini)
            : null,
      ),
    ),
  );
  controller.dispose();
  // New medicines mean new alarms.
  await syncReminders(
    reminders: DoseReminders(),
    medicines: store.active(),
    logs: await DoseLogStore.load(),
    strings: strings,
  );
}

/// Demo tools, kept small and out of the patient's way: one link under the
/// tiles, which opens a sheet with the two ways to fire the dose alarm.
class _DemoLink extends StatelessWidget {
  const _DemoLink();

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.demoSection.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.alarm_rounded),
              label: Text(s.doseDemo),
              onPressed: () => _showDemoSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDemoSheet(BuildContext context) {
  final s = L10n.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: AppTheme.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.doseDemo, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.alarm_on_rounded),
              label: Text(s.doseDemoNow),
              onPressed: () {
                Navigator.pop(sheet);
                openDoseDemo(context);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_clock_outlined),
              label: Text(s.doseDemoRing),
              onPressed: () {
                Navigator.pop(sheet);
                openDoseDemo(context, ring: true);
              },
            ),
            const SizedBox(height: 8),
            Text(
              s.doseDemoRingWhy,
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BigChoiceTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      iconSize: 60,
      titleStyle: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontSize: 24, height: 1.2),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      alignTop: true,
      minHeight: AppTheme.tapTarget,
    );
  }
}
