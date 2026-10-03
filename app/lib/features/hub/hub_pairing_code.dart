/// The port the Hub app listens on unless its owner changed it.
const defaultHubPort = 8787;

/// What the Hub's pairing QR carries: where it is, a one-time code, and its
/// name.
///
/// The QR text is `winger-hub:1?u=<base url>&c=<6 digits>&n=<hub name>`, with
/// `u` and `n` URL-encoded. The same two things — address and code — can be
/// typed by hand, so both ways end here.
class HubPairingCode {
  const HubPairingCode({
    required this.baseUrl,
    required this.code,
    required this.hubName,
  });

  /// Normalised by [normaliseHubUrl]: scheme, host and port, no trailing slash.
  final String baseUrl;

  /// Six digits, valid for a few minutes on the Hub.
  final String code;

  /// Shown until the Hub answers with its own name.
  final String hubName;

  static const scheme = 'winger-hub';

  /// The only QR version this phone understands.
  static const version = '1';

  static final _sixDigits = RegExp(r'^\d{6}$');

  /// Null for anything that is not a version-1 Hub QR with an address and a
  /// six-digit code. The name is optional: an old Hub without one is still a
  /// Hub.
  static HubPairingCode? parse(String raw) {
    final Uri uri;
    try {
      uri = Uri.parse(raw.trim());
    } on FormatException {
      return null;
    }
    if (uri.scheme != scheme || uri.path != version) return null;
    final String? u, c, n;
    try {
      // queryParameters throws on a malformed percent-escape.
      u = uri.queryParameters['u'];
      c = uri.queryParameters['c'];
      n = uri.queryParameters['n'];
    } on FormatException {
      return null;
    }
    return typed(address: u ?? '', code: c ?? '', hubName: n);
  }

  /// The address and code as a person typed them. Null when either is wrong.
  static HubPairingCode? typed({
    required String address,
    required String code,
    String? hubName,
  }) {
    final url = normaliseHubUrl(address);
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (url == null || !_sixDigits.hasMatch(digits)) return null;
    final name = hubName?.trim() ?? '';
    return HubPairingCode(
      baseUrl: url,
      code: digits,
      hubName: name.isEmpty ? 'Winger Hub' : name,
    );
  }
}

/// `192.168.1.20` → `http://192.168.1.20:8787`. A person types the address
/// off the Hub's screen, so the scheme and the default port are optional.
/// Null when there is no host, or the scheme is not http(s).
String? normaliseHubUrl(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final Uri uri;
  try {
    uri = Uri.parse(text);
  } on FormatException {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : defaultHubPort;
  // Only the origin: the routes are added by the client.
  return Uri(scheme: uri.scheme, host: uri.host, port: port).toString();
}
