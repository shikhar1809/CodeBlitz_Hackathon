import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/features/visit/capture_tools.dart';
import 'package:winger/features/visit/media_store.dart';
import 'package:winger/features/visit/visit.dart';
import 'package:winger/features/visit/visit_repository.dart';
import 'package:winger/features/visit/visit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

class FakePhotos extends PhotoCapture {
  int picks = 0;

  @override
  Future<XFile?> camera() async {
    picks++;
    return XFile('rx.jpg', name: 'rx.jpg');
  }

  @override
  Future<XFile?> gallery() => camera();
}

class FakeMedia implements MediaStore {
  FakeMedia({this.persistent = true});

  @override
  final bool persistent;

  final kept = <String>[];

  @override
  Future<String> keep(
    String visitId,
    XFile file, {
    required String name,
  }) async {
    final path = '/visits/$visitId/$name.jpg';
    kept.add(path);
    return path;
  }

  @override
  Future<void> deleteVisit(String visitId) async {}
}

void main() {
  late VisitRepository repo;
  late FakePhotos photos;
  late FakeMedia media;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await VisitRepository.load();
    photos = FakePhotos();
    media = FakeMedia();
  });

  Widget screen({required bool agree, bool persistent = true}) {
    media = FakeMedia(persistent: persistent);
    return themed(
      VisitScreen(
        repository: repo,
        media: media,
        photos: photos,
        consent: (_) async => agree,
        onBuildPlan: (_) {},
      ),
    );
  }

  Future<void> addPrescription(WidgetTester tester) async {
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
  }

  testWidgets('declining consent captures nothing', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(screen(agree: false));
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsNothing);
    expect(photos.picks, 0);
    expect(repo.loadDraft(), isNull);
  });

  testWidgets('a photo is saved to the draft the moment it lands', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(screen(agree: true));
    await addPrescription(tester);

    final draft = repo.loadDraft()!;
    expect(draft.consent, isTrue);
    expect(draft.photos.single.label, PhotoLabel.prescription);
    expect(draft.photos.single.path, media.kept.single);
  });

  testWidgets('build plan stays locked until the prescription is in', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(screen(agree: true));

    FilledButton button() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Build plan'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button().onPressed, isNull);
    expect(find.text('Add the prescription photo first.'), findsOneWidget);

    await addPrescription(tester);
    expect(button().onPressed, isNotNull);
  });

  testWidgets('a browser build says captures will not survive the tab', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(screen(agree: true, persistent: false));
    expect(find.textContaining('Browser preview'), findsOneWidget);
  });

  testWidgets('a visit killed mid-way resumes from the draft', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(screen(agree: true));
    await addPrescription(tester);

    // The app is killed and reopened.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen(agree: true));
    expect(find.text('Prescription photo'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
  });

  test('a visit round-trips through JSON', () {
    final v = Visit(id: 'v1', consent: true, doctorWords: 'telma subah')
      ..photos.add(
        VisitPhoto(path: '/a.jpg', label: PhotoLabel.bill, ocrText: 'TELMA'),
      );
    final back = Visit.fromJson(v.toJson());
    expect(back.id, 'v1');
    expect(back.doctorWords, 'telma subah');
    expect(back.photos.single.label, PhotoLabel.bill);
    expect(back.photos.single.ocrText, 'TELMA');
    expect(back.has(CaptureKind.doctorVoice), isTrue);
  });
}
