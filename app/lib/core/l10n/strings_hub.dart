import '../../features/hub/hub_client.dart' show HubProblem, TimeOfDayChoice;
import 'app_strings.dart';

/// The Winger Hub: pairing with the computer at home, booking a doctor's
/// visit through it, and following the booking. Same rule as AppStrings:
/// English and Hindi side by side.
///
/// Department names go to the clinic's website in English; only their labels
/// here are translated.
extension HubStrings on AppStrings {
  // ── Connecting ──────────────────────────────────────────────────────────
  String get homeHub => pick('Home Hub', 'घर का Hub');
  String get hubConnectWhy => pick(
    'Connect to your Winger Hub at home (a spare computer running the Hub '
        'app)',
    'घर के Winger Hub से जुड़ें (एक अलग कंप्यूटर जिस पर Hub ऐप चल रहा है)',
  );
  String get hubScanTitle =>
      pick('Scan the code on the Hub', 'Hub पर दिख रहा कोड स्कैन करें');
  String get hubOrType => pick(
    'Or type the address and code from the Hub\'s screen:',
    'या Hub की स्क्रीन से पता और कोड लिखें:',
  );
  String get hubAddressHint =>
      pick('Address, like 192.168.1.20', 'पता, जैसे 192.168.1.20');
  String get hubCodeHint => pick('6-digit code', '6 अंकों का कोड');
  String get hubConnect => pick('Connect', 'जोड़ें');
  String get hubConnecting => pick('Connecting…', 'जोड़ रहे हैं…');
  String get hubBadQr =>
      pick('This is not a Winger Hub code.', 'यह Winger Hub का कोड नहीं है।');
  String get hubBadTyped => pick(
    'Check the address and the 6-digit code.',
    'पता और 6 अंकों का कोड जाँचें।',
  );
  String get hubWebNote => pick(
    'In the browser, only a Hub on this same computer can be reached. '
        'Use the Android app for a Hub elsewhere at home.',
    'ब्राउज़र में सिर्फ़ इसी कंप्यूटर पर चल रहा Hub जुड़ता है। '
        'घर के दूसरे कंप्यूटर के Hub के लिए Android ऐप इस्तेमाल करें।',
  );

  /// How the Hub lists this phone.
  String hubDeviceName(String? name) {
    final n = name?.trim() ?? '';
    return n.isEmpty
        ? pick('Winger phone', 'Winger फ़ोन')
        : pick('$n\'s phone', '$n का फ़ोन');
  }

  String hubProblem(HubProblem p) => switch (p) {
    HubProblem.unreachable => pick(
      'Cannot reach the Hub. Is the Hub computer on, and is this phone on '
          'the same Wi-Fi?',
      'Hub से संपर्क नहीं हो पा रहा। क्या Hub वाला कंप्यूटर चालू है, और यह '
          'फ़ोन उसी Wi-Fi पर है?',
    ),
    HubProblem.wrongCode => pick(
      'That code is wrong or has expired. Get a new one on the Hub.',
      'यह कोड गलत है या इसका समय खत्म हो गया। Hub पर नया कोड लें।',
    ),
    HubProblem.tooManyTries => pick(
      'Too many tries. Wait a minute, then try again.',
      'बहुत बार कोशिश हुई। एक मिनट रुककर फिर करें।',
    ),
    HubProblem.unlinked => pick(
      'This phone was removed from the Hub. Connect again.',
      'यह फ़ोन Hub से हटा दिया गया है। फिर से जोड़ें।',
    ),
    HubProblem.badReply => pick(
      'That address is not a Winger Hub.',
      'यह पता Winger Hub का नहीं है।',
    ),
    HubProblem.failed => pick(
      'The Hub could not do that. Try again.',
      'Hub यह नहीं कर पाया। फिर से कोशिश करें।',
    ),
  };

  // ── Connected ───────────────────────────────────────────────────────────
  String hubConnectedTo(String name) =>
      pick('Connected to $name', '$name से जुड़ा है');
  String get hubAddress => pick('Address', 'पता');
  String get hubDisconnect => pick('Disconnect', 'हटाएँ');
  String get hubChecking => pick('Checking the Hub…', 'Hub जाँच रहे हैं…');
  String get hubReady =>
      pick('The Hub is on and ready.', 'Hub चालू है और तैयार है।');
  String get hubAgentStarting => pick(
    'The Hub is on, but its AI is still starting.',
    'Hub चालू है, पर उसका AI अभी शुरू हो रहा है।',
  );
  String get hubNotConnected =>
      pick('No Hub connected', 'कोई Hub जुड़ा नहीं है');
  String get hubDisconnected => pick(
    'Disconnected. The Hub can remove this phone from its list too.',
    'हटा दिया। Hub पर भी इस फ़ोन को सूची से हटा सकते हैं।',
  );

  // ── Booking a visit ─────────────────────────────────────────────────────
  String get bookVisit => pick('Book a doctor\'s visit', 'डॉक्टर का समय लें');
  String get bookVisitWhy =>
      pick('Your Home Hub books it online', 'घर का Hub ऑनलाइन बुक करेगा');
  String get bookWhy => pick(
    'Fill in what you know. The Hub asks you before it books anything.',
    'जो पता है वो भरें। बुक करने से पहले Hub आपसे पूछेगा।',
  );
  String get clinicWebsite => pick('Clinic website', 'क्लिनिक की वेबसाइट');
  String get clinicWebsiteInvalid => pick(
    'Write the clinic\'s website, starting with https://',
    'क्लिनिक की वेबसाइट लिखें, https:// से शुरू करके',
  );
  String get department => pick('Department', 'विभाग');
  String departmentLabel(String english) => switch (english) {
    'General Medicine' => pick('General Medicine', 'सामान्य चिकित्सा'),
    'Diabetes & Endocrinology' => pick(
      'Diabetes & Endocrinology',
      'डायबिटीज़ और हार्मोन',
    ),
    'Cardiology' => pick('Cardiology (heart)', 'हृदय रोग'),
    'Orthopaedics' => pick('Orthopaedics (bones)', 'हड्डी रोग'),
    'Eye Care' => pick('Eye Care', 'आँखों की जाँच'),
    'ENT' => pick('ENT (ear, nose, throat)', 'नाक, कान, गला'),
    _ => english,
  };
  String get doctorName => pick('Doctor\'s name', 'डॉक्टर का नाम');
  String get preferredDay => pick('Which day?', 'कौन-सा दिन?');
  String get anyDay => pick('Any day', 'कोई भी दिन');
  String get chooseDay => pick('Choose a day', 'दिन चुनें');
  String get timeOfDayQuestion => pick('What time of day?', 'दिन में कब?');
  String timeOfDayLabel(TimeOfDayChoice t) => switch (t) {
    TimeOfDayChoice.morning => pick('Morning', 'सुबह'),
    TimeOfDayChoice.afternoon => pick('Afternoon', 'दोपहर'),
    TimeOfDayChoice.evening => pick('Evening', 'शाम'),
    TimeOfDayChoice.any => pick('Any time', 'कभी भी'),
  };
  String get visitReason => pick('Reason for the visit', 'मिलने की वजह');
  String get visitReasonHint =>
      pick('e.g. sugar check-up', 'जैसे शुगर की जाँच');
  String get patientDetails => pick('Patient', 'मरीज़');
  String get patientNameHint => pick('Patient\'s name', 'मरीज़ का नाम');
  String get patientNameMissing =>
      pick('Please write the patient\'s name', 'कृपया मरीज़ का नाम लिखें');
  String get ageHint => pick('Age', 'उम्र');
  String get gender => pick('Gender', 'लिंग');
  String get female => pick('Female', 'महिला');
  String get male => pick('Male', 'पुरुष');
  String get otherGender => pick('Other', 'अन्य');
  String get genderMissing =>
      pick('Choose Female, Male or Other', 'महिला, पुरुष या अन्य चुनें');
  String get askHubToBook => pick('Ask the Hub to book', 'Hub से बुक करवाएँ');
  String get sendingToHub => pick('Sending to the Hub…', 'Hub को भेज रहे हैं…');

  /// "5 Oct 2026", without the intl package.
  String shortDate(DateTime d) {
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const hi = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून', //
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
    ];
    return '${d.day} ${pick(en[d.month - 1], hi[d.month - 1])} ${d.year}';
  }

  // ── Following the booking ───────────────────────────────────────────────
  String get bookingTitle =>
      pick('Booking your visit', 'आपका समय बुक हो रहा है');
  String get bookingQueued =>
      pick('Waiting for the Hub to start…', 'Hub के शुरू करने का इंतज़ार…');
  String get bookingRunning => pick(
    'The Hub is filling in the clinic\'s form…',
    'Hub क्लिनिक का फ़ॉर्म भर रहा है…',
  );
  String get hubAsks =>
      pick('The Hub needs something from you', 'Hub को आपसे कुछ चाहिए');
  String get answerHint => pick('Type it here', 'यहाँ लिखें');
  String get send => pick('Send', 'भेजें');
  String get sentWaiting =>
      pick('Sent. Waiting for the Hub…', 'भेज दिया। Hub का इंतज़ार…');
  String get approveTitle =>
      pick('Check before booking', 'बुक करने से पहले जाँचें');
  String get approveWhy => pick(
    'Nothing is booked until you say yes.',
    'आपके हाँ कहे बिना कुछ भी बुक नहीं होगा।',
  );
  String get yesBookIt => pick('Yes, book it', 'हाँ, बुक करें');
  String get noStop => pick('No, stop', 'नहीं, रोकें');
  String get bookedTitle => pick('Your visit is booked', 'आपका समय बुक हो गया');
  String get bookingFailedTitle =>
      pick('The booking did not go through', 'बुकिंग नहीं हो पाई');
  String get bookingStoppedTitle => pick('Booking stopped', 'बुकिंग रोक दी');
  String get bookingStoppedWhy =>
      pick('Nothing was booked.', 'कुछ भी बुक नहीं हुआ।');
  String get hubTryAgain => pick('Try again', 'फिर से कोशिश करें');
  String get stopBooking => pick('Stop', 'रोकें');
  String get stillTrying => pick(
    'Cannot reach the Hub. Still trying…',
    'Hub से संपर्क नहीं हो रहा। कोशिश जारी है…',
  );
  String get whatHubDid => pick('What the Hub did', 'Hub ने क्या किया');
  String get finished => pick('Done', 'हो गया');
}
