import 'gallery_scanner.dart';

GalleryScanner createGalleryScanner() => _Unsupported();

class _Unsupported implements GalleryScanner {
  @override
  Future<ScanOutcome> recent({
    Duration within = const Duration(days: 7),
    int limit = 12,
  }) async => const ScanOutcome.unsupported();
}
