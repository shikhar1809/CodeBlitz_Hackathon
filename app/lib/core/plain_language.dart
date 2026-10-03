import '../domain/merge_engine.dart';
import '../domain/mention.dart';
import '../domain/sig.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';

/// Plain language that the parser reads back exactly. Used to pre-fill an
/// instruction a person is about to edit.
const english = AppStrings(AppLanguage.en);

/// A Sig, a source, a verdict — in words a patient reads without thinking.
abstract final class PlainLanguage {
  static String slot(DoseSlot s, AppStrings t) => switch (s) {
    DoseSlot.morning => t.morning,
    DoseSlot.afternoon => t.afternoon,
    DoseSlot.evening => t.evening,
    DoseSlot.night => t.night,
  };

  /// "Morning · Night · after food · for 30 days".
  static String describe(Sig sig, AppStrings t, {bool withUnits = true}) {
    final parts = <String>[];
    if (sig.sos) {
      parts.add(t.whenNeeded);
    } else if (sig.stat) {
      parts.add(t.onceNow);
    } else if (sig.slots.isEmpty) {
      parts.add(t.timingUnknown);
    } else {
      parts.addAll(sig.slots.map((s) => slot(s, t)));
    }
    if (sig.food == FoodTiming.before) parts.add(t.beforeFood);
    if (sig.food == FoodTiming.after) parts.add(t.afterFood);
    if (sig.everyNDays != null && sig.everyNDays! > 1) {
      parts.add(t.everyNDays(sig.everyNDays!));
    }
    if (sig.durationDays != null) parts.add(t.forDays(sig.durationDays!));
    if (withUnits && sig.unitsPerDose != 1) {
      parts.add(
        sig.unitsPerDose == .5
            ? t.halfTablet
            : t.tablets(_trim(sig.unitsPerDose)),
      );
    }
    return parts.join(' · ');
  }

  static String sourceLabel(SourceKind s, AppStrings t) => switch (s) {
    SourceKind.bill => t.sourceBill,
    SourceKind.prescription => t.sourcePrescription,
    SourceKind.doctor => t.sourceDoctor,
    SourceKind.chemist => t.sourceChemist,
    SourceKind.strip => t.sourceStrip,
  };

  /// Printed sources keep their capitals — TELMA 40, as on the bill. Spoken or
  /// handwritten ones read as they were said — Glycomet 500. Never translated.
  static String displayName(MergedMedicine m) {
    final printed = m.sources.any(
      (s) => s == SourceKind.bill || s == SourceKind.strip,
    );
    return printed ? m.name : titleCase(m.name);
  }

  static String titleCase(String name) => name
      .split(' ')
      .map(
        (w) => w.isEmpty || RegExp(r'^\d').hasMatch(w) || w.length <= 2
            ? w
            : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');

  /// The one line under a medicine's name that says how much to trust it.
  static String status(MergedMedicine m, AppStrings t) {
    if (m.conflicts.isNotEmpty) {
      return switch (m.conflicts.first.field) {
        ConflictField.notPrescribed => t.notPrescribed,
        ConflictField.strength => t.disagreeStrength,
        ConflictField.timing => t.disagreeTiming,
        ConflictField.food => t.disagreeFood,
        ConflictField.interval => t.disagreeInterval,
        ConflictField.asNeeded => t.disagreeAsNeeded,
      };
    }
    if (m.verdict == Verdict.green) return t.agreeTwoPlus;
    final r = m.reasons;
    if (r.contains(AmberReason.sameSourceTwice)) return t.listedTwice;
    if (r.contains(AmberReason.singleSource)) {
      final only = m.sources.single;
      if (only == SourceKind.doctor || only == SourceKind.chemist) {
        return t.onlySpoken;
      }
      if (only == SourceKind.prescription) return t.onlyOnPrescription;
      return t.onlyOneSource;
    }
    if (r.contains(AmberReason.noTiming)) return t.noTimingGiven;
    if (r.contains(AmberReason.uncertain)) return t.readerUnsure;
    return t.wordsToCheck;
  }

  static num _trim(double v) => v == v.roundToDouble() ? v.round() : v;
}
