import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';

enum ChunkKind { gps, audio, photo, note }

/// One encrypted piece of evidence, linked to the one before by hash.
class EvidenceChunk {
  final int index;
  final ChunkKind kind;
  final DateTime at;
  final String prevHash;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
  final String hash;

  EvidenceChunk({
    required this.index,
    required this.kind,
    required this.at,
    required this.prevHash,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.hash,
  });

  static String computeHash(int index, ChunkKind kind, DateTime at,
      String prevHash, List<int> nonce, List<int> cipherText, List<int> mac) {
    final b = BytesBuilder()
      ..add(utf8.encode('$index|${kind.name}|${at.toUtc().toIso8601String()}|$prevHash|'))
      ..add(nonce)
      ..add(cipherText)
      ..add(mac);
    return c.sha256.convert(b.toBytes()).toString();
  }

  bool get selfConsistent =>
      hash == computeHash(index, kind, at, prevHash, nonce, cipherText, mac);

  Map<String, dynamic> toJson() => {
        'i': index,
        'k': kind.name,
        't': at.toUtc().toIso8601String(),
        'p': prevHash,
        'n': base64.encode(nonce),
        'c': base64.encode(cipherText),
        'm': base64.encode(mac),
        'h': hash,
      };

  factory EvidenceChunk.fromJson(Map<String, dynamic> j) => EvidenceChunk(
        index: j['i'] as int,
        kind: ChunkKind.values.byName(j['k'] as String),
        at: DateTime.parse(j['t'] as String),
        prevHash: j['p'] as String,
        nonce: base64.decode(j['n'] as String),
        cipherText: base64.decode(j['c'] as String),
        mac: base64.decode(j['m'] as String),
        hash: j['h'] as String,
      );
}

/// AES-256-GCM chunks in a SHA-256 hash chain. Any edit, removal or reorder
/// breaks [verify].
class EvidenceChain {
  static const genesis = '0000000000000000000000000000000000000000000000000000000000000000';
  static final _aes = AesGcm.with256bits();

  final SecretKey key;
  final List<EvidenceChunk> chunks;

  EvidenceChain(this.key, [List<EvidenceChunk>? chunks]) : chunks = chunks ?? [];

  static Future<EvidenceChain> create() async =>
      EvidenceChain(await _aes.newSecretKey());

  String get head => chunks.isEmpty ? genesis : chunks.last.hash;

  Future<EvidenceChunk> append(ChunkKind kind, List<int> data,
      {DateTime? at}) async {
    final when = at ?? DateTime.now();
    final box = await _aes.encrypt(data, secretKey: key);
    final i = chunks.length;
    final chunk = EvidenceChunk(
      index: i,
      kind: kind,
      at: when,
      prevHash: head,
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
      hash: EvidenceChunk.computeHash(
          i, kind, when, head, box.nonce, box.cipherText, box.mac.bytes),
    );
    chunks.add(chunk);
    return chunk;
  }

  Future<List<int>> open(EvidenceChunk c) => _aes.decrypt(
      SecretBox(c.cipherText, nonce: c.nonce, mac: Mac(c.mac)),
      secretKey: key);

  /// True when every chunk hashes correctly and links to the one before.
  static bool verify(List<EvidenceChunk> chunks) {
    var prev = genesis;
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      if (c.index != i || c.prevHash != prev || !c.selfConsistent) return false;
      prev = c.hash;
    }
    return true;
  }
}
