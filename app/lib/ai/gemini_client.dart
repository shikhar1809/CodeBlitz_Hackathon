import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/mention.dart';
import '../domain/sig_parser.dart';
import 'ai_config.dart';

/// One medicine as the model read it.
class ReadMedicine {
  const ReadMedicine({
    required this.name,
    this.strength = '',
    this.instruction = '',
    this.raw = '',
    this.uncertain = false,
  });

  final String name;
  final String strength;
  final String instruction;
  final String raw;
  final bool uncertain;

  factory ReadMedicine.fromJson(Map<String, Object?> j) => ReadMedicine(
    name: (j['name'] as String? ?? '').trim(),
    strength: (j['strength'] as String? ?? '').trim(),
    instruction: (j['instruction'] as String? ?? '').trim(),
    raw: (j['raw'] as String? ?? '').trim(),
    uncertain: j['uncertain'] == true,
  );
}

class HandwritingReading {
  const HandwritingReading(this.medicines, this.notes);

  final List<ReadMedicine> medicines;
  final List<String> notes;

  /// Into the same merge as everything else, with no extra trust. The name is
  /// re-parsed so it lines up with the bill; the instruction goes through the
  /// same SigParser as every other source.
  List<Mention> toMentions() => [
    for (final m in medicines)
      if (m.name.isNotEmpty) _mention(m),
  ];

  static Mention _mention(ReadMedicine m) {
    final line = '${m.name} ${m.strength} ${m.instruction}'.trim();
    final parsed = SigParser.parseLine(line);
    return Mention(
      source: SourceKind.prescription,
      name: parsed.name ?? m.name.toUpperCase(),
      strength: parsed.strength,
      sig: parsed.sig,
      raw: m.raw.isNotEmpty ? m.raw : line,
      purpose: parsed.purpose,
      uncertain: m.uncertain,
      readOnline: true,
    );
  }
}

enum GeminiFailure { notConfigured, overBudget, timedOut, rejected, unreadable }

class GeminiException implements Exception {
  const GeminiException(this.failure, [this.detail]);

  final GeminiFailure failure;
  final String? detail;

  @override
  String toString() =>
      'GeminiException($failure${detail == null ? '' : ': $detail'})';
}

/// Gemini reads handwriting, and nothing else (ADR-35).
///
/// Temperature 0: the same photo must not produce a different list on the
/// second run, mid-demo. A budget of four calls per visit, and a 45 second
/// timeout. The prompt does more work than the model choice.
class GeminiClient {
  GeminiClient({
    http.Client? client,
    String? apiKey,
    this.model = AiConfig.handwritingModel,
    this.budget = AiConfig.callsPerVisit,
    this.timeout = AiConfig.timeout,
  }) : _injected = client,
       _key = apiKey ?? AiConfig.geminiKey;

  final String _key;
  final String model;
  final int budget;
  final Duration timeout;

  final http.Client? _injected;
  http.Client? _lazy;
  http.Client get _http => _injected ?? (_lazy ??= http.Client());

  int _calls = 0;
  int get callsUsed => _calls;
  bool get configured => _key.isNotEmpty;
  bool get hasBudget => _calls < budget;

  static const prompt = '''
You are reading a doctor's handwritten prescription from India.

Return JSON only, in exactly this shape:
{"medicines":[{"name":"","strength":"","instruction":"","raw":"","uncertain":false}],"notes":[""]}

Rules:
- "name": the medicine name in English letters, exactly as written. Leave out
  the dosage form word: "Tab Telma 40" is "Telma 40". Never translate or
  expand a brand name. Never replace a brand with its generic.
- "strength": the number and unit if written ("40 mg"), else "".
- "instruction": the dosing instruction as written, in shorthand if it was
  written in shorthand ("1-0-1 p/c x 10 days", "BD", "HS", "SOS").
- "raw": the full line exactly as you read it.
- "uncertain": true if ANY part of the line is hard to read. Do not guess:
  a missing field is far better than a wrong one, because a person checks
  every row.
- Anything that is not a medicine (advice, tests, follow-up) goes in "notes".
- If nothing can be read, return {"medicines":[],"notes":[]}. Do not guess.
''';

  Future<HandwritingReading> readPrescription(
    Uint8List image, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!configured) throw const GeminiException(GeminiFailure.notConfigured);
    if (!hasBudget) throw const GeminiException(GeminiFailure.overBudget);
    _calls++;

    final uri = Uri.parse(
      '${AiConfig.endpoint}/v1beta/models/$model:generateContent?key=$_key',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(image),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    });

    final http.Response r;
    try {
      r = await _http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException(GeminiFailure.timedOut);
    }
    if (r.statusCode != 200) {
      throw GeminiException(GeminiFailure.rejected, 'HTTP ${r.statusCode}');
    }
    return parseResponse(r.body);
  }

  /// Unwrap candidates[0].content.parts[*].text, strip ``` fences, parse.
  static HandwritingReading parseResponse(String body) {
    try {
      final j = jsonDecode(body) as Map<String, Object?>;
      final parts =
          (((j['candidates'] as List).first as Map)['content'] as Map)['parts']
              as List;
      final text = parts
          .map((p) => (p as Map)['text'] as String? ?? '')
          .join()
          .trim()
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
      final data = jsonDecode(text) as Map<String, Object?>;
      return HandwritingReading(
        [
          for (final m in data['medicines'] as List? ?? const [])
            ReadMedicine.fromJson((m as Map).cast<String, Object?>()),
        ],
        [
          for (final n in data['notes'] as List? ?? const [])
            if ((n as String).trim().isNotEmpty) n.trim(),
        ],
      );
    } catch (e) {
      throw GeminiException(GeminiFailure.unreadable, '$e');
    }
  }
}
