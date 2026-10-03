import 'app_strings.dart';

/// The pharmacy questions: asked the moment a doubt is found, in plain words.
///
/// Medicine names are passed in as printed and never translated.
extension PharmacyStrings on AppStrings {
  // ── Titles, one per kind of doubt ───────────────────────────────────────
  String get phSubstitutionTitle =>
      pick('A different medicine was given?', 'क्या दूसरी दवाई दी गई?');
  String get phStrengthTitle =>
      pick('The strength does not match', 'दवाई की ताकत मेल नहीं खाती');
  String get phNotPrescribedTitle =>
      pick('Sold, but not prescribed', 'दी गई, पर लिखी नहीं गई');
  String get phQuantityTitle => pick(
    'The number of tablets does not match',
    'गोलियों की गिनती मेल नहीं खाती',
  );
  String get phUnreadableTitle =>
      pick('One line could not be read', 'एक लाइन पढ़ी नहीं जा सकी');

  // ── The question, in a sentence ─────────────────────────────────────────
  String phSubstitutionAsk(String prescribed, String given) => pick(
    '$prescribed was prescribed, but $given was given in its place. '
        'Which one is right?',
    'लिखी गई थी $prescribed, पर उसकी जगह $given दी गई। कौन-सी सही है?',
  );
  String phStrengthAsk(String a, String b) => pick(
    'One source says $a, another says $b. Which strength is right?',
    'एक जगह $a लिखा है, दूसरी जगह $b। कौन-सी ताकत सही है?',
  );
  String phNotPrescribedAsk(String name) => pick(
    '$name is on the bill, but neither the doctor nor the prescription '
        'mentions it. Is it yours to take?',
    '$name बिल में है, पर डॉक्टर या पर्ची में इसका ज़िक्र नहीं है। '
        'क्या यह आपको लेनी है?',
  );
  String phQuantityAsk(String name, int sold, int needed, int days) => pick(
    'The bill has $sold tablets of $name. The course needs $needed, for '
        '$days days. Which is right?',
    'बिल में $name की $sold गोलियाँ हैं। कोर्स के लिए $needed चाहिए, '
        '$days दिन के लिए। कौन-सा सही है?',
  );
  String get phUnreadableAsk => pick(
    'This line looks like a medicine, but the phone could not read its '
        'name. What is it?',
    'यह लाइन दवाई जैसी लगती है, पर फ़ोन इसका नाम नहीं पढ़ पाया। यह क्या है?',
  );

  // ── The two readings ─────────────────────────────────────────────────────
  String get phNotMentioned =>
      pick('Doctor and prescription', 'डॉक्टर और पर्ची');
  String get phNotMentionedQuote => pick('Not mentioned', 'ज़िक्र नहीं');
  String phCourseDetail(int needed, int days) => pick(
    '$needed tablets for $days days',
    '$days दिन के लिए $needed गोलियाँ',
  );
  String phBillDetail(int sold, int days) => pick(
    '$sold tablets — lasts $days days',
    '$sold गोलियाँ — $days दिन चलेंगी',
  );
  String get phReadAs => pick('As read', 'जैसा पढ़ा गया');

  // ── Answers ──────────────────────────────────────────────────────────────
  String get phPickThis => pick('This one', 'यही सही');
  String get phTakeIt => pick('Yes, I take it', 'हाँ, लेनी है');
  String get phInList => pick(
    'It is already in the list',
    'यह सूची में पहले से है',
  );
  String get phNotMedicine => pick('It is not a medicine', 'यह दवाई नहीं है');
  String get phNeither =>
      pick('Neither — let me explain', 'दोनों नहीं — मुझे बताना है');
  String get phExplainHint => pick(
    'Say or write what happened',
    'बोलकर या लिखकर बताएँ क्या हुआ',
  );
  String get phRecordNote =>
      pick('Record a voice note', 'आवाज़ में नोट रिकॉर्ड करें');
  String get phNoteSaved => pick('Voice note saved', 'आवाज़ का नोट सेव हुआ');
  String get phSaveExplanation =>
      pick('Save my explanation', 'मेरी बात सेव करें');
  String get phNotSure => pick(
    'Not sure — ask the chemist later',
    'पक्का नहीं — बाद में केमिस्ट से पूछेंगे',
  );
  String get phDecideLater => pick('Decide later', 'बाद में तय करें');
  String get phWhoAnswers =>
      pick('Who is answering?', 'कौन जवाब दे रहा है?');
  String get phByPatient => pick('Patient', 'मरीज़');
  String get phByCaretaker => pick('Caretaker', 'देखभाल करने वाले');
  String get phByDoctor => pick('Doctor', 'डॉक्टर');

  // ── On the card, afterwards ──────────────────────────────────────────────
  String get phNotAnswered =>
      pick('Not answered yet', 'अभी जवाब नहीं दिया');
  String get phStillNotSure => pick(
    'Not sure yet — ask the chemist',
    'अभी पक्का नहीं — केमिस्ट से पूछें',
  );
  String phExplained(String text) => pick(
    'Your explanation: “$text”',
    'आपकी बात: “$text”',
  );
  String get phNeedsPick => pick(
    'Still needs a pick or an edit',
    'अभी भी चुनना या बदलना बाकी है',
  );
  String get phVoiceNoteKept =>
      pick('A voice note is kept', 'आवाज़ का नोट रखा है');
  String get phAnswered => pick('Answered', 'जवाब दिया');
  String get phAnswer => pick('Answer', 'जवाब दें');
  String phSameAs(String name, String other) => pick(
    '$name — the same medicine as $other',
    '$name — $other वाली ही दवाई',
  );
}
