import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// Puts the current [AppStrings] above every route.
///
/// It sits in `MaterialApp.builder`, not around `home`, so a pushed route can
/// still find it. The test harness mirrors that.
class L10n extends InheritedWidget {
  const L10n({super.key, required this.language, required super.child});

  final AppLanguage language;

  AppStrings get strings => AppStrings(language);

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<L10n>();
    return AppStrings(scope?.language ?? AppLanguage.en);
  }

  static AppLanguage languageOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10n>()?.language ??
      AppLanguage.en;

  @override
  bool updateShouldNotify(L10n oldWidget) => oldWidget.language != language;
}
