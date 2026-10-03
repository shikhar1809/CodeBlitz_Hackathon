import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/app_prefs.dart';
import 'core/voice/voice_guide.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Which voice spoke, and how long it took, on every prompted screen. Set
  // here and nowhere else, so goldens (which run in debug mode) never show it.
  if (kDebugMode) VoiceGuide.showDebugStatus = true;
  final prefs = await AppPrefs.load();
  runApp(RapidRxApp(prefs: prefs));
}
