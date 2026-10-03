import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loaded by `flutter test` before any test file in this directory.
///
/// Golden screenshots are the primary UI check, so they have to render the real
/// fonts. By default the test runner draws every glyph as a box, which makes a
/// Hindi screen and an English screen look identical — useless as a spec.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();
  await _loadMaterialIcons();
  await testMain();
}

Future<void> _loadAppFonts() async {
  const families = <String, List<String>>{
    'NotoSans': [
      'NotoSans-Regular.ttf',
      'NotoSans-SemiBold.ttf',
      'NotoSans-Bold.ttf',
    ],
    'NotoSansDevanagari': [
      'NotoSansDevanagari-Regular.ttf',
      'NotoSansDevanagari-SemiBold.ttf',
      'NotoSansDevanagari-Bold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(_bytes('assets/fonts/$file'));
    }
    await loader.load();
  }
}

/// Icons ship with the Flutter SDK, not with the app, so the test runner has
/// no copy of them. Load the font straight out of the SDK cache, or every icon
/// in every golden is an empty box.
Future<void> _loadMaterialIcons() async {
  final root = _flutterRoot();
  if (root == null) return;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

String? _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // `flutter test` runs the tester from inside the SDK cache.
  final exe = Platform.resolvedExecutable.replaceAll('\\', '/');
  final at = exe.indexOf('/bin/cache/');
  return at > 0 ? exe.substring(0, at) : null;
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(File(path).readAsBytesSync());
