import 'gallery_scanner_stub.dart'
    if (dart.library.io) 'gallery_scanner_io.dart'
    as platform;

enum ScanStatus { found, nothing, denied, unsupported }

/// What a scan of recent photos turned up.
class ScanOutcome {
  const ScanOutcome(this.status, [this.paths = const []]);

  const ScanOutcome.unsupported() : this(ScanStatus.unsupported);

  final ScanStatus status;
  final List<String> paths;
}

/// Looks through the last few days of photos for anything that might be a
/// prescription, a bill or a strip — because the person has usually already
/// taken the photo, at the counter, and cannot find it again.
///
/// It only suggests. Nothing it finds enters the visit until a person ticks
/// it and leaves the step. Where it cannot run, it says why.
abstract class GalleryScanner {
  factory GalleryScanner() => platform.createGalleryScanner();

  Future<ScanOutcome> recent({
    Duration within = const Duration(days: 7),
    int limit = 12,
  });
}
