import 'package:flutter/material.dart';

import '../../core/dose_book.dart';
import '../../core/schedule.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// "Medicine time": large, two taps at most. Taken all · Taken some · Snooze.
class DoseCheckIn extends StatelessWidget {
  final Occurrence o;
  const DoseCheckIn({super.key, required this.o});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.doses;
    final hi = d.hindi;
    final now = app.now();
    final late = now.difference(o.due);
    final meds = [for (final id in o.medIds) d.book.med(id)].whereType<Medicine>().toList();
    return Material(
      color: W.page,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: GradientIcon(WIcons.pill, W.green, size: 76)),
            const SizedBox(height: 16),
            Text(hi ? 'दवा का समय' : 'Medicine time',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            Text(
              '${DayTime(o.due.hour, o.due.minute).label}'
              '${late.inMinutes >= 1 ? ' · ${late.inMinutes} min ago' : ''}'
              '${app.settings.caregiver ? ' · for ${d.patient}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: W.text2),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(children: [
                for (final m in meds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const TintIcon(WIcons.pill, W.leaf, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                            if (m.note.isNotEmpty)
                              Text(m.note, style: const TextStyle(fontSize: 17, color: W.text2)),
                          ]),
                        ),
                        if (o.taken.contains(m.id)) const Icon(WIcons.tick, color: W.leaf, size: 30),
                      ]),
                    ),
                  ),
              ]),
            ),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E9E5B),
                  textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => d.takeAll(o),
                icon: const Icon(WIcons.tick, size: 28),
                label: Text(hi ? 'सब ले ली · Taken all' : 'Taken all · सब ले ली'),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              if (o.medIds.length > 1)
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PerPillConfirm(o: o), fullscreenDialog: true)),
                      child: Text(hi ? 'कुछ ली' : 'Taken some'),
                    ),
                  ),
                ),
              if (o.medIds.length > 1) const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    onPressed: o.snoozes >= DoseBook.maxSnoozes
                        ? null
                        : () {
                            if (!d.snooze(o)) app.showBanner('No more snoozes for this dose');
                          },
                    child: Text(hi ? '10 मिनट बाद' : 'Snooze 10 min'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              app.settings.contacts('family').isEmpty
                  ? 'Not medical advice. Follow your doctor.'
                  : 'If not confirmed, ${app.settings.contacts('family').first.name} is told after an hour. Not medical advice.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: W.text2),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tick each medicine actually taken.
class PerPillConfirm extends StatefulWidget {
  final Occurrence o;
  const PerPillConfirm({super.key, required this.o});
  @override
  State<PerPillConfirm> createState() => _PerPillConfirmState();
}

class _PerPillConfirmState extends State<PerPillConfirm> {
  late final Set<String> _picked = {...widget.o.taken};

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.doses;
    return Scaffold(
      appBar: AppBar(title: Text(d.hindi ? 'कौन सी दवा ली?' : 'Which did you take?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Expanded(
              child: ListView(children: [
                for (final id in widget.o.medIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WCard(
                      padding: EdgeInsets.zero,
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        value: _picked.contains(id),
                        onChanged: widget.o.taken.contains(id)
                            ? null
                            : (v) => setState(() => v == true ? _picked.add(id) : _picked.remove(id)),
                        title: Text(d.book.med(id)?.label ?? id,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        subtitle: Text(d.book.med(id)?.note ?? '', style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
              ]),
            ),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _picked.difference(widget.o.taken).isEmpty
                    ? null
                    : () {
                        d.takeSome(widget.o, _picked.difference(widget.o.taken));
                        Navigator.pop(context);
                      },
                child: const Text('Save', style: TextStyle(fontSize: 20)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
