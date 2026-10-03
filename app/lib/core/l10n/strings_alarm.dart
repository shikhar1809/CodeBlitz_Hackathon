import '../../domain/medicine_form.dart';
import 'app_strings.dart';

/// The dose alarm, and the demo tools that fire it.
extension AlarmStrings on AppStrings {
  String get alarmTitle => pick('Time for your medicine', 'दवाई का समय');
  String get alarmQuestion => pick('Did you take it?', 'क्या आपने दवाई ले ली?');
  String get alarmTaken => pick('Yes, taken', 'हाँ, ले ली');
  String get alarmLater => pick('No / Later', 'नहीं / बाद में');
  String get alarmLaterNote => pick(
    'Not saved. The dose is still due.',
    'सेव नहीं हुआ। दवाई अभी बाकी है।',
  );
  String get alarmDemoBanner => pick(
    'Demo — nothing on this screen is saved',
    'डेमो — इस स्क्रीन से कुछ सेव नहीं होगा',
  );
  String get alarmDemoDone => pick(
    'Demo finished. Nothing was saved.',
    'डेमो पूरा हुआ। कुछ सेव नहीं हुआ।',
  );
  String get alarmOneTablet => pick('one tablet', 'एक गोली');
  String get alarmPressYesOrNo => pick(
    'Press the green button if you have taken it.',
    'ले ली हो तो हरा बटन दबाइए।',
  );

  String formName(MedicineForm f) => switch (f) {
    MedicineForm.tablet => pick('Tablet', 'गोली'),
    MedicineForm.capsule => pick('Capsule', 'कैप्सूल'),
    MedicineForm.syrup => pick('Syrup', 'सिरप'),
    MedicineForm.drops => pick('Drops', 'ड्रॉप्स'),
    MedicineForm.injection => pick('Injection', 'इंजेक्शन'),
    MedicineForm.cream => pick('Cream', 'क्रीम'),
  };

  // ── Demo tools (DevFlags.demoTools) ────────────────────────────────────
  String get demoSection => pick('Demo', 'डेमो');
  String get doseDemo => pick('Dose demo', 'दवाई अलार्म डेमो');
  String get doseDemoNow => pick('Show the alarm now', 'अलार्म अभी दिखाएँ');
  String get doseDemoRing => pick('Ring in 15 seconds', '15 सेकंड में बजाएँ');
  String get doseDemoRingWhy => pick(
    'Then lock the phone and wait: the screen wakes by itself.',
    'फिर फ़ोन लॉक करके रुकिए: स्क्रीन अपने आप जागेगी।',
  );
  String get doseDemoRingSet => pick(
    'Lock the phone now. The alarm rings in 15 seconds.',
    'अब फ़ोन लॉक कीजिए। 15 सेकंड में अलार्म बजेगा।',
  );
  String get doseDemoRingUnavailable => pick(
    'Ringing only works in the Android app.',
    'अलार्म सिर्फ़ Android ऐप में बजता है।',
  );
}
