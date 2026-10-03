import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'text_recogniser.dart';

TextRecogniser createTextRecogniser() => Platform.isAndroid || Platform.isIOS
    ? _MlKitRecogniser()
    : _DesktopRecogniser();

/// ML Kit on the phone. Printed bills read here at over 99%, with no network,
/// no key and no quota — which is why the bill decides a medicine's identity.
class _MlKitRecogniser implements TextRecogniser {
  // Built on first use: a recogniser touches a platform channel.
  TextRecognizer? _latin;
  TextRecognizer? _devanagari;

  @override
  bool get supported => true;

  @override
  Future<ReadResult> read(String path) async {
    final image = InputImage.fromFilePath(path);
    _latin ??= TextRecognizer(script: TextRecognitionScript.latin);
    _devanagari ??= TextRecognizer(script: TextRecognitionScript.devanagiri);
    final latin = await _latin!.processImage(image);
    var text = latin.text;
    // A Hindi note on the prescription: read it as well, and keep both.
    final hindi = await _devanagari!.processImage(image);
    if (RegExp('[ऀ-ॿ]').hasMatch(hindi.text)) {
      text = '$text\n${hindi.text}';
    }
    return ReadResult.text(text);
  }

  @override
  Future<void> close() async {
    await _latin?.close();
    await _devanagari?.close();
  }
}

/// Windows and the test runner have no ML Kit. Say so.
class _DesktopRecogniser implements TextRecogniser {
  @override
  bool get supported => false;

  @override
  Future<ReadResult> read(String path) async => const ReadResult.unsupported();

  @override
  Future<void> close() async {}
}
