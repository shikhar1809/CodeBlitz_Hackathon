import 'dart:convert';

/// A preset configures the one Winger engine for one job.
///
/// Presets may only use actions from an allowlist. Contacts always come from
/// the user, never from the preset, and `emergency` (112) is only allowed in
/// built-in presets. Bad files are rejected, never half-loaded.
enum Watch { continuous, scheduled }

enum Priority { safety, health, routine }

class PresetError implements Exception {
  final String message;
  const PresetError(this.message);
  @override
  String toString() => 'PresetError: $message';
}

class ActionSpec {
  /// One of [allowed].
  final String kind;

  /// Contact role for message_contacts / call_contact ("guardian", "family").
  final String? arg;
  const ActionSpec(this.kind, [this.arg]);

  static const allowed = {
    'notify',
    'speak',
    'checkin',
    'vibrate',
    'message_contacts',
    'call_contact',
    'emergency',
  };
  static const needsRole = {'message_contacts', 'call_contact'};
  static const roles = {'guardian', 'family', 'buddy'};

  factory ActionSpec.parse(String s) {
    final parts = s.split(':');
    if (parts.length > 2) throw PresetError('bad action "$s"');
    final kind = parts[0];
    final arg = parts.length == 2 ? parts[1] : null;
    if (!allowed.contains(kind)) throw PresetError('action "$kind" is not allowed');
    if (needsRole.contains(kind)) {
      if (arg == null || !roles.contains(arg)) {
        throw PresetError('"$kind" needs a contact role: ${roles.join(', ')}');
      }
    } else if (arg != null) {
      throw PresetError('"$kind" takes no argument');
    }
    return ActionSpec(kind, arg);
  }

  @override
  String toString() => arg == null ? kind : '$kind:$arg';
}

class LadderStep {
  final String id;

  /// Offset from the start of the watch (a dose's due time, a check-in).
  final Duration after;
  final List<ActionSpec> actions;
  const LadderStep(this.id, this.after, this.actions);

  bool has(String kind) => actions.any((a) => a.kind == kind);
}

/// "0m", "30s", "90m", "2h".
Duration parseDuration(String s) {
  final m = RegExp(r'^(\d{1,4})(s|m|h)$').firstMatch(s.trim());
  if (m == null) throw PresetError('bad duration "$s"');
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) {
    's' => Duration(seconds: n),
    'm' => Duration(minutes: n),
    _ => Duration(hours: n),
  };
}

class Preset {
  final String id;
  final int version;
  final String name;
  final String tagline;
  final Watch watch;
  final Priority priority;
  final String? module;
  final List<LadderStep> ladder;
  final String checkIn;
  final bool builtin;
  final bool comingSoon;
  final String footer;

  const Preset({
    required this.id,
    required this.version,
    required this.name,
    required this.tagline,
    required this.watch,
    required this.priority,
    required this.ladder,
    required this.checkIn,
    this.module,
    this.builtin = false,
    this.comingSoon = false,
    this.footer = '',
  });

  static const checkIns = {'call', 'overlay', 'notification_actions', 'per_item_confirm'};
  static const maxSteps = 8;

  bool get hasEmergency => ladder.any((s) => s.has('emergency'));

  /// Parses and validates. [builtin] is true only for presets shipped in the
  /// app; only those may declare an emergency (112) step.
  factory Preset.parse(String source, {bool builtin = false}) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw const PresetError('not valid JSON');
    }
    if (raw is! Map<String, dynamic>) throw const PresetError('must be an object');
    final j = raw;

    String str(String k, {bool required = true}) {
      final v = j[k];
      if (v == null && !required) return '';
      if (v is! String || v.trim().isEmpty) throw PresetError('"$k" must be a non-empty string');
      return v;
    }

    final id = str('id');
    if (!RegExp(r'^[a-z][a-z0-9_]{1,30}$').hasMatch(id)) throw PresetError('bad id "$id"');
    final version = j['version'];
    if (version is! int || version < 1) throw const PresetError('"version" must be a positive integer');

    final watch = Watch.values.where((w) => w.name == j['watch']).firstOrNull;
    if (watch == null) throw const PresetError('"watch" must be continuous or scheduled');
    final priority = Priority.values.where((p) => p.name == j['priority']).firstOrNull;
    if (priority == null) throw const PresetError('"priority" must be safety, health or routine');
    if (priority == Priority.safety && !builtin) {
      throw const PresetError('only built-in presets may have safety priority');
    }

    final checkIn = str('checkIn');
    if (!checkIns.contains(checkIn)) throw PresetError('bad checkIn "$checkIn"');

    final rawLadder = j['ladder'];
    if (rawLadder is! List || rawLadder.isEmpty) throw const PresetError('"ladder" must be a non-empty list');
    if (rawLadder.length > maxSteps) throw const PresetError('too many ladder steps');
    final steps = <LadderStep>[];
    final ids = <String>{};
    for (final s in rawLadder) {
      if (s is! Map) throw const PresetError('each ladder step must be an object');
      final sid = s['id'];
      if (sid is! String || sid.isEmpty || !ids.add(sid)) throw PresetError('bad or repeated step id "$sid"');
      final after = parseDuration('${s['after']}');
      final acts = s['actions'];
      if (acts is! List || acts.isEmpty) throw PresetError('step "$sid" needs actions');
      final actions = [for (final a in acts) ActionSpec.parse('$a')];
      if (!builtin && actions.any((a) => a.kind == 'emergency')) {
        throw const PresetError('only built-in presets may use "emergency"');
      }
      if (steps.isNotEmpty && after < steps.last.after) {
        throw PresetError('step "$sid" comes before the step above it');
      }
      steps.add(LadderStep(sid, after, actions));
    }

    final copy = j['copy'];
    return Preset(
      id: id,
      version: version,
      name: str('name'),
      tagline: str('tagline', required: false),
      watch: watch,
      priority: priority,
      module: j['module'] as String?,
      ladder: steps,
      checkIn: checkIn,
      builtin: builtin,
      comingSoon: j['comingSoon'] == true,
      footer: copy is Map && copy['footer'] is String ? copy['footer'] as String : '',
    );
  }
}
