import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_hub.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import 'booking_progress_screen.dart';
import 'hub_client.dart';
import 'hub_connect_screen.dart';

/// The demo clinic's booking site. Fictional: built for the hackathon, so
/// the Hub's agent has a real form to fill without touching a real hospital.
const demoClinicUrl = 'https://wingercodeblitz.web.app/clinic/';

/// The clinic's own department names. They go to the site in English; the
/// screen shows them in the app's language.
const clinicDepartments = [
  'General Medicine',
  'Diabetes & Endocrinology',
  'Cardiology',
  'Orthopaedics',
  'Eye Care',
  'ENT',
];

/// What to book, for whom — then hand it to the Hub.
///
/// Only what the clinic's form needs. The patient's name, number and age come
/// from the phone; gender is asked because the phone has never needed it.
/// Nothing is booked from here: the Hub asks again, with the filled form in
/// front of the person, before it submits.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({
    super.key,
    required this.prefs,
    this.patientName,
    this.patientPhone,
    this.patientAge,
    this.httpClient,
    this.today,
  });

  final AppPrefs prefs;
  final String? patientName;
  final String? patientPhone;
  final int? patientAge;

  /// For tests. The app uses a real client.
  final http.Client? httpClient;

  /// For tests: the first day the date picker offers.
  final DateTime? today;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _url = TextEditingController(text: demoClinicUrl);
  late final _name = TextEditingController(text: widget.patientName ?? '');
  late final _phone = TextEditingController(text: widget.patientPhone ?? '');
  late final _age = TextEditingController(
    text: widget.patientAge?.toString() ?? '',
  );
  final _doctor = TextEditingController();
  final _reason = TextEditingController();

  String _department = clinicDepartments.first;
  String? _gender;
  DateTime? _date;
  TimeOfDayChoice _time = TimeOfDayChoice.any;

  String? _urlError;
  String? _nameError;
  String? _genderError;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_url, _name, _phone, _age, _doctor, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = widget.today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _validate(AppStrings s) {
    final uri = Uri.tryParse(_url.text.trim());
    final urlOk =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    setState(() {
      _urlError = urlOk ? null : s.clinicWebsiteInvalid;
      _nameError = _name.text.trim().isEmpty ? s.patientNameMissing : null;
      _genderError = _gender == null ? s.genderMissing : null;
    });
    return _urlError == null && _nameError == null && _genderError == null;
  }

  /// Not paired (or unpaired since): pair first, then carry on.
  Future<HubClient?> _client() async {
    var client = HubClient.fromPrefs(widget.prefs, client: widget.httpClient);
    if (client != null) return client;
    final paired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HubConnectScreen(
          prefs: widget.prefs,
          httpClient: widget.httpClient,
          popWhenConnected: true,
        ),
      ),
    );
    if (paired != true) return null;
    return HubClient.fromPrefs(widget.prefs, client: widget.httpClient);
  }

  Future<void> _submit() async {
    final s = L10n.of(context);
    if (!_validate(s)) {
      Haptics.error();
      return;
    }
    Haptics.tap();
    final client = await _client();
    if (client == null || !mounted) return;
    final request = BookingRequest(
      url: _url.text.trim(),
      patientName: _name.text.trim(),
      patientAge: int.tryParse(_age.text.trim()),
      patientGender: _gender!,
      patientPhone: _phone.text.trim(),
      department: _department,
      doctor: _doctor.text.trim(),
      date: _date,
      timeOfDay: _time,
      reason: _reason.text.trim(),
    );
    setState(() => _busy = true);
    try {
      final id = await client.startBooking(request);
      if (!mounted) return;
      setState(() => _busy = false);
      // "Try again" on a failed booking comes back here, form intact.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingProgressScreen(client: client, jobId: id),
        ),
      );
    } on HubException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      Haptics.error();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.hubProblem(e.problem))));
    } finally {
      if (widget.httpClient == null) client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return VoicePrompt(
      text: '${s.bookVisit}. ${s.bookWhy}',
      child: Scaffold(
        appBar: AppBar(title: Text(s.bookVisit)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                s.bookWhy,
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // ── Who ──────────────────────────────────────────────────────
              _Label(s.patientDetails),
              BigTextField(
                controller: _name,
                hint: s.patientNameHint,
                errorText: _nameError,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: BigTextField(
                      controller: _age,
                      hint: s.ageHint,
                      digits: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: BigTextField(
                      controller: _phone,
                      hint: s.phoneHint,
                      digits: 10,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Label(s.gender),
              _ChoiceGrid<String>(
                columns: 3,
                options: const ['Female', 'Male', 'Other'],
                label: (g) => switch (g) {
                  'Female' => s.female,
                  'Male' => s.male,
                  _ => s.otherGender,
                },
                selected: _gender,
                onChanged: (g) => setState(() {
                  _gender = g;
                  _genderError = null;
                }),
              ),
              if (_genderError != null) _ErrorLine(_genderError!),
              const SizedBox(height: 24),

              // ── What ─────────────────────────────────────────────────────
              _Label(s.department),
              DropdownButtonFormField<String>(
                initialValue: _department,
                isExpanded: true,
                itemHeight: AppTheme.tapTarget,
                style: text.bodyLarge,
                iconSize: 32,
                items: [
                  for (final d in clinicDepartments)
                    DropdownMenuItem(
                      value: d,
                      child: Text(
                        s.departmentLabel(d),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (d) {
                  if (d != null) setState(() => _department = d);
                },
              ),
              const SizedBox(height: 16),
              _Label(s.doctorName, optional: s.optional),
              BigTextField(controller: _doctor, hint: s.doctorName),
              const SizedBox(height: 24),

              // ── When ─────────────────────────────────────────────────────
              _Label(s.preferredDay, optional: s.optional),
              Pressable(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    _date == null ? s.chooseDay : s.shortDate(_date!),
                  ),
                  onPressed: _pickDate,
                ),
              ),
              if (_date != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _date = null),
                    child: Text(s.anyDay),
                  ),
                ),
              const SizedBox(height: 16),
              _Label(s.timeOfDayQuestion),
              _ChoiceGrid<TimeOfDayChoice>(
                columns: 2,
                options: TimeOfDayChoice.values,
                label: s.timeOfDayLabel,
                selected: _time,
                onChanged: (t) => setState(() => _time = t),
              ),
              const SizedBox(height: 24),

              // ── Why, and where ───────────────────────────────────────────
              _Label(s.visitReason, optional: s.optional),
              BigTextField(controller: _reason, hint: s.visitReasonHint),
              const SizedBox(height: 16),
              _Label(s.clinicWebsite),
              BigTextField(
                controller: _url,
                hint: demoClinicUrl,
                keyboardType: TextInputType.url,
                errorText: _urlError,
              ),
              const SizedBox(height: 28),
              Pressable(
                enabled: !_busy,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.event_available_rounded),
                  label: Text(_busy ? s.sendingToHub : s.askHubToBook),
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional});

  final String text;

  /// The "Optional" tag's word, when the field is optional.
  final String? optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (optional != null) ...[
            const SizedBox(width: 10),
            OptionalTag(text: optional!),
          ],
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, color: AppColors.red),
    ),
  );
}

/// Big either/or buttons in a grid: one tap picks, the pick is amber.
class _ChoiceGrid<T> extends StatelessWidget {
  const _ChoiceGrid({
    required this.columns,
    required this.options,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final int columns;
  final List<T> options;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = (options.length / columns).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 10),
                Expanded(
                  child: r * columns + c < options.length
                      ? _choice(context, options[r * columns + c])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, T option) {
    final on = option == selected;
    return Semantics(
      button: true,
      selected: on,
      child: Pressable(
        child: Material(
          color: on ? AppColors.amberSoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(
              color: on ? AppColors.amber : AppColors.hairline,
              width: on ? 3 : 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: Haptics.on(() => onChanged(option)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTheme.tapTarget),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label(option),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
