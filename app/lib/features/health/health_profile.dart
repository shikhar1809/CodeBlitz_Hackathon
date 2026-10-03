/// Validation for the health profile. Pure, so every rule is tested.
abstract final class HealthProfile {
  static const minAge = 1, maxAge = 120;
  static const minHeight = 50, maxHeight = 250;
  static const minWeight = 10, maxWeight = 300;

  /// Age is required.
  static HealthError? checkAge(String raw) {
    final v = int.tryParse(raw.trim());
    if (raw.trim().isEmpty) return HealthError.missing;
    if (v == null || v < minAge || v > maxAge) return HealthError.outOfRange;
    return null;
  }

  /// Height and weight are optional: empty is fine, nonsense is not.
  static HealthError? checkOptional(String raw, int min, int max) {
    if (raw.trim().isEmpty) return null;
    final v = int.tryParse(raw.trim());
    if (v == null || v < min || v > max) return HealthError.outOfRange;
    return null;
  }
}

enum HealthError { missing, outOfRange }
