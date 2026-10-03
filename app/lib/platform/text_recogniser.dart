import 'text_recogniser_stub.dart'
    if (dart.library.io) 'text_recogniser_io.dart'
    as platform;

/// What reading a photo produced.
class ReadResult {
  const ReadResult.text(this.text) : unsupported = false;
  const ReadResult.unsupported() : text = '', unsupported = true;

  final String text;

  /// This build cannot read photos at all. Never the same as "the photo was
  /// blank" — a silent empty result would hide the difference, and that is
  /// the worst failure this product can have.
  final bool unsupported;
}

/// On-device OCR. ML Kit, Latin and Devanagari, on the phone; an honest
/// "cannot read photos here" everywhere else.
abstract class TextRecogniser {
  factory TextRecogniser() => platform.createTextRecogniser();

  bool get supported;

  Future<ReadResult> read(String path);

  Future<void> close();
}
