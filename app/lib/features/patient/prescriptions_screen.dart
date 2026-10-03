import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/scheduled_medicine.dart';
import '../wizard/wizard_widgets.dart';

/// Every approved visit, one card each: when it was added, the medicines it
/// carried, and what it was built from.
class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({
    super.key,
    this.records = const [],
    this.waiting = const {},
  });

  final List<PrescriptionRecord> records;

  /// Visits with something still in the sync queue.
  final Set<String> waiting;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.myPrescriptions)),
      body: records.isEmpty
          ? EmptyState(icon: Icons.description, text: s.noPrescriptionsYet)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _RecordCard(
                record: records[i],
                waiting: waiting.contains(records[i].id),
              ),
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.waiting});

  final PrescriptionRecord record;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final names = [...record.medicineNames.map(PlainLanguage.titleCase)]
      ..sort();
    return ToneCard(
      fill: AppColors.surface,
      border: AppColors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _date(record.addedAt, s),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Pill('${record.medicineNames.length}', tone: PillTone.amber),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            names.join(', '),
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Pill(
                waiting ? s.waitingToSync : s.syncedLabel,
                tone: waiting ? PillTone.warn : PillTone.green,
              ),
              if (record.onlineReading != null)
                Pill(s.reviewReading, tone: PillTone.strong),
            ],
          ),
          if (record.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final e in record.evidence)
                  if (_evidence(e, s) case final label?) Pill(label),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String? _evidence(String e, AppStrings s) => switch (e) {
    'doctor' => s.evidenceDoctor,
    'prescription' => s.evidencePrescription,
    'bill' => s.evidenceBill,
    'chemist' => s.evidenceChemist,
    _ => null,
  };

  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsHi = [
    'जन॰', 'फ़र॰', 'मार्च', 'अप्रैल', 'मई', 'जून', //
    'जुल॰', 'अग॰', 'सित॰', 'अक्टू॰', 'नव॰', 'दिस॰',
  ];

  static String _date(DateTime d, AppStrings s) =>
      '${d.day} ${(s.isHindi ? _monthsHi : _monthsEn)[d.month - 1]} ${d.year}';
}

/// A calm, centred "nothing here yet" — an icon and one honest sentence.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -.8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
