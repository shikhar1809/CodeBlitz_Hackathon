import 'app_strings.dart';

/// The Home Vault step, the family code, and the Winger calls. English and
/// Hindi side by side, like every string in the app.
extension FamilyStrings on AppStrings {
  // ── Home Vault ───────────────────────────────────────────────────────────
  String get vaultTitle => pick('Keep your family in the loop', 'अपने परिवार को साथ रखें');
  String get vaultWhy => pick(
    'Connect to the Winger Home Vault on your home computer. Your family '
        'sees your doses there. Everything is locked with a family code on '
        'this phone, so even the Vault cannot read it.',
    'अपने घर के कंप्यूटर पर Winger Home Vault से जुड़ें। परिवार वहाँ आपकी '
        'दवाई देख पाएगा। सब कुछ इस फ़ोन पर एक फ़ैमिली कोड से बंद होता है, '
        'इसलिए Vault भी इसे पढ़ नहीं सकता।',
  );
  String get vaultAddress => pick('Home Vault address', 'Home Vault का पता');
  String get vaultHint => pick('e.g. 192.168.1.20:8787', 'जैसे 192.168.1.20:8787');
  String get vaultConnect => pick('Connect', 'जोड़ें');
  String get vaultChecking => pick('Looking for your Home Vault…', 'आपका Home Vault ढूँढ रहे हैं…');
  String get vaultNotFound => pick(
    'No Home Vault answered at that address. Check it is running and on the same Wi-Fi.',
    'उस पते पर Home Vault नहीं मिला। देखें कि वह चालू है और उसी Wi-Fi पर है।',
  );
  String get vaultLater => pick('Not now', 'अभी नहीं');
  String get vaultConnected => pick('Connected to your Home Vault', 'आपके Home Vault से जुड़ गए');
  String get familyCodeTitle => pick('Your family code', 'आपका फ़ैमिली कोड');
  String get familyCodeWhy => pick(
    'Give this code to your family. They enter it in the family portal to '
        'see your doses. Anyone with it can see them, so share it only with '
        'family.',
    'यह कोड अपने परिवार को दें। वे इसे फ़ैमिली पोर्टल में डालकर आपकी दवाई '
        'देख सकते हैं। जिसके पास यह कोड है वह देख सकता है, इसलिए सिर्फ़ '
        'परिवार को दें।',
  );
  String get continueToApp => pick('Continue', 'आगे बढ़ें');

  // ── Winger calls ─────────────────────────────────────────────────────────
  String get callerName => pick('Winger', 'Winger');
  String get callIncoming => pick('Incoming call', 'आने वाली कॉल');
  String get callMedicine => pick('Medicine time', 'दवाई का समय');
  String get callCheckIn => pick('Daily check-in', 'रोज़ का हालचाल');
  String get callAnswer => pick('Answer', 'उठाएँ');
  String get callDecline => pick('Decline', 'काटें');
  String get callEnd => pick('End call', 'कॉल काटें');
  String get callConnecting => pick('Connecting…', 'जुड़ रहे हैं…');
  String get callTookThem => pick('I took them', 'मैंने ले ली');
  String get callLater => pick('Remind me later', 'बाद में याद दिलाएँ');
  String get callFeelGood => pick('I am fine', 'मैं ठीक हूँ');
  String get callFeelUnwell => pick('Not feeling well', 'तबियत ठीक नहीं');
  String get callNeedHelp => pick('Call my family', 'परिवार को बुलाएँ');
  String get callFamilyTold => pick('Your family has been told.', 'आपके परिवार को बता दिया गया है।');
  String get demoMedicineCall => pick('Medicine call', 'दवाई कॉल');
  String get demoCheckInCall => pick('Check-in call', 'हालचाल कॉल');

  String medicineLine(String name, List<String> medicines) => pick(
    'Namaste $name. This is Winger. It is time for your medicines: '
        '${medicines.join(', ')}. Have you taken them?',
    'नमस्ते $name। मैं Winger बोल रहा हूँ। आपकी दवाई का समय हो गया है: '
        '${medicines.join(', ')}। क्या आपने ले ली?',
  );

  String checkInLine(String name) => pick(
    'Namaste $name. This is Winger, calling to check on you. How are you feeling today?',
    'नमस्ते $name। मैं Winger, आपका हालचाल पूछने के लिए कॉल कर रहा हूँ। आज आप कैसा महसूस कर रहे हैं?',
  );

  String get thanksLine => pick('Thank you. Take care.', 'धन्यवाद। अपना ध्यान रखिए।');
  String get laterLine => pick(
    'All right, I will remind you again in a little while.',
    'ठीक है, थोड़ी देर में फिर याद दिलाऊँगा।',
  );
  String get unwellLine => pick(
    'I am sorry. I have told your family, they will call you soon.',
    'मुझे दुख है। मैंने आपके परिवार को बता दिया है, वे जल्द ही फ़ोन करेंगे।',
  );
}
