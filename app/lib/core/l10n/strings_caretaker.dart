import '../storage/app_prefs.dart' show CaretakerType;
import 'app_strings.dart';

/// Caretaker onboarding, pairing, the patient's scan, and the caretaker home
/// by type. Same rule as AppStrings: English and Hindi side by side.
extension CaretakerStrings on AppStrings {
  // ── Who are you to the patient? ─────────────────────────────────────────
  String get caretakerTypeQuestion =>
      pick('Who are you to the patient?', 'आप मरीज़ के कौन हैं?');
  String get caretakerTypeWhy => pick(
    'This decides what you can see.',
    'इससे तय होता है कि आप क्या देख पाएँगे।',
  );
  String get familyMember => pick('Family member', 'परिवार का सदस्य');
  String get familyMemberWhy => pick(
    'Son, daughter, spouse or relative. You see everything.',
    'बेटा, बेटी, पति-पत्नी या रिश्तेदार। आप सब कुछ देख पाएँगे।',
  );
  String get commercialCaretaker =>
      pick('Non-family caretaker', 'परिवार से बाहर के देखभालकर्ता');
  String get commercialCaretakerWhy => pick(
    'A paid attendant or nurse. The patient sets a PIN, and you see '
        'the doses and notes.',
    'पैसे लेकर देखभाल करने वाले या नर्स। मरीज़ एक PIN रखेंगे, और आप '
        'दवाई और नोट देख पाएँगे।',
  );
  String caretakerTypeLabel(CaretakerType t) => switch (t) {
    CaretakerType.family => familyMember,
    CaretakerType.commercial => commercialCaretaker,
  };

  // ── Your QR code ────────────────────────────────────────────────────────
  String get pairingQrTitle =>
      pick('Your caretaker QR code', 'आपका देखभालकर्ता QR कोड');
  String get pairingQrWhy => pick(
    'Ask the patient to open RapidRX and tap "Scan caretaker QR".',
    'मरीज़ से कहें: RapidRX खोलें, फिर "देखभालकर्ता का QR स्कैन करें" दबाएँ।',
  );
  String pairingValidFor(int minutes) => pick(
    minutes == 1
        ? 'Works for 1 more minute'
        : 'Works for $minutes more minutes',
    'अभी $minutes मिनट और चलेगा',
  );
  String get pairingExpired => pick(
    'This code has expired. Make a new one.',
    'इस कोड का समय खत्म हो गया। नया बनाएँ।',
  );
  String get makeNewCode => pick('Make a new code', 'नया कोड बनाएँ');
  String get orTypeThisCode => pick(
    'No camera? Send this code to the patient to type or paste:',
    'कैमरा नहीं है? यह कोड मरीज़ को भेजें, वे इसे लिख या पेस्ट कर सकते हैं:',
  );
  String get shareCode => pick('Send the code', 'कोड भेजें');
  String get enterPatientCode =>
      pick('Enter the patient\'s code', 'मरीज़ का कोड डालें');
  String get doThisLater => pick('I\'ll do this later', 'यह बाद में करूँगा');
  String get pairingDemoHint => pick(
    'Demo: there is no server. After scanning, the patient\'s phone shows a '
        '4-digit code that completes the link.',
    'डेमो: कोई सर्वर नहीं है। स्कैन के बाद मरीज़ के फ़ोन पर 4 अंकों का '
        'कोड आता है, उसी से जुड़ाव पूरा होता है।',
  );

  // ── Enter the patient's code ────────────────────────────────────────────
  String get confirmWhy => pick(
    'After the patient scans your QR code, their phone shows their name and '
        'a 4-digit code.',
    'मरीज़ के आपका QR कोड स्कैन करने के बाद, उनके फ़ोन पर उनका नाम और '
        '4 अंकों का कोड दिखेगा।',
  );
  String get patientNameHint => pick('Patient\'s name', 'मरीज़ का नाम');
  String get fourDigitCode => pick('4-digit code', '4 अंकों का कोड');
  String get connect => pick('Connect', 'जोड़ें');
  String get patientNameMissing =>
      pick('Write the patient\'s name', 'मरीज़ का नाम लिखें');
  String get codeShort => pick('The code has 4 digits', 'कोड 4 अंकों का है');
  String get codeWrong => pick(
    'That code does not match. Check the patient\'s phone.',
    'यह कोड मेल नहीं खाता। मरीज़ का फ़ोन देखें।',
  );
  String get connectionSuccessful =>
      pick('Caretaker connection successful', 'देखभालकर्ता जुड़ गए');
  String linkedTo(String name) =>
      pick('You are now linked to $name.', 'अब आप $name से जुड़ गए हैं।');
  String get ok => pick('OK', 'ठीक है');

  // ── Caretaker home: the link ────────────────────────────────────────────
  String get notLinkedYet =>
      pick('Not linked to a patient yet.', 'अभी किसी मरीज़ से नहीं जुड़े हैं।');
  String get showMyQr => pick('Show my QR code', 'मेरा QR कोड दिखाएँ');
  String linkedPatientLine(String name) =>
      pick('Linked to $name', '$name से जुड़े हैं');

  // ── Patient: scan caretaker QR ──────────────────────────────────────────
  String get scanCaretakerQr =>
      pick('Scan caretaker QR', 'देखभालकर्ता का QR स्कैन करें');
  String get scanCaretakerQrWhy => pick(
    'Link a family member or caretaker',
    'परिवार के सदस्य या देखभालकर्ता को जोड़ें',
  );
  String get pointCamera => pick(
    'Point the camera at the QR code on the caretaker\'s phone.',
    'कैमरा देखभालकर्ता के फ़ोन पर दिख रहे QR कोड की ओर करें।',
  );
  String get torch => pick('Torch', 'टॉर्च');
  String get cannotScanHere => pick(
    'This device cannot scan. Type or paste the code the caretaker sent you.',
    'यह डिवाइस स्कैन नहीं कर सकता। देखभालकर्ता का भेजा कोड लिखें या पेस्ट करें।',
  );
  String get cameraDenied => pick(
    'RapidRX is not allowed to use the camera. Allow it in Settings, then '
        'try again — or type the code below.',
    'RapidRX को कैमरा इस्तेमाल करने की अनुमति नहीं है। सेटिंग में अनुमति दें, '
        'फिर दोबारा कोशिश करें — या नीचे कोड लिखें।',
  );
  String get cameraFailed => pick(
    'The camera did not start. Try again, or type the code below.',
    'कैमरा चालू नहीं हुआ। दोबारा कोशिश करें, या नीचे कोड लिखें।',
  );
  String get tryAgain => pick('Try again', 'दोबारा कोशिश करें');
  String get orTypeCode => pick('Or type the code', 'या कोड लिखें');
  String get codeFieldHint => pick('Paste the code here', 'कोड यहाँ पेस्ट करें');
  String get checkCode => pick('Check code', 'कोड जाँचें');
  String get codeMalformed => pick(
    'This is not a RapidRX caretaker code.',
    'यह RapidRX देखभालकर्ता का कोड नहीं है।',
  );
  String get codeVersion => pick(
    'This code is from a different version of RapidRX. Update the app on '
        'both phones.',
    'यह कोड RapidRX के दूसरे संस्करण का है। दोनों फ़ोन में ऐप अपडेट करें।',
  );
  String get codeChecksum => pick(
    'Part of this code is wrong. Scan it again, or check each letter.',
    'इस कोड का कुछ हिस्सा गलत है। दोबारा स्कैन करें, या हर अक्षर जाँचें।',
  );
  String get codeExpired => pick(
    'This code has expired. Ask the caretaker to make a new one.',
    'इस कोड का समय खत्म हो गया। देखभालकर्ता से नया कोड बनवाएँ।',
  );
  String get codeClock => pick(
    'The time on one of the phones is wrong. Check the time on both phones.',
    'किसी एक फ़ोन में समय गलत है। दोनों फ़ोन का समय जाँचें।',
  );
  String whoIsIt(String name, CaretakerType t) =>
      '$name — ${caretakerTypeLabel(t)}';
  String familySees(String name) => pick(
    '$name will see your medicines, health details and prescriptions, and '
        'get your alerts on WhatsApp.',
    '$name आपकी दवाइयाँ, सेहत की जानकारी और पर्चियाँ देख पाएँगे, और '
        'WhatsApp पर आपके अलर्ट पाएँगे।',
  );
  String commercialSees(String name) => pick(
    '$name will see today\'s doses, your schedule and notes — not your '
        'health details. You set a PIN they must enter.',
    '$name आज की दवाइयाँ, दवाई का समय और नोट देख पाएँगे — आपकी सेहत की '
        'जानकारी नहीं। आप एक PIN रखेंगे जो उन्हें डालना होगा।',
  );
  String linkName(String name) => pick('Link $name', '$name को जोड़ें');
  String get notThem =>
      pick('Not them? Scan again', 'ये नहीं हैं? दोबारा स्कैन करें');
  String pinForTitle(String name) =>
      pick('Set a PIN for $name', '$name के लिए PIN रखें');
  String pinForWhy(String name) => pick(
    '$name types this PIN each time they open your medicines. Tell it to '
        'them yourself.',
    '$name हर बार आपकी दवाइयाँ खोलते समय यह PIN डालेंगे। यह उन्हें आप '
        'खुद बताएँ।',
  );
  String get pinAgain => pick('Type the PIN again', 'PIN दोबारा लिखें');
  String get caretakerPinShort =>
      pick('The PIN has 4 digits', 'PIN 4 अंकों का है');
  String get caretakerPinMismatch =>
      pick('The two PINs are different.', 'दोनों PIN अलग हैं।');
  String showCodeTo(String name) => pick(
    'Show this code to $name. They type it on their phone, with your name, '
        'to finish.',
    'यह कोड $name को दिखाएँ। वे इसे आपके नाम के साथ अपने फ़ोन में डालेंगे, '
        'तब जुड़ाव पूरा होगा।',
  );
  String get sendCodeWhatsApp =>
      pick('Send the code on WhatsApp', 'कोड WhatsApp पर भेजें');
  String pairingWhatsApp(String patient, String code) => pick(
    'RapidRX: $patient linked you as their caretaker. Enter this code on '
        'your phone: $code',
    'RapidRX: $patient ने आपको देखभालकर्ता के रूप में जोड़ा है। अपने फ़ोन '
        'में यह कोड डालें: $code',
  );

  // ── Patient: the linked caretaker, in the account sheet ─────────────────
  String get yourCaretaker => pick('Your caretaker', 'आपके देखभालकर्ता');
  String get noCaretakerLinked => pick(
    'No caretaker linked yet.',
    'अभी कोई देखभालकर्ता नहीं जुड़ा है।',
  );
  String get unlink => pick('Unlink', 'हटाएँ');
  String unlinkQuestion(String name) =>
      pick('Unlink $name?', '$name को हटाएँ?');
  String get unlinkWhy => pick(
    'They will stop getting your alerts. You can scan their code again '
        'any time.',
    'उन्हें आपके अलर्ट मिलने बंद हो जाएँगे। आप कभी भी उनका कोड दोबारा स्कैन '
        'कर सकते हैं।',
  );
  String unlinked(String name) =>
      pick('$name is unlinked.', '$name को हटा दिया गया।');
}
