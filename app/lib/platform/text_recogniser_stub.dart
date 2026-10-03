import 'text_recogniser.dart';

TextRecogniser createTextRecogniser() => _UnsupportedRecogniser();

class _UnsupportedRecogniser implements TextRecogniser {
  @override
  bool get supported => false;

  @override
  Future<ReadResult> read(String path) async => const ReadResult.unsupported();

  @override
  Future<void> close() async {}
}
