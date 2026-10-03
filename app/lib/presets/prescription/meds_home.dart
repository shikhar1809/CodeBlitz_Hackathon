import 'package:flutter/material.dart';

import '../../core/dose_book.dart';
import '../../core/schedule.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'add_medicine_screen.dart';

/// Home for the Prescription Agent: the next dose, today's doses, medicines.
class MedsHome extends StatelessWidget {
  const MedsHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.doses;
    final now = app.now();
    final today = d.book.today(now);
    final next = d.book.nextDue(now);
    final adherence = d.book.adherence(now);
    final family = app.settings.contacts('family');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WCard(
        radius: 28,
        child: Row(children: [
          const GradientIcon(WIcons.alarm, W.green, size: 62),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Next dose', style: TextStyle(color: W.text2)),
              Text(
                next == null ? 'Nothing scheduled' : '${_dayLabel(next, now)}${DayTime(next.hour, next.minute).label}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              if (next != null)
                Text(
                  d.book.medicines
                      .where((m) => m.schedule.between(next, next.add(const Duration(minutes: 1))).isNotEmpty)
                      .map((m) => m.label)
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: W.text2),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _Stat(
            icon: WIcons.calendar,
            color: W.leaf,
            value: adherence == null ? '—' : '${(adherence * 100).round()}%',
            label: 'Taken today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat(
            icon: WIcons.people,
            color: W.magenta,
            value: family.isEmpty ? 'None' : family.first.name.split(' ').first,
            label: 'Told if missed',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        const Expanded(child: Text('Today', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedicineScreen())),
          icon: const Icon(WIcons.addSquare),
          label: const Text('Add medicine'),
        ),
      ]),
      const SizedBox(height: 6),
      if (today.isEmpty)
        WCard(
          child: Column(children: [
            const Text('No doses today. Add a medicine exactly as the doctor wrote it.',
                textAlign: TextAlign.center, style: TextStyle(color: W.text2)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedicineScreen())),
              child: const Text('Add medicine'),
            ),
          ]),
        ),
      for (final o in today) _DoseRow(o: o, now: now),
      const SizedBox(height: 12),
      const Text('Not medical advice. Follow your doctor.',
          textAlign: TextAlign.center, style: TextStyle(color: W.text2, fontSize: 12)),
    ]);
  }

  static String _dayLabel(DateTime t, DateTime now) {
    final d = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return d == 0 ? '' : d == 1 ? 'Tomorrow ' : '${t.day}/${t.month} ';
  }
}

class _DoseRow extends StatelessWidget {
  final Occurrence o;
  final DateTime now;
  const _DoseRow({required this.o, required this.now});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.doses;
    final status = o.status(now);
    final (label, color) = switch (status) {
      DoseStatus.upcoming => ('Upcoming', W.text2),
      DoseStatus.due => (o.snoozedUntil != null && now.isBefore(o.snoozedUntil!) ? 'Snoozed' : 'Due now', W.marigold),
      DoseStatus.taken => ('Taken', W.leaf),
      DoseStatus.partial => ('Some taken', W.marigold),
      DoseStatus.missed => ('Missed · family told', W.sos),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WCard(
        padding: const EdgeInsets.all(16),
        onTap: status == DoseStatus.taken || status == DoseStatus.upcoming
            ? null
            : () {
                o.snoozedUntil = null;
                app.arbiter.remove(o.id);
                d.syncArbiter(now);
                app.changed();
              },
        child: Row(children: [
          SizedBox(
            width: 82,
            child: Text(DayTime(o.due.hour, o.due.minute).label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(o.medIds.map((id) => d.book.med(id)?.label ?? id).join('\n'),
                style: const TextStyle(fontSize: 15, height: 1.35)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => WCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          TintIcon(icon, color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              Text(label, style: const TextStyle(color: W.text2, fontSize: 12)),
            ]),
          ),
        ]),
      );
}
