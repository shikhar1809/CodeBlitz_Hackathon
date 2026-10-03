import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_scanner.dart';
import 'qr_scanner_stub.dart';

QrScanner createQrScanner() => Platform.isAndroid || Platform.isIOS
    ? _MobileQrScanner()
    // Windows and the test runner: mobile_scanner has no scanner there.
    : UnsupportedQrScanner();

class _MobileQrScanner implements QrScanner {
  // Built on first use: the controller talks to a platform channel.
  MobileScannerController? _controller;
  MobileScannerController get _c => _controller ??= MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final _torch = ValueNotifier(false);

  @override
  bool get supported => true;

  @override
  Widget view({
    required ValueChanged<String> onCode,
    required Widget Function(ScanProblem) problem,
  }) => MobileScanner(
    controller: _c,
    onDetect: (capture) {
      for (final b in capture.barcodes) {
        final raw = b.rawValue;
        if (raw != null && raw.isNotEmpty) {
          onCode(raw);
          return;
        }
      }
    },
    // mobile_scanner asks for the camera itself when it starts; a "no"
    // arrives here.
    errorBuilder: (context, error) => problem(switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => ScanProblem.permissionDenied,
      MobileScannerErrorCode.unsupported => ScanProblem.unsupported,
      _ => ScanProblem.failed,
    }),
  );

  @override
  ValueListenable<bool> get torchOn => _torch;

  @override
  Future<void> toggleTorch() async {
    try {
      await _c.toggleTorch();
      _torch.value = _c.value.torchState == TorchState.on;
    } catch (_) {
      // No torch on this camera: the icon simply stays off.
      _torch.value = false;
    }
  }

  @override
  Future<void> retry() async {
    try {
      await _c.stop();
      await _c.start();
    } catch (_) {
      // The error builder shows why.
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _torch.dispose();
  }
}
