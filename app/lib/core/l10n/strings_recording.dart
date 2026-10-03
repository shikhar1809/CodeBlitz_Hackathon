import 'app_strings.dart';

/// "Did it record?" — the words around every microphone in the app.
extension RecordingStrings on AppStrings {
  String get recordingLive => pick('Recording', 'रिकॉर्ड हो रहा है');
  String get listeningLive => pick('Listening', 'सुन रहे हैं');

  /// `Recorded 0:42`, or without a length when it is not known. The tick is
  /// an icon beside it: `✓` is in neither bundled Noto face, and an older
  /// phone's fallback font may not have it either.
  String recordedFor(String? length) => pick(
    ['Recorded', ?length].join(' '),
    ['रिकॉर्ड हो गया', ?length].join(' '),
  );

  String get nothingHeard =>
      pick('Nothing heard, try again', 'कुछ सुनाई नहीं दिया, फिर से बोलें');
  String get tooShortWhy => pick(
    'That was under a second. Hold on a little longer.',
    'यह एक सेकंड से कम था। थोड़ा ज़्यादा देर बोलें।',
  );
  String get silentWhy => pick(
    'The microphone heard no voice. Speak closer to the phone.',
    'माइक्रोफ़ोन को कोई आवाज़ नहीं मिली। फ़ोन के पास बोलें।',
  );
  String get tryAgain => pick('Try again', 'फिर से कोशिश करें');
  String get playRecording => pick('Play', 'सुनें');
  String get recordAgain => pick('Record again', 'फिर से रिकॉर्ड करें');
  String get deleteRecording => pick('Delete', 'हटाएँ');
  String get soundLevel => pick('Sound level', 'आवाज़ का स्तर');
  String get cannotPlay => pick(
    'The recording could not be played here.',
    'रिकॉर्डिंग यहाँ नहीं चल पाई।',
  );
}
