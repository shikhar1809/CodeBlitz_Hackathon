/// The four times of day a dose can be due.
///
/// The patient sees सुबह / दोपहर / शाम / रात. The clock times behind them
/// (DoseClock) drive reminders only.
enum DoseSlot { morning, afternoon, evening, night }

enum FoodTiming { before, after, unspecified }

/// A prescription instruction, as structure.
///
/// Produced by code, not by a model: "1-0-1 p/c x 10 days" always becomes the
/// same Sig, and anyone can read why.
class Sig {
  const Sig({
    this.slots = const [],
    this.food = FoodTiming.unspecified,
    this.everyNDays,
    this.sos = false,
    this.stat = false,
    this.durationDays,
    this.unitsPerDose = 1,
    this.unresolved = const [],
  });

  /// Empty when nobody said when. That is not "never" — it is "unknown".
  final List<DoseSlot> slots;
  final FoodTiming food;

  /// 2 for alternate days. Null for every day.
  final int? everyNDays;

  /// As needed. No slots and no alarm, ever — an alarm would invent a time.
  final bool sos;

  /// A single dose, now.
  final bool stat;
  final int? durationDays;

  /// 1, 2, or 0.5 for half a tablet.
  final double unitsPerDose;

  /// Words the parser could not place. Non-empty means a person must look.
  final List<String> unresolved;

  static const empty = Sig();

  bool get hasTiming => slots.isNotEmpty || sos || stat;
  bool get isClear => unresolved.isEmpty;

  Sig copyWith({
    List<DoseSlot>? slots,
    FoodTiming? food,
    int? everyNDays,
    bool clearEveryNDays = false,
    bool? sos,
    bool? stat,
    int? durationDays,
    bool clearDuration = false,
    double? unitsPerDose,
    List<String>? unresolved,
  }) => Sig(
    slots: slots ?? this.slots,
    food: food ?? this.food,
    everyNDays: clearEveryNDays ? null : everyNDays ?? this.everyNDays,
    sos: sos ?? this.sos,
    stat: stat ?? this.stat,
    durationDays: clearDuration ? null : durationDays ?? this.durationDays,
    unitsPerDose: unitsPerDose ?? this.unitsPerDose,
    unresolved: unresolved ?? this.unresolved,
  );

  /// Fill what this Sig does not know from [other]; never overwrite.
  ///
  /// An as-needed medicine never borrows slots: that would invent an alarm.
  Sig fillFrom(Sig other) => Sig(
    slots: slots.isNotEmpty || sos ? slots : other.slots,
    food: food != FoodTiming.unspecified ? food : other.food,
    everyNDays: everyNDays ?? other.everyNDays,
    sos: sos || (slots.isEmpty && other.sos),
    stat: stat || other.stat,
    durationDays: durationDays ?? other.durationDays,
    unitsPerDose: unitsPerDose != 1 ? unitsPerDose : other.unitsPerDose,
    unresolved: [...unresolved, ...other.unresolved],
  );

  Map<String, Object?> toJson() => {
    'slots': [for (final s in slots) s.name],
    'food': food.name,
    if (everyNDays != null) 'everyNDays': everyNDays,
    if (sos) 'sos': true,
    if (stat) 'stat': true,
    if (durationDays != null) 'durationDays': durationDays,
    'unitsPerDose': unitsPerDose,
    if (unresolved.isNotEmpty) 'unresolved': unresolved,
  };

  factory Sig.fromJson(Map<String, Object?> j) => Sig(
    slots: [
      for (final s in (j['slots'] as List? ?? const []))
        DoseSlot.values.byName(s as String),
    ],
    food: FoodTiming.values.byName(j['food'] as String? ?? 'unspecified'),
    everyNDays: j['everyNDays'] as int?,
    sos: j['sos'] as bool? ?? false,
    stat: j['stat'] as bool? ?? false,
    durationDays: j['durationDays'] as int?,
    unitsPerDose: (j['unitsPerDose'] as num?)?.toDouble() ?? 1,
    unresolved: [
      for (final u in (j['unresolved'] as List? ?? const [])) u as String,
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is Sig &&
      _sameList(other.slots, slots) &&
      other.food == food &&
      other.everyNDays == everyNDays &&
      other.sos == sos &&
      other.stat == stat &&
      other.durationDays == durationDays &&
      other.unitsPerDose == unitsPerDose &&
      _sameList(other.unresolved, unresolved);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(slots),
    food,
    everyNDays,
    sos,
    stat,
    durationDays,
    unitsPerDose,
    Object.hashAll(unresolved),
  );

  @override
  String toString() => 'Sig(${toJson()})';
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
