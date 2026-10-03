/// The two languages the app speaks.
enum AppLanguage {
  en('en', 'en-IN'),
  hi('hi', 'hi-IN');

  const AppLanguage(this.code, this.locale);

  /// Stored in preferences.
  final String code;

  /// Used for dictation and the voice.
  final String locale;

  static AppLanguage? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}
