import 'app_language.dart';

/// Every word the app shows, in both languages, as a typed Dart table.
///
/// Not intl, not ARB: two languages, one team, one weekend. A getter per string
/// means a missing translation is a compile error rather than a blank label on
/// a demo phone, and a reviewer can read the English and the Hindi side by side.
///
/// Medicine names are never in this table. They stay in English letters exactly
/// as printed — in the Hindi UI too — because the patient has to match them
/// against the pack in their hand.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isHindi => language == AppLanguage.hi;

  String _t(String en, String hi) => isHindi ? hi : en;

  /// For strings that live beside their feature, as an extension on
  /// AppStrings in `lib/core/l10n/strings_<feature>.dart`. Same rule: English
  /// and Hindi side by side, and a missing one is a compile error.
  String pick(String en, String hi) => _t(en, hi);

  // ── Brand ────────────────────────────────────────────────────────────────
  String get appName => 'RapidRX';
  String get tagline => _t('Every dose, on time', 'हर दवाई, सही समय');

  // ── Language (the one screen that is bilingual at once) ─────────────────
  static const languageQuestionEn = 'Which language are you comfortable in?';
  static const languageQuestionHi = 'आप किस भाषा में सहज हैं?';
  static const englishOption = 'ENGLISH';
  static const hindiOption = 'हिंदी';

  String get savingPreference =>
      _t('Saving your preference…', 'आपकी पसंद सेव हो रही है…');

  // ── Voice help ──────────────────────────────────────────────────────────
  String get voiceQuestion =>
      _t('Do you need voice help?', 'क्या आपको आवाज़ में मदद चाहिए?');
  String get voiceWhy => _t(
    'RapidRX will read each screen aloud, and repeat it every little while. '
        'It works without internet too.',
    'RapidRX हर स्क्रीन पढ़कर सुनाएगा, और थोड़ी-थोड़ी देर में दोहराएगा। '
        'यह बिना इंटरनेट के भी काम करता है।',
  );
  String get yes => _t('Yes', 'हाँ');
  String get no => _t('No', 'नहीं');

  // ── Phone and OTP ───────────────────────────────────────────────────────
  String get phoneTitle => _t('Your mobile number', 'आपका मोबाइल नंबर');
  String get phoneWhy => _t(
    'Used to link your family member’s phone later. '
        'No SMS is sent in this demo.',
    'बाद में आपके परिवार के सदस्य का फ़ोन जोड़ने के लिए। '
        'इस डेमो में कोई SMS नहीं भेजा जाता।',
  );
  String get phoneHint => _t('Mobile number', 'मोबाइल नंबर');
  String get phoneInvalid =>
      _t('Enter a 10-digit mobile number', '10 अंकों का मोबाइल नंबर लिखें');

  String get otpTitle => _t('Enter the code', 'कोड लिखें');
  String otpSentTo(String phone) => _t(
    'We sent a 4-digit code to +91 $phone',
    'हमने +91 $phone पर 4 अंकों का कोड भेजा है',
  );
  String get otpHint => _t('4-digit code', '4 अंकों का कोड');
  String get otpWrong => _t(
    'That code is not right. Try again.',
    'यह कोड सही नहीं है। फिर से लिखें।',
  );
  String get otpDemoHint =>
      _t('Demo build: the code is 1234', 'डेमो: कोड 1234 है');
  String get verify => _t('Verify', 'जाँचें');

  // ── Profile ─────────────────────────────────────────────────────────────
  String get profileTitle => _t('About you', 'आपके बारे में');
  String get nameHint => _t('Your name', 'आपका नाम');
  String get nameMissing =>
      _t('Please write your name', 'कृपया अपना नाम लिखें');
  String get optional => _t('Optional', 'ज़रूरी नहीं');

  // ── PIN ─────────────────────────────────────────────────────────────────
  String get pinTitle => _t('Set a 4-digit PIN', '4 अंकों का PIN बनाएँ');
  String get pinWhy => _t(
    'You will use it to open RapidRX. Choose something you will remember.',
    'इससे आप RapidRX खोलेंगे। ऐसा चुनें जो आपको याद रहे।',
  );
  String get pinConfirmTitle => _t('Enter the PIN again', 'PIN फिर से लिखें');
  String get pinConfirmWhy =>
      _t('To make sure it is right.', 'ताकि पक्का हो जाए कि यह सही है।');
  String get pinInvalid =>
      _t('The PIN must be 4 digits', 'PIN 4 अंकों का होना चाहिए');
  String get pinMismatch => _t(
    'The two PINs are different. Set it again.',
    'दोनों PIN अलग हैं। फिर से बनाएँ।',
  );

  // ── Role ────────────────────────────────────────────────────────────────
  String get roleQuestion =>
      _t('Who is using this app?', 'यह ऐप कौन चला रहा है?');
  String get patient => _t('PATIENT', 'मरीज़');
  String get patientWhy =>
      _t('I want to track my prescription', 'मुझे अपनी दवाई पर नज़र रखनी है');
  String get caregiver => _t('CAREGIVER', 'देखभाल करने वाला');
  String get caregiverWhy => _t(
    'I want to help a patient track their prescription',
    'मुझे किसी की दवाई का ध्यान रखना है',
  );

  // ── Patient menu ────────────────────────────────────────────────────────
  /// The patient's greeting at the top of the menu.
  String hello(String? name) {
    final n = name?.trim() ?? '';
    return n.isEmpty ? _t('Hello', 'नमस्ते') : _t('Hello $n', 'नमस्ते $n');
  }

  String get menuQuestion =>
      _t('What would you like to do?', 'आप क्या करना चाहते हैं?');
  String get newPrescription => _t('New prescription', 'नई पर्ची');
  String get newPrescriptionWhy => _t(
    'Photograph a prescription, bill or strip',
    'पर्ची, बिल या दवाई के पत्ते की फ़ोटो लें',
  );
  String get myPrescriptions => _t('My prescriptions', 'मेरी पर्चियाँ');
  String get myPrescriptionsWhy =>
      _t('Everything added so far', 'अब तक जोड़ी गई सब पर्चियाँ');
  String get medicineSchedule => _t('Medicine schedule', 'दवाई का समय');
  String get medicineScheduleWhy =>
      _t('What to take today, and when', 'आज क्या और कब लेना है');
  String get noPrescriptionsYet => _t(
    'No prescriptions yet. Add one to build your daily plan.',
    'अभी कोई पर्ची नहीं है। एक जोड़िए, फिर रोज़ का प्लान बनेगा।',
  );

  // ── App bar actions ─────────────────────────────────────────────────────
  String get voiceOn => _t('Voice help is on', 'आवाज़ में मदद चालू है');
  String get voiceOff => _t('Voice help is off', 'आवाज़ में मदद बंद है');
  String get switchLanguage => _t('हिंदी में देखें', 'Switch to English');
  String get account => _t('Account', 'खाता');
  String get changeRole =>
      _t('Change who is using the app', 'ऐप चलाने वाला बदलें');
  String get startAgain =>
      _t('Start again from the beginning', 'शुरू से फिर करें');
  String get startAgainWhy => _t(
    'Your name, number and PIN will be asked again.',
    'आपका नाम, नंबर और PIN फिर से पूछा जाएगा।',
  );

  // ── Visit capture ───────────────────────────────────────────────────────
  String get newVisit => _t('New visit', 'नई विज़िट');
  String get visitIntro => _t(
    'Add what you have. You can come back and add the rest later.',
    'जो आपके पास है वो जोड़ें। बाकी बाद में भी जोड़ सकते हैं।',
  );
  String get doctorNameHint =>
      _t('Doctor\'s name (optional)', 'डॉक्टर का नाम (ज़रूरी नहीं)');
  String photoN(int n) => _t('Photo $n', 'फ़ोटो $n');
  String get prescriptionPhoto => _t('Prescription photo', 'पर्ची की फ़ोटो');
  String get prescriptionPhotoWhy =>
      _t('The anchor of the visit', 'विज़िट की सबसे ज़रूरी चीज़');
  String get doctorVoice => _t('Doctor\'s voice', 'डॉक्टर की बात');
  String get doctorVoiceWhy =>
      _t('What the doctor explained', 'डॉक्टर ने जो समझाया');
  String get pharmacyBill => _t('Pharmacy bill', 'दवाई का बिल');
  String get pharmacyBillWhy =>
      _t('Printed, so the most reliable', 'छपा हुआ, इसलिए सबसे भरोसेमंद');
  String get chemistVoice => _t('Chemist\'s voice', 'केमिस्ट की बात');
  String get chemistVoiceWhy =>
      _t('What the chemist explained', 'केमिस्ट ने जो समझाया');
  String get required => _t('Required', 'ज़रूरी');
  String get recommended => _t('Recommended', 'सुझाया गया');
  String get added => _t('Added', 'जुड़ गया');
  String get buildPlan => _t('Build plan', 'प्लान बनाएँ');
  String get addPrescriptionFirst =>
      _t('Add the prescription photo first.', 'पहले पर्ची की फ़ोटो जोड़ें।');
  String get browserPreview => _t(
    'Browser preview: captures are kept only until you close this tab. '
        'The Android build saves them on the phone.',
    'ब्राउज़र प्रीव्यू: टैब बंद करते ही फ़ोटो और आवाज़ हट जाएँगी। '
        'Android ऐप इन्हें फ़ोन पर सेव करता है।',
  );
  String get takePhoto => _t('Take a photo', 'फ़ोटो खींचें');
  String get chooseFromGallery => _t('Choose from gallery', 'गैलरी से चुनें');
  String get startRecording => _t('Start recording', 'रिकॉर्डिंग शुरू करें');
  String get stopRecording => _t('Stop and save', 'रोकें और सेव करें');
  String get recording => _t('Recording…', 'रिकॉर्ड हो रहा है…');
  String get micUnavailable => _t(
    'The microphone is not available here.',
    'यहाँ माइक्रोफ़ोन उपलब्ध नहीं है।',
  );
  String get cameraUnavailable => _t(
    'Could not get a photo. Nothing was added.',
    'फ़ोटो नहीं मिली। कुछ नहीं जोड़ा गया।',
  );

  // ── Consent ─────────────────────────────────────────────────────────────
  String get consentTitle =>
      _t('Before we keep anything', 'कुछ भी रखने से पहले');
  String get consentBody => _t(
    'Photos and voice notes of this visit are saved on this phone only. '
        'They are read on the phone to build your plan. Nothing is sent '
        'anywhere unless you say so on a later screen.',
    'इस विज़िट की फ़ोटो और आवाज़ सिर्फ़ इसी फ़ोन पर सेव होंगी। प्लान बनाने '
        'के लिए इन्हें फ़ोन पर ही पढ़ा जाता है। जब तक आप आगे किसी स्क्रीन '
        'पर हाँ न कहें, कुछ भी कहीं नहीं भेजा जाता।',
  );
  String get consentAgree => _t('I agree, continue', 'मैं सहमत हूँ, आगे बढ़ें');
  String get consentDecline => _t('Not now', 'अभी नहीं');

  // ── Plain language for a schedule ───────────────────────────────────────
  String get morning => _t('Morning', 'सुबह');
  String get afternoon => _t('Afternoon', 'दोपहर');
  String get evening => _t('Evening', 'शाम');
  String get night => _t('Night', 'रात');
  String get beforeFood => _t('before food', 'खाने से पहले');
  String get afterFood => _t('after food', 'खाने के बाद');
  String get whenNeeded => _t('When needed', 'ज़रूरत पड़ने पर');
  String get onceNow => _t('Once, now', 'एक बार, अभी');
  String get timingUnknown =>
      _t('Nobody said when', 'कब लेनी है, किसी ने नहीं बताया');
  String forDays(int d) => _t('for $d days', '$d दिन तक');
  String everyNDays(int n) => n == 2
      ? _t('every other day', 'एक दिन छोड़कर')
      : _t('every $n days', 'हर $n दिन');
  String get halfTablet => _t('half a tablet', 'आधी गोली');
  String tablets(num n) => _t('$n tablets', '$n गोली');

  // ── Wizard: frame ───────────────────────────────────────────────────────
  String stepOf(int n, int total) => _t('Step $n of $total', 'चरण $n / $total');
  String get approve => _t('Approve and add', 'मंज़ूर करें और जोड़ें');

  // ── Step 1 and 4: words ─────────────────────────────────────────────────
  String get doctorWordsTitle =>
      _t('What did the doctor say?', 'डॉक्टर ने क्या कहा?');
  String get doctorWordsWhy => _t(
    'Record it, or type it. You can skip this and use the photo instead.',
    'बोलकर बताएँ या लिखें। चाहें तो इसे छोड़कर सिर्फ़ फ़ोटो से भी काम चलेगा।',
  );
  String get pharmacyTitle => _t('Pharmacy page', 'दवाई की दुकान');
  String get pharmacyWhy => _t(
    'What did the chemist say? Speak it or write it. The bill photo was '
        'added in the photo step.',
    'केमिस्ट ने क्या कहा? बोलकर या लिखकर बताएँ। बिल की फ़ोटो पिछले चरण में '
        'जुड़ गई है।',
  );
  String get speak => _t('Speak', 'बोलें');
  String get listening =>
      _t('Listening… tap to stop', 'सुन रहे हैं… रोकने के लिए दबाएँ');
  String get writeIt => _t('Write it', 'लिखें');
  String get nothingWrittenYet =>
      _t('Nothing written yet', 'अभी कुछ नहीं लिखा');
  String get alsoSaveAudio => _t('Also save the audio', 'आवाज़ भी सेव करें');
  String get alsoSaveAudioWhy => _t(
    'Keeps the recording so a family member can listen later. It is not '
        'turned into text.',
    'रिकॉर्डिंग रख ली जाएगी ताकि परिवार वाले बाद में सुन सकें। इसे टेक्स्ट '
        'में नहीं बदला जाता।',
  );
  String get audioSaved => _t('Audio saved', 'आवाज़ सेव हो गई');
  String get dictationUnavailable => _t(
    'Speaking is not available on this device. Write it instead.',
    'इस डिवाइस पर बोलकर लिखना उपलब्ध नहीं है। लिखकर बताएँ।',
  );
  String get writeNoteTitle =>
      _t('Write what was said', 'जो कहा गया, वो लिखें');
  String get writeNoteHint => _t(
    'For example: Telma 40 subah, khane ke baad',
    'जैसे: Telma 40 subah, khane ke baad',
  );

  // ── Step 2 and 5: takeaways ─────────────────────────────────────────────
  String get takeawaysTitle =>
      _t('Is this what was said?', 'क्या यही कहा गया था?');
  String get takeawaysWhy => _t(
    'Read on this phone, with no internet. Tick what is correct, fix what '
        'is not.',
    'इसी फ़ोन पर, बिना इंटरनेट के पढ़ा गया। जो सही है उस पर टिक करें, जो '
        'गलत है उसे ठीक करें।',
  );
  String get chemistTakeawaysTitle =>
      _t('Is this what the chemist said?', 'क्या केमिस्ट ने यही कहा था?');
  String get looksClear => _t('Looks clear', 'साफ़ है');
  String get pleaseCheck => _t('Please check', 'जाँच लें');
  String get edit => _t('Edit', 'बदलें');
  String get medicineName => _t('Medicine name', 'दवाई का नाम');
  String get medicineNameWhy => _t(
    'In English letters, as printed on the pack',
    'अंग्रेज़ी अक्षरों में, जैसा पत्ते पर छपा है',
  );
  String get whenToTake => _t('When to take it', 'कब लेनी है');
  String get nothingToCheck => _t(
    'Nothing was said to check. You can go on.',
    'जाँचने के लिए कुछ नहीं कहा गया। आप आगे बढ़ सकते हैं।',
  );
  String get addRow => _t('Add a medicine', 'दवाई जोड़ें');

  // ── Step 3: photos ──────────────────────────────────────────────────────
  String get photosTitle => _t('Photos', 'फ़ोटो');
  String get photosWhy => _t(
    'The prescription, the bill, and the strips. RapidRX reads each one on '
        'this phone and labels it - check the labels before continuing.',
    'पर्ची, बिल और दवाई के पत्ते। RapidRX हर फ़ोटो को इसी फ़ोन पर पढ़कर '
        'पहचानता है - आगे बढ़ने से पहले पहचान जाँच लें।',
  );
  String get findRecent => _t('Find recent photos', 'हाल की फ़ोटो ढूँढें');
  String get camera => _t('Camera', 'कैमरा');
  String get gallery => _t('Gallery', 'गैलरी');
  String get areTheseRight => _t('Are these right?', 'क्या ये सही हैं?');
  String nSelected(int n) => _t('$n selected', '$n चुनी गईं');
  String get labelPrescription => _t('Prescription', 'पर्ची');
  String get labelBill => _t('Bill', 'बिल');
  String get labelStrip => _t('Strip', 'पत्ता');
  String get notMedicalReason => _t(
    'This does not look like a prescription, bill or strip.',
    'यह पर्ची, बिल या दवाई का पत्ता नहीं लगता।',
  );
  String get useAnyway => _t('Use it anyway', 'फिर भी इस्तेमाल करें');
  String get reading => _t('Reading…', 'पढ़ रहे हैं…');
  String get couldNotRead => _t(
    'This build cannot read photos. They are kept with the visit.',
    'यह ऐप फ़ोटो नहीं पढ़ सकता। फ़ोटो विज़िट के साथ रखी गई हैं।',
  );
  String get needPrescription => _t(
    'Tick at least one prescription photo to continue.',
    'आगे बढ़ने के लिए कम से कम एक पर्ची की फ़ोटो चुनें।',
  );
  String get scanUnsupported => _t(
    'Finding recent photos only works in the Android app. Use Camera or '
        'Gallery.',
    'हाल की फ़ोटो ढूँढना सिर्फ़ Android ऐप में होता है। कैमरा या गैलरी '
        'इस्तेमाल करें।',
  );
  String get scanDenied => _t(
    'RapidRX was not allowed to look at your photos. Use Camera or Gallery.',
    'RapidRX को फ़ोटो देखने की अनुमति नहीं मिली। कैमरा या गैलरी इस्तेमाल करें।',
  );
  String get scanNothing => _t(
    'No recent photos looked like a prescription or bill.',
    'हाल की कोई फ़ोटो पर्ची या बिल जैसी नहीं लगी।',
  );

  // ── Step 6: processing ──────────────────────────────────────────────────
  String get processingTitle => _t('Reading everything', 'सब कुछ पढ़ रहे हैं');
  String get stageJudge => _t(
    'Judge - what do we have, and how clear is it',
    'जाँच - हमारे पास क्या है, और कितना साफ़ है',
  );
  String get stageExtract =>
      _t('Extract - medicines, doses, timings', 'निकालना - दवाई, खुराक, समय');
  String get stageVerify =>
      _t('Verify - cross-check every source', 'मिलान - हर स्रोत से मिलाना');
  String get onDeviceOnly => _t(
    'Done on this phone. Online reading of handwriting is not set up yet, '
        'so photos are kept with the visit for now.',
    'यह सब इसी फ़ोन पर हुआ। हाथ की लिखावट ऑनलाइन पढ़ना अभी चालू नहीं है, '
        'इसलिए फ़ोटो अभी विज़िट के साथ रखी गई हैं।',
  );
  String get onDeviceBadge => _t('On this phone only', 'सिर्फ़ इसी फ़ोन पर');
  String foundMedicines(int n) =>
      _t(n == 1 ? 'Found 1 medicine' : 'Found $n medicines', '$n दवाई मिलीं');
  String get foundNothing => _t(
    'No medicine could be read. Go back and add a clearer photo, or write '
        'what the doctor said.',
    'कोई दवाई पढ़ी नहीं जा सकी। पीछे जाकर साफ़ फ़ोटो जोड़ें, या डॉक्टर की '
        'बात लिखें।',
  );

  // ── Step 7: medicines ───────────────────────────────────────────────────
  String get medicinesTitle => _t('Your medicines', 'आपकी दवाइयाँ');
  String get medicinesWhy => _t(
    'Each card shows what every source said. Confirm the ones that are '
        'right, fix the ones that are not.',
    'हर कार्ड दिखाता है कि हर स्रोत ने क्या कहा। जो सही हैं उन्हें पक्का '
        'करें, जो गलत हैं उन्हें ठीक करें।',
  );
  String get confirm => _t('Confirm', 'पक्का करें');
  String get confirmed => _t('Confirmed', 'पक्का');
  String get sourceBill => _t('Bill', 'बिल');
  String get sourcePrescription => _t('Rx', 'पर्ची');
  String get sourceDoctor => _t('Doctor', 'डॉक्टर');
  String get sourceChemist => _t('Chemist', 'केमिस्ट');
  String get sourceStrip => _t('Strip', 'पत्ता');
  String get agreeTwoPlus =>
      _t('Two or more sources agree', 'दो या ज़्यादा स्रोत सहमत हैं');
  String get notPrescribed => _t(
    'On the bill, but nobody prescribed it',
    'बिल पर है, पर किसी ने लिखी नहीं',
  );
  String get onlySpoken =>
      _t('Only spoken - not on the bill', 'सिर्फ़ बोली गई - बिल पर नहीं');
  String get onlyOnPrescription => _t(
    'Only on the prescription - not on the bill',
    'सिर्फ़ पर्ची पर - बिल पर नहीं',
  );
  String get onlyOneSource => _t('Only one source', 'सिर्फ़ एक स्रोत');
  String get noTimingGiven =>
      _t('Nobody said when to take it', 'कब लेनी है, किसी ने नहीं बताया');
  String get wordsToCheck =>
      _t('Some words need a check', 'कुछ शब्द जाँचने हैं');
  String get readerUnsure =>
      _t('The reading was not certain', 'पढ़ाई पक्की नहीं थी');
  String get listedTwice => _t('Listed twice', 'दो बार लिखी है');
  String get disagreeStrength => _t(
    'The sources show different strengths',
    'स्रोतों में ताक़त अलग-अलग है',
  );
  String get disagreeTiming =>
      _t('The sources disagree on when', 'स्रोतों में समय अलग-अलग है');
  String get disagreeFood => _t(
    'Before or after food? The sources disagree',
    'खाने से पहले या बाद? स्रोत अलग कहते हैं',
  );
  String get disagreeInterval => _t(
    'Every day or not? The sources disagree',
    'रोज़ या नहीं? स्रोत अलग कहते हैं',
  );
  String get disagreeAsNeeded => _t(
    'Fixed time or only when needed? The sources disagree',
    'तय समय पर या ज़रूरत पर? स्रोत अलग कहते हैं',
  );
  String get chooseOne => _t('Which one is right?', 'कौन सा सही है?');
  String get keepThis => _t('Keep this one', 'यही रखें');
  String get leaveOut => _t('Leave it out', 'इसे हटाएँ');
  String get leftOut => _t('Left out', 'हटा दी गई');
  String get putBack => _t('Put it back', 'वापस जोड़ें');
  String get confirmAllFirst => _t(
    'Confirm or leave out every card to continue.',
    'आगे बढ़ने के लिए हर कार्ड को पक्का करें या हटाएँ।',
  );

  // ── Step 8: placement ───────────────────────────────────────────────────
  String get placementTitle => _t('Where they fit', 'कब-कब लेनी हैं');
  String get placementWhy => _t(
    'Checked against what you already take.',
    'जो आप पहले से ले रहे हैं, उससे मिलाया गया।',
  );
  String get placementKept =>
      _t('Timing as prescribed', 'जैसा लिखा गया, वही समय');
  String get placementSuggested => _t(
    'Suggested time - nobody said when',
    'सुझाया गया समय - किसी ने नहीं बताया',
  );
  String get placementDuplicate =>
      _t('Already on your list', 'पहले से आपकी सूची में है');
  String get placementBusy =>
      _t('Many medicines at this time', 'इस समय कई दवाइयाँ हैं');
  String get placementFoodClash => _t(
    'Empty stomach, among after-food medicines',
    'खाली पेट वाली, खाने के बाद वाली दवाइयों के साथ',
  );
  String get placementCourse => _t('Stops on its own', 'अपने आप बंद हो जाएगी');
  String get prescriptionSaved => _t('Prescription saved', 'पर्ची सेव हो गई');
  String get scheduleUpdated =>
      _t('Schedule updated', 'दवाई का समय अपडेट हो गया');

  // ── Daily doses ─────────────────────────────────────────────────────────
  String get tickAsYouGo => _t(
    'Tick each medicine as you take it.',
    'जैसे-जैसे लेते जाइए, हर दवाई पर टिक कीजिए।',
  );
  String get allTaken => _t('All taken', 'सब ले ली');
  String get statusTaken => _t('Taken', 'ले ली');
  String get statusMissed => _t('Missed', 'छूट गई');
  String get statusNotYet => _t('Not yet', 'अभी नहीं');
  String get statusDueNow => _t('Due now', 'अभी का समय');
  String takeOnlyWhenNeeded(String names) => _t(
    'Take $names only when you need it.',
    '$names सिर्फ़ ज़रूरत पड़ने पर लें।',
  );
  String get thisMonth => _t('This month', 'इस महीने');
  String get legendTaken => _t('Taken', 'ले ली');
  String get legendMissed => _t('Missed', 'छूट गई');
  String get legendNothingDue => _t('Nothing due', 'कुछ नहीं लेना था');
  String get nothingDueToday =>
      _t('Nothing is due today.', 'आज कुछ नहीं लेना है।');
  String get remindersUnavailable => _t(
    'Reminders only work in the Android app.',
    'याद दिलाना सिर्फ़ Android ऐप में काम करता है।',
  );
  String get remindersOff => _t(
    'Reminders are turned off for RapidRX. Turn on notifications so the '
        'phone can ring when a dose is due.',
    'RapidRX के लिए याद दिलाना बंद है। नोटिफ़िकेशन चालू करें ताकि दवाई के '
        'समय फ़ोन बज सके।',
  );
  String get share => _t('Share', 'शेयर करें');
  String get doseSaved => _t('Saved. Well done.', 'सेव हो गया। शाबाश।');
  String get evidenceDoctor => _t('doctor note', 'डॉक्टर की बात');
  String get evidencePrescription => _t('prescription', 'पर्ची');
  String get evidenceBill => _t('bill', 'बिल');
  String get evidenceChemist => _t('chemist', 'केमिस्ट');
  String get halfDot => _t('half', 'आधी');

  // ── Online handwriting (consent-gated) ──────────────────────────────────
  String get readOnlineTitle =>
      _t('Read the handwriting online', 'लिखावट ऑनलाइन पढ़ें');
  String get readOnlineBody => _t(
    'The prescription photo will be sent to Google to read the handwriting. '
        'Nothing else leaves the phone.',
    'लिखावट पढ़ने के लिए पर्ची की फ़ोटो Google को भेजी जाएगी। इसके अलावा '
        'कुछ भी फ़ोन से बाहर नहीं जाता।',
  );
  String get readButton => _t('Read', 'पढ़ें');
  String get readingOnline =>
      _t('Reading the handwriting…', 'लिखावट पढ़ रहे हैं…');
  String readOnlineDone(int n) => _t(
    'Read online. $n added to the cross-check — each one is still checked '
        'against the bill.',
    'ऑनलाइन पढ़ लिया। $n दवाई मिलान में जोड़ी गईं — हर एक अब भी बिल से '
        'मिलाई जाएगी।',
  );
  String get readOnlineFailed => _t(
    'Could not read it online. Everything done on this phone still stands.',
    'ऑनलाइन नहीं पढ़ा जा सका। इस फ़ोन पर जो हुआ, वो सब वैसा ही है।',
  );
  String get onDeviceDone => _t(
    'Done on this phone. Nothing has left it.',
    'यह सब इसी फ़ोन पर हुआ। कुछ भी बाहर नहीं गया।',
  );

  // ── Caregiver home ──────────────────────────────────────────────────────
  String get todaysDoses => _t('Today\'s doses', 'आज की खुराक');
  String get alerts => _t('Alerts', 'अलर्ट');
  String get alertsWhy => _t(
    'A message goes out when a dose is taken, and when one is missed.',
    'दवाई लेने पर और छूटने पर संदेश जाता है।',
  );
  String get noFamilyYet =>
      _t('No family member added yet.', 'अभी कोई सदस्य नहीं जोड़ा गया।');
  String get sendStatus => _t('Send today\'s status', 'आज का हाल भेजें');
  String get sharePlan => _t('Share the full plan', 'पूरा प्लान भेजें');
  String get familyNumberTitle => _t(
    'Family member\'s WhatsApp number',
    'परिवार के सदस्य का WhatsApp नंबर',
  );
  String get familyNumberInvalid => _t(
    'That does not look like a mobile number. Nothing was saved.',
    'यह मोबाइल नंबर नहीं लगता। कुछ सेव नहीं हुआ।',
  );
  String get sentAutomatically =>
      _t('Sent on WhatsApp.', 'WhatsApp पर भेज दिया।');
  String get openedInWhatsApp => _t(
    'Opened in WhatsApp — press send there.',
    'WhatsApp में खुल गया — वहाँ भेजें दबाएँ।',
  );
  String get sendFailed => _t(
    'Could not send. It will be tried again later.',
    'भेजा नहीं जा सका। बाद में फिर कोशिश होगी।',
  );
  String get addFamilyFirst => _t(
    'Add a family member\'s number first.',
    'पहले परिवार के सदस्य का नंबर जोड़ें।',
  );

  // ── Messages that leave the phone (plain text) ──────────────────────────
  String planHeader(String name) =>
      _t('Medicine plan — $name', 'दवाई का प्लान — $name');
  String statusHeader(String name) =>
      _t('Medicines today — $name', 'आज की दवाई — $name');
  String get messageFooter => _t(
    'Sent from RapidRX. Every row was checked by a person. This is not '
        'medical advice.',
    'RapidRX से भेजा गया। हर पंक्ति किसी व्यक्ति ने जाँची है। यह डॉक्टरी '
        'सलाह नहीं है।',
  );
  String get inTheMorning => _t('in the morning', 'सुबह');
  String get inTheAfternoon => _t('in the afternoon', 'दोपहर में');
  String get inTheEvening => _t('in the evening', 'शाम को');
  String get atNight => _t('at night', 'रात को');
  String get and => _t('and', 'और');
  String take(String name) => _t('Take $name', '$name लें');
  String takeWhenNeeded(String name) =>
      _t('Take $name only when needed.', '$name सिर्फ़ ज़रूरत पड़ने पर लें।');
  String takeOnceNow(String name) =>
      _t('Take $name once.', '$name एक बार लें।');
  String takeWhenUnknown(String name) => _t(
    '$name — ask the doctor when to take it.',
    '$name — कब लेनी है, डॉक्टर से पूछें।',
  );
  String forMoreDays(int d) => _t('for $d more days', 'अभी $d दिन और');
  String doctorSaidFor(String p) => _t(
    'The doctor said this is for "$p".',
    'डॉक्टर ने कहा यह "$p" के लिए है।',
  );
  String slotTaken(String name, String slot) => _t(
    '$name: $slot medicines were taken.',
    '$name: $slot की दवाई ले ली गई।',
  );
  String slotMissed(String name, String slot) =>
      _t('$name: $slot medicines were missed.', '$name: $slot की दवाई छूट गई।');
  String slotMissedOn(String name, String slot, String date) => _t(
    '$name: $slot medicines on $date were missed.',
    '$name: $date को $slot की दवाई छूट गई।',
  );

  // ── Health profile (patients) ───────────────────────────────────────────
  String get healthTitle =>
      _t('A little about your health', 'आपकी सेहत के बारे में');
  String get healthWhy => _t(
    'Only your age is needed. The rest helps, and you can add it later.',
    'सिर्फ़ उम्र ज़रूरी है। बाकी से मदद मिलती है, और इसे बाद में भी जोड़ सकते हैं।',
  );
  String get ageLabel => _t('Age (years)', 'उम्र (साल)');
  String get heightLabel => _t('Height (cm)', 'लंबाई (सेमी)');
  String get weightLabel => _t('Weight (kg)', 'वज़न (किलो)');
  String get ageMissing => _t('Please write your age', 'कृपया अपनी उम्र लिखें');
  String get ageOutOfRange =>
      _t('Age must be between 1 and 120', 'उम्र 1 से 120 के बीच होनी चाहिए');
  String get heightOutOfRange => _t(
    'Height must be between 50 and 250 cm',
    'लंबाई 50 से 250 सेमी के बीच होनी चाहिए',
  );
  String get weightOutOfRange => _t(
    'Weight must be between 10 and 300 kg',
    'वज़न 10 से 300 किलो के बीच होना चाहिए',
  );
  String get ayushmanLabel =>
      _t('Ayushman Bharat (PM-JAY) card', 'आयुष्मान भारत (PM-JAY) कार्ड');
  String get ayushmanHint => _t('PM-JAY ID', 'PM-JAY आईडी');
  String get fetchPmjay => _t('Fetch from PM-JAY', 'PM-JAY से लाएँ');
  String get fetchingPmjay => _t('Looking it up…', 'ढूँढ रहे हैं…');
  String get pmjayBadFormat => _t(
    'That does not look like a PM-JAY ID. It has 9 letters and numbers.',
    'यह PM-JAY आईडी नहीं लगती। इसमें 9 अक्षर और अंक होते हैं।',
  );
  String get pmjayNotFound => _t(
    'No card was found for this ID. Check the number on your card.',
    'इस आईडी से कोई कार्ड नहीं मिला। कार्ड पर लिखा नंबर जाँच लें।',
  );
  String get demoData => _t('Demo data', 'डेमो डेटा');
  String get pmjayIdLabel => _t('PM-JAY ID', 'PM-JAY आईडी');
  String get familyIdLabel => _t('Family ID', 'परिवार आईडी');
  String get stateLabel => _t('State', 'राज्य');
  String eligibleCover(String cover) =>
      _t('Eligible — $cover cover', 'पात्र — $cover का कवर');
  String validTill(String d) => _t('Valid till $d', '$d तक मान्य');
  String get yesThisIsMe => _t('Yes, this is me', 'हाँ, यह मैं हूँ');
  String get notMe => _t('Not me', 'यह मैं नहीं');
  String get cardConfirmed => _t('Card saved', 'कार्ड सेव हो गया');

  // ── Doctor verification ─────────────────────────────────────────────────
  String get whoVerifies => _t('Who is verifying?', 'कौन जाँच रहा है?');
  String get verifierDoctor => _t('Doctor', 'डॉक्टर');
  String get verifierPatient => _t('Me (patient)', 'मैं (मरीज़)');
  String get verifierCaretaker =>
      _t('Me (caretaker)', 'मैं (देखभाल करने वाला)');
  String get doctorCheckTitle =>
      _t('Doctor, is this what you said?', 'डॉक्टर साहब, क्या आपने यही कहा?');
  String get doctorCheckWhy => _t(
    'Tick each point that is right. Mark "Not provided" for anything you '
        'did not say. Unticked points stay flagged.',
    'जो सही है उस पर टिक करें। जो आपने नहीं कहा, उसे "नहीं बताया" चुनें। '
        'बिना टिक वाले बिंदु जाँच के लिए रह जाते हैं।',
  );
  String get pointName => _t('Medicine and strength', 'दवाई और ताक़त');
  String get pointDose => _t('Dose', 'खुराक');
  String get pointTiming => _t('When to take', 'कब लेनी है');
  String get pointFood => _t('With food', 'खाने के साथ');
  String get pointDuration => _t('How long', 'कितने दिन');
  String get pointPurpose => _t('What it is for', 'किसलिए');
  String get notProvided => _t('Not provided', 'नहीं बताया');
  String get notMentioned => _t('Not mentioned', 'नहीं कहा गया');
  String get oneTablet => _t('1 tablet', '1 गोली');
  String get verified => _t('Verified', 'जाँच हो गई');
  String pointsLeft(int n) =>
      _t(n == 1 ? '1 point left' : '$n points left', '$n बिंदु बाकी');
  String get adviceCheck => _t('Advice', 'सलाह');

  // ── Note for the caretaker ──────────────────────────────────────────────
  String get caretakerNoteTitle =>
      _t('Note for the caretaker', 'देखभाल करने वाले के लिए नोट');
  String get caretakerNoteHint =>
      _t('Anything the family should know', 'परिवार को जो जानना चाहिए');
  String get priority => _t('Priority', 'ज़रूरी कितना');
  String get priorityLow => _t('Low', 'कम');
  String get priorityMedium => _t('Medium', 'मध्यम');
  String get priorityHigh => _t('High', 'ज़्यादा');
  String get caretakerNotes => _t('Notes', 'नोट');

  // ── Offline and sync ────────────────────────────────────────────────────
  String get offlineTitle => _t('No internet', 'इंटरनेट नहीं है');
  String get offlineSaved => _t(
    'No internet. Your session is saved and will sync automatically when '
        'you\'re back online.',
    'इंटरनेट नहीं है। आपका सेशन सेव है और इंटरनेट आते ही अपने आप सिंक हो '
        'जाएगा।',
  );
  String get allSyncedTitle => _t('All synced', 'सब सिंक हो गया');
  String get allSynced => _t(
    'Everything saved offline has been sent.',
    'ऑफ़लाइन सेव हुआ सब कुछ भेज दिया गया।',
  );
  String get newReadingTitle =>
      _t('New reading to review', 'नई पढ़ाई जाँचनी है');
  String get newReading => _t(
    'The handwriting was read online. Open My prescriptions to check it — '
        'nothing on your schedule changed.',
    'लिखावट ऑनलाइन पढ़ी गई। मेरी पर्चियाँ खोलकर जाँचें — आपके दवाई के '
        'समय में कुछ नहीं बदला।',
  );
  String get waitingToSync => _t('Waiting to sync', 'सिंक होना बाकी');
  String get syncedLabel => _t('Synced', 'सिंक हो गया');
  String get reviewReading => _t('New reading to review', 'नई पढ़ाई जाँचें');
  String get pmjayQueued => _t(
    'No internet. We will look this up as soon as you are online.',
    'इंटरनेट नहीं है। इंटरनेट आते ही हम इसे ढूँढ लेंगे।',
  );
  String get pmjayFoundLater => _t(
    'Your Ayushman card was found. Is this you?',
    'आपका आयुष्मान कार्ड मिल गया। क्या यह आप हैं?',
  );

  // ── Shared ──────────────────────────────────────────────────────────────
  String get continueLabel => _t('Continue', 'आगे बढ़ें');
  String get back => _t('Back', 'पीछे');
  String get next => _t('Next', 'आगे');
  String get skip => _t('Skip', 'छोड़ें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get done => _t('Done', 'हो गया');
  String get save => _t('Save', 'सेव करें');
  String get change => _t('Change', 'बदलें');
}
