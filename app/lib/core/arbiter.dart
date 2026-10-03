import 'presets.dart';

/// One pending check-in that wants the screen.
class CheckInRequest {
  final String id;
  final Priority priority;
  final DateTime at;
  const CheckInRequest(this.id, this.priority, this.at);
}

/// Safety outranks everything: only one check-in overlay at a time, highest
/// priority first (safety > health > routine), oldest first within a level.
/// While a safety alert is active, lower-priority contact messages are held
/// back and released afterwards.
class Arbiter {
  final List<CheckInRequest> _pending = [];

  void add(CheckInRequest r) {
    if (_pending.any((p) => p.id == r.id)) return;
    _pending.add(r);
  }

  void remove(String id) => _pending.removeWhere((p) => p.id == id);

  bool contains(String id) => _pending.any((p) => p.id == id);

  /// The check-in that owns the screen now, or null.
  CheckInRequest? get current {
    if (_pending.isEmpty) return null;
    final sorted = [..._pending]
      ..sort((a, b) {
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : a.at.compareTo(b.at);
      });
    return sorted.first;
  }

  /// Waiting behind the current one (shown as notifications instead).
  List<CheckInRequest> get queued {
    final c = current;
    return _pending.where((p) => p != c).toList();
  }

  /// Should a lower-priority action wait? True for anything below safety
  /// while a safety check-in is pending.
  bool holds(Priority p) =>
      p != Priority.safety && _pending.any((x) => x.priority == Priority.safety);
}
