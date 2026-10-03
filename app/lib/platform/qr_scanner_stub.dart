import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'qr_scanner.dart';

QrScanner createQrScanner() => UnsupportedQrScanner();

/// The web build (and anything else with no scanner): nothing to scan with,
/// and it says so. The screen offers the typed code.
class UnsupportedQrScanner implements QrScanner {
  final _torch = ValueNotifier(false);

  @override
  bool get supported => false;

  @override
  Widget view({
    required ValueChanged<String> onCode,
    required Widget Function(ScanProblem) problem,
  }) => problem(ScanProblem.unsupported);

  @override
  ValueListenable<bool> get torchOn => _torch;

  @override
  Future<void> toggleTorch() async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> dispose() async => _torch.dispose();
}
