import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/storage/app_prefs.dart';

/// Why a call to the Hub did not work. Each one has its own sentence on
/// screen, because "something went wrong" helps nobody at home.
enum HubProblem {
  /// No answer: the Hub laptop is off, asleep, or on another Wi-Fi.
  unreachable,

  /// 403 on pairing: the code was mistyped or has expired.
  wrongCode,

  /// 429 on pairing: the Hub stopped listening for a while.
  tooManyTries,

  /// 401: this phone was removed on the Hub. The stored link is gone.
  unlinked,

  /// An answer that is not the contract: a different server on that port.
  badReply,

  /// Any other status from the Hub.
  failed,
}

class HubException implements Exception {
  const HubException(this.problem, [this.detail]);

  final HubProblem problem;

  /// The Hub's own `error` text, when it sent one. For logs, not for screens.
  final String? detail;

  @override
  String toString() =>
      'HubException($problem${detail == null ? '' : ': $detail'})';
}

/// `GET /api/health`.
class HubHealth {
  const HubHealth({
    required this.version,
    required this.agentReady,
    this.model,
  });

  final String version;

  /// The local AI model is loaded and the browser agent can take a job.
  final bool agentReady;
  final String? model;
}

/// What `POST /api/pair` hands back.
class HubPairResult {
  const HubPairResult({
    required this.deviceId,
    required this.token,
    required this.hubName,
    required this.hubVersion,
  });

  final String deviceId;
  final String token;
  final String hubName;
  final String hubVersion;
}

/// A job's state, as the Hub names it.
enum HubJobStatus {
  queued,
  running,
  needsInput,
  needsApproval,
  done,
  failed,
  cancelled;

  static HubJobStatus fromWire(String? s) => switch (s) {
    'queued' => queued,
    'running' => running,
    'needs_input' => needsInput,
    'needs_approval' => needsApproval,
    'done' => done,
    'failed' => failed,
    'cancelled' => cancelled,
    // A status from a newer Hub: keep watching rather than stop.
    _ => running,
  };

  /// Nothing more will happen: stop polling.
  bool get isFinal => this == done || this == failed || this == cancelled;
}

class HubStep {
  const HubStep({required this.at, required this.text});

  final DateTime at;
  final String text;
}

/// What the agent is about to submit, for the person to say yes or no to.
class HubApproval {
  const HubApproval({required this.summary, required this.fields});

  final String summary;
  final List<({String label, String value})> fields;
}

/// `GET /api/agent/jobs/<id>`.
class HubJob {
  const HubJob({
    required this.id,
    required this.status,
    this.steps = const [],
    this.question,
    this.approval,
    this.result,
    this.error,
  });

  final String id;
  final HubJobStatus status;
  final List<HubStep> steps;

  /// Set while [status] is needs_input — usually "the OTP sent to …".
  final String? question;

  /// Set while [status] is needs_approval.
  final HubApproval? approval;

  /// What was booked, in the Hub's words.
  final String? result;
  final String? error;

  factory HubJob.fromJson(Map<String, Object?> j) {
    final approval = j['approval'];
    return HubJob(
      id: '${j['id']}',
      status: HubJobStatus.fromWire(j['status'] as String?),
      steps: [
        for (final s in (j['steps'] as List?) ?? const [])
          if (s is Map)
            HubStep(
              at: DateTime.fromMillisecondsSinceEpoch(
                (s['at'] as num?)?.toInt() ?? 0,
              ),
              text: '${s['text'] ?? ''}',
            ),
      ],
      question: _text(j['question']),
      approval: approval is Map
          ? HubApproval(
              summary: '${approval['summary'] ?? ''}',
              fields: [
                for (final f in (approval['fields'] as List?) ?? const [])
                  if (f is Map)
                    (
                      label: '${f['label'] ?? ''}',
                      value: '${f['value'] ?? ''}',
                    ),
              ],
            )
          : null,
      result: _text(j['result']),
      error: _text(j['error']),
    );
  }

  /// The contract leaves `result` loose: a sentence, or a small object. An
  /// object is shown as "key: value" lines rather than dropped.
  static String? _text(Object? v) => switch (v) {
    null => null,
    String s when s.trim().isEmpty => null,
    String s => s,
    Map m => [for (final e in m.entries) '${e.key}: ${e.value}'].join('\n'),
    _ => '$v',
  };
}

enum TimeOfDayChoice { morning, afternoon, evening, any }

/// Everything the Hub's agent needs to fill in a clinic's booking form.
class BookingRequest {
  const BookingRequest({
    required this.url,
    required this.patientName,
    this.patientAge,
    required this.patientGender,
    required this.patientPhone,
    required this.department,
    this.doctor = '',
    this.date,
    this.timeOfDay = TimeOfDayChoice.any,
    this.reason = '',
  });

  final String url;
  final String patientName;
  final int? patientAge;

  /// Female, Male or Other — as the clinic's form says it.
  final String patientGender;
  final String patientPhone;

  /// In English, as the clinic's site lists it, whatever the app language.
  final String department;
  final String doctor;

  /// Null for "any day".
  final DateTime? date;
  final TimeOfDayChoice timeOfDay;
  final String reason;

  static String wireDate(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'kind': 'book_appointment',
    'url': url,
    'patient': {
      'name': patientName,
      'age': patientAge,
      'gender': patientGender,
      'phone': patientPhone,
    },
    'request': {
      'department': department,
      'doctor': doctor,
      'date': wireDate(date),
      'timeOfDay': timeOfDay.name,
      'reason': reason,
    },
  };
}

/// The phone's side of the Winger Hub HTTP API.
///
/// The Hub is a spare computer at home, on the same Wi-Fi, so this is plain
/// HTTP to a LAN address. Android allows that because the manifest sets
/// `usesCleartextTraffic`. On the web build, a page served over https may
/// only call `http://localhost` (a Hub on the same computer as the browser):
/// the browser blocks http calls to a LAN address as mixed content.
///
/// Every route except health and pair carries the bearer token. A 401 means
/// the phone was removed on the Hub: [onUnlinked] runs (it forgets the stored
/// link) and the call throws [HubProblem.unlinked].
class HubClient {
  HubClient({
    required this.baseUrl,
    this.token,
    http.Client? client,
    this.onUnlinked,
    this.timeout = const Duration(seconds: 8),
  }) : _http = client ?? http.Client();

  /// The client for the Hub this phone is paired with, or null when it is
  /// not paired. A 401 clears the link in [prefs].
  static HubClient? fromPrefs(AppPrefs prefs, {http.Client? client}) {
    final url = prefs.hubUrl;
    final token = prefs.hubToken;
    if (url == null || token == null) return null;
    return HubClient(
      baseUrl: url,
      token: token,
      client: client,
      onUnlinked: prefs.clearHubLink,
    );
  }

  final String baseUrl;
  final String? token;
  final Future<void> Function()? onUnlinked;
  final Duration timeout;
  final http.Client _http;

  Future<HubHealth> health() async {
    final j = await _call('GET', '/api/health', auth: false);
    if (j['hub'] != 'winger') throw const HubException(HubProblem.badReply);
    final agent = j['agent'];
    return HubHealth(
      version: '${j['version'] ?? ''}',
      agentReady: agent is Map && agent['ready'] == true,
      model: agent is Map ? agent['model'] as String? : null,
    );
  }

  /// Trade the six-digit code for a token. [deviceName] is how the Hub lists
  /// this phone, e.g. "Ramesh's phone".
  Future<HubPairResult> pair({
    required String code,
    required String deviceName,
  }) async {
    final j = await _call(
      'POST',
      '/api/pair',
      body: {'code': code, 'name': deviceName},
      auth: false,
      pairing: true,
    );
    final hub = j['hub'];
    final deviceId = j['deviceId'];
    final token = j['token'];
    if (deviceId is! String || token is! String || token.isEmpty) {
      throw const HubException(HubProblem.badReply);
    }
    return HubPairResult(
      deviceId: deviceId,
      token: token,
      hubName: hub is Map ? '${hub['name'] ?? ''}' : '',
      hubVersion: hub is Map ? '${hub['version'] ?? ''}' : '',
    );
  }

  /// Who the Hub thinks this phone is. Also the cheapest "am I still
  /// paired?" check.
  Future<({String deviceId, String name})> me() async {
    final j = await _call('GET', '/api/me');
    return (deviceId: '${j['deviceId'] ?? ''}', name: '${j['name'] ?? ''}');
  }

  /// Returns the job id.
  Future<String> startBooking(BookingRequest request) async {
    final j = await _call('POST', '/api/agent/jobs', body: request.toJson());
    final id = j['id'];
    if (id == null || '$id'.isEmpty) {
      throw const HubException(HubProblem.badReply);
    }
    return '$id';
  }

  Future<HubJob> job(String id) async =>
      HubJob.fromJson(await _call('GET', '/api/agent/jobs/${_seg(id)}'));

  /// Answer the agent's question — usually the OTP the clinic sent.
  Future<void> answer(String id, String text) =>
      _call('POST', '/api/agent/jobs/${_seg(id)}/answer', body: {'text': text});

  /// The human safety gate. Only ever called from a person's tap.
  Future<void> approve(String id, {required bool approve}) => _call(
    'POST',
    '/api/agent/jobs/${_seg(id)}/approve',
    body: {'approve': approve},
  );

  Future<void> cancel(String id) =>
      _call('POST', '/api/agent/jobs/${_seg(id)}/cancel', body: const {});

  void close() => _http.close();

  static String _seg(String id) => Uri.encodeComponent(id);

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool pairing = false,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (auth) {
      final t = token;
      // No token is the same as a removed one: pair again.
      if (t == null) throw const HubException(HubProblem.unlinked);
      request.headers['Authorization'] = 'Bearer $t';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const HubException(HubProblem.unreachable);
    } on http.ClientException catch (e) {
      throw HubException(HubProblem.unreachable, e.message);
    }

    final Object? decoded;
    try {
      // UTF-8 whatever the header says: step text may well be Hindi, and
      // `response.body` falls back to Latin-1 without a charset.
      final text = utf8.decode(response.bodyBytes);
      decoded = text.isEmpty ? const {} : jsonDecode(text);
    } on FormatException {
      throw HubException(HubProblem.badReply, 'HTTP ${response.statusCode}');
    }
    final j = decoded is Map
        ? decoded.cast<String, Object?>()
        : const <String, Object?>{};
    final detail = j['error'] as String?;

    switch (response.statusCode) {
      case >= 200 && < 300:
        if (decoded is! Map) throw const HubException(HubProblem.badReply);
        return j;
      case 401 when auth:
        await onUnlinked?.call();
        throw HubException(HubProblem.unlinked, detail);
      case 403 when pairing:
        throw HubException(HubProblem.wrongCode, detail);
      case 429:
        throw HubException(HubProblem.tooManyTries, detail);
      default:
        throw HubException(
          HubProblem.failed,
          detail ?? 'HTTP ${response.statusCode}',
        );
    }
  }
}
