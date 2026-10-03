import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/app_state.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/l10n.dart';
import 'package:winger/core/storage/app_prefs.dart';
import 'package:winger/core/theme/app_theme.dart';
import 'package:winger/core/widgets/rx_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every golden is a real phone: 412 x 892 logical pixels.
const phoneSize = Size(412, 892);

/// Size the test surface to a phone, and put it back afterwards.
void usePhoneSurface(WidgetTester tester, {Size size = phoneSize}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A fresh [AppState] over empty mock preferences.
Future<AppState> freshState({
  AppLanguage language = AppLanguage.en,
  Map<String, Object> values = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'app_language': language.code,
    ...values,
  });
  return AppState(await AppPrefs.load());
}

/// Wrap a screen the way the app does: scopes in `MaterialApp.builder`, so a
/// pushed route finds them exactly as it would on the phone.
Widget themed(
  Widget child, {
  AppLanguage language = AppLanguage.en,
  AppState? state,
}) {
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: (context, inner) => L10n(language: language, child: inner!),
    home: child,
  );
  if (state != null) app = AppScope(state: state, child: app);
  return app;
}

/// Asset images decode on a real thread, which fake async never gives them.
/// Decode the logo up front so it is in the golden rather than a blank square.
Future<void> precacheLogo(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    await precacheImage(const AssetImage(RxLogo.asset), context);
  });
  await tester.pump();
}
