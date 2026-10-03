import 'package:flutter/widgets.dart';

import 'l10n/app_language.dart';
import '../features/sync/sync_service.dart';
import 'storage/app_prefs.dart';

/// The few app-wide choices every screen can see: language, voice and role.
///
/// No state-management package (ADR-7): one [ChangeNotifier] and one inherited
/// scope are enough for three values, and there is nothing to learn on the day.
class AppState extends ChangeNotifier {
  AppState(this.prefs)
    : _language = prefs.language ?? AppLanguage.en,
      _voiceHelp = prefs.voiceHelp ?? false,
      _role = prefs.role;

  final AppPrefs prefs;

  /// Offline save and sync. Null in tests that do not need it.
  SyncService? sync;

  AppLanguage _language;
  bool _voiceHelp;
  AppRole? _role;

  AppLanguage get language => _language;
  bool get voiceHelp => _voiceHelp;
  AppRole? get role => _role;

  Future<void> setLanguage(AppLanguage l) async {
    _language = l;
    notifyListeners();
    await prefs.setLanguage(l);
  }

  Future<void> toggleLanguage() => setLanguage(
    _language == AppLanguage.en ? AppLanguage.hi : AppLanguage.en,
  );

  Future<void> setVoiceHelp(bool on) async {
    _voiceHelp = on;
    notifyListeners();
    await prefs.setVoiceHelp(on);
  }

  Future<void> setRole(AppRole? role) async {
    _role = role;
    notifyListeners();
    if (role != null) await prefs.setRole(role);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
}
