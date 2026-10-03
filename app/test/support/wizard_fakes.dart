import 'package:cross_file/cross_file.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:winger/features/visit/capture_tools.dart';
import 'package:winger/features/visit/media_store.dart';
import 'package:winger/features/visit/visit.dart';
import 'package:winger/features/visit/visit_repository.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/platform/gallery_scanner.dart';
import 'package:winger/platform/text_recogniser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canned OCR, keyed by file name, that counts every read.
class FakeRecogniser implements TextRecogniser {
  FakeRecogniser(this.texts, {this.supported = true});

  final Map<String, String> texts;
  final List<String> reads = [];

  @override
  final bool supported;

  @override
  Future<ReadResult> read(String path) async {
    reads.add(path);
    if (!supported) return const ReadResult.unsupported();
    return ReadResult.text(texts[path.split('/').last] ?? '');
  }

  @override
  Future<void> close() async {}
}

class FakeMedia implements MediaStore {
  @override
  bool get persistent => true;

  @override
  Future<String> keep(
    String visitId,
    XFile file, {
    required String name,
  }) async => file.path;

  @override
  Future<void> deleteVisit(String visitId) async {}
}

class FakePhotos extends PhotoCapture {
  FakePhotos(this.next);

  List<String> next;

  @override
  Future<XFile?> camera() async => next.isEmpty ? null : XFile(next.first);

  @override
  Future<List<XFile>> galleryMany() async => [for (final p in next) XFile(p)];
}

class FakeScanner implements GalleryScanner {
  FakeScanner(this.outcome);

  final ScanOutcome outcome;

  @override
  Future<ScanOutcome> recent({
    Duration within = const Duration(days: 7),
    int limit = 12,
  }) async => outcome;
}

const billText = '''
SHREE GANESH MEDICAL STORE  GSTIN 09ABCDE1234F1Z5
1 TELMA 40 TAB          30 NOS   255.00
2 GLYCOMET 500 SR       1x15      45.50
TOTAL 300.50''';

const rxText = '''
Dr. A. K. Verma  MBBS
Rx
1) Tab Telma 40   1-0-1  p/c
2) Tab Glycomet 500 SR   1-0-1  x 30 days''';

const holidayText = 'beach 2024  Goa trip';

final today = DateTime(2026, 9, 26, 9, 30);

Future<VisitWizardController> wizard({
  Map<String, String>? ocr,
  bool ocrSupported = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = await VisitRepository.load();
  final store = await MedicineStore.load();
  return VisitWizardController(
    visit: Visit(id: 'v1', consent: true, createdAt: today),
    repository: repo,
    store: store,
    media: FakeMedia(),
    recogniser: FakeRecogniser(
      ocr ?? {'bill.jpg': billText, 'rx.jpg': rxText, 'beach.jpg': holidayText},
      supported: ocrSupported,
    ),
    clock: () => today,
  );
}
