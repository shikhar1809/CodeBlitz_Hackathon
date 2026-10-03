import 'package:flutter/material.dart';

import '../../core/dose_book.dart';
import '../../core/schedule.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Add a medicine exactly as prescribed. Nothing is scheduled until a human
/// confirms it matches the prescription (Winger never invents a dose).
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});
  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _note = TextEditingController();
  final List<DayTime> _times = [const DayTime(9, 0)];
  final Set<int> _days = {};
  int? _forDays;
  bool _checked = false;
  String? _error;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 21, minute: 0));
    if (t == null) return;
    final d = DayTime(t.hour, t.minute);
    if (!_times.contains(d)) setState(() => _times.add(d));
  }

  void _save() {
    final app = AppScope.read(context);
    String? err;
    if (_name.text.trim().isEmpty) err = 'Name of the medicine, as on the strip.';
    if (_times.isEmpty) err = 'Add at least one time.';
    if (!_checked) err = 'Confirm this matches the prescription.';
    setState(() => _error = err);
    if (err != null) return;
    final now = app.now();
    final start = DateTime(now.year, now.month, now.day);
    app.doses.addMedicine(Medicine(
      id: 'm${now.microsecondsSinceEpoch}',
      name: _name.text.trim(),
      strength: _strength.text.trim(),
      note: _note.text.trim(),
      since: now,
      schedule: Schedule(
        times: _times,
        days: _days,
        start: start,
        end: _forDays == null ? null : start.add(Duration(days: _forDays! - 1)),
      ),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add medicine')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Medicine name')),
          const SizedBox(height: 10),
          TextField(controller: _strength, decoration: const InputDecoration(labelText: 'Strength (e.g. 500 mg)')),
          const SizedBox(height: 10),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (e.g. after food)')),
          const SizedBox(height: 18),
          const Text('Times', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in [..._times]..sort())
              InputChip(label: Text(t.label), onDeleted: () => setState(() => _times.remove(t))),
            ActionChip(avatar: const Icon(WIcons.clock, size: 18), label: const Text('Add time'), onPressed: _addTime),
          ]),
          const SizedBox(height: 18),
          const Text('Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: const Text('Every day'),
              selected: _days.isEmpty,
              onSelected: (_) => setState(() => _days.clear()),
            ),
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(_dayNames[i]),
                selected: _days.contains(i + 1),
                onSelected: (v) => setState(() => v ? _days.add(i + 1) : _days.remove(i + 1)),
              ),
          ]),
          const SizedBox(height: 18),
          const Text('How long', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final (label, n) in const [('Ongoing', null), ('5 days', 5), ('7 days', 7), ('30 days', 30)])
              ChoiceChip(label: Text(label), selected: _forDays == n, onSelected: (_) => setState(() => _forDays = n)),
          ]),
          const SizedBox(height: 18),
          WCard(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              title: const Text('This matches the prescription', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Checked against the doctor\'s note. If the bill, strip or chemist say something different, ask the doctor first.'),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: W.sos))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Add to schedule')),
          const SizedBox(height: 10),
          const Text('Not medical advice. Follow your doctor.',
              textAlign: TextAlign.center, style: TextStyle(color: W.text2, fontSize: 12)),
        ]),
      );
}
