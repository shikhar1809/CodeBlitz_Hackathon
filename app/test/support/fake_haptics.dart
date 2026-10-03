import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/feedback/haptics.dart';

/// Records every buzz instead of running the motor. Installed for one test and
/// removed afterwards, with the global switch put back on.
class FakeHaptics {
  FakeHaptics._();

  final List<HapticKind> calls = [];

  static FakeHaptics install() {
    final fake = FakeHaptics._();
    Haptics.debugOverride = fake.calls.add;
    addTearDown(() {
      Haptics.debugOverride = null;
      Haptics.enabled = true;
    });
    return fake;
  }
}
