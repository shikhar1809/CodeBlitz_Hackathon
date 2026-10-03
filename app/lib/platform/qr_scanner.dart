import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'qr_scanner_stub.dart'
    if (dart.library.io) 'qr_scanner_io.dart'
    as platform;

/// Why the camera view is not scanning.
enum ScanProblem {
  /// The person said no to the camera, or turned it off in Settings.
  permissionDenied,

  /// This device or build has no scanner: the web, Windows, the test runner.
  unsupported,

  /// The camera would not start.
  failed,
}

/// Scan a QR code with the camera. `mobile_scanner` on the phone; everywhere
/// else an honest "this device cannot scan", and the screen offers the typed
/// code instead. It never pretends a scan happened.
abstract class QrScanner {
  factory QrScanner() => platform.createQrScanner();

  bool get supported;

  /// The live camera view. [onCode] gets each QR's text; [problem] builds
  /// what to show instead of the camera when it cannot scan.
  Widget view({
    required ValueChanged<String> onCode,
    required Widget Function(ScanProblem) problem,
  });

  /// Whether the torch is on, for the toggle's icon.
  ValueListenable<bool> get torchOn;

  Future<void> toggleTorch();

  /// Start the camera again, after the person allowed it in Settings.
  Future<void> retry();

  Future<void> dispose();
}
