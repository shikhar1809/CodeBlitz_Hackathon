import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/content_gate.dart';

void main() {
  group('photos', () {
    test('a pharmacy bill is a bill', () {
      final v = ContentGate.judgeText('''
SHREE GANESH MEDICAL STORE  GSTIN 09ABCDE1234F1Z5
1 TELMA 40 TAB  30 NOS  255.00
2 GLYCOMET 500 SR 1x15  45.50
TOTAL 307.50''');
      expect(v.kind, ContentKind.bill);
      expect(v.evidence, contains('tab'));
    });

    test('a prescription is a prescription', () {
      final v = ContentGate.judgeText('''
Dr. A. K. Verma MBBS
Rx  Tab Telma 40  1-0-1  p/c
    Tab Pan 40 OD a/c''');
      expect(v.kind, ContentKind.prescription);
      expect(v.evidence, containsAll(['tab', '1-0-1']));
    });

    test('a strip is a strip', () {
      final v = ContentGate.judgeText('''
TELMA 40
Telmisartan Tablets IP 40 mg
Each tablet contains Telmisartan IP 40 mg
Mfg. Lic. No  Batch No  Exp. 08/2027
Store below 30C, protect from light''');
      expect(v.kind, ContentKind.medicineStrip);
    });

    test('tuning bug: a café receipt is not medical', () {
      final v = ContentGate.judgeText('''
BLUE TOKAI COFFEE
Cappuccino 1  220.00
Croissant 1  180.00
TOTAL 400.00   GST 20.00''');
      expect(v.kind, ContentKind.notMedical);
    });

    test('tuning bug: "beach 2024" is not medical', () {
      expect(ContentGate.judgeText('beach 2024').kind, ContentKind.notMedical);
    });

    test('a brand and a number only support, they never establish', () {
      expect(ContentGate.judgeText('Telma 40').kind, ContentKind.notMedical);
    });

    test('an empty photo is not medical, and says nothing', () {
      final v = ContentGate.judgeText('');
      expect(v.kind, ContentKind.notMedical);
      expect(v.evidence, isEmpty);
    });
  });

  group('speech', () {
    test('the bar is lower: one short sentence passes', () {
      expect(
        ContentGate.judgeSpeech('Telma forty, one in the morning').medical,
        isTrue,
      );
    });

    test('Hinglish passes', () {
      expect(
        ContentGate.judgeSpeech('Glycomet 500 subah aur raat').medical,
        isTrue,
      );
    });

    test('shorthand alone passes', () {
      expect(ContentGate.judgeSpeech('Pan 40 OD').medical, isTrue);
    });

    test('tuning bug: a cricket conversation is not medical', () {
      expect(
        ContentGate.judgeSpeech(
          'We batted till night and he scored forty, what a match',
        ).medical,
        isFalse,
      );
    });

    test('Hindi: a time of day with a strength', () {
      expect(ContentGate.judgeSpeech('Telma 40 subah').medical, isTrue);
    });

    test('small talk is not medical', () {
      expect(
        ContentGate.judgeSpeech('Namaste, kaise hain aap').medical,
        isFalse,
      );
    });
  });
}
