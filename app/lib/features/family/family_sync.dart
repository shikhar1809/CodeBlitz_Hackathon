import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/dose_clock.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import 'family_crypto.dart';

/// Shares what the family needs with the Winger Home Vault (or the hosted
/// relay), end-to-end encrypted with the family code.
///
/// The phone stays the owner: the Vault is a mailbox that only ever holds
/// ciphertext. Every call fails quietly; nothing on the phone waits for it.
class FamilySync {
  FamilySync(this._prefs, {http.Client? client}) : _http = client ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _http;

  static const _urlKey = 'family.vault_url';
  static const _codeKey = 'family.code';
  static const _decidedKey = 'family.decided';
  static const timeout = Duration(seconds: 6);

  static Future<FamilySync> load() async => FamilySync(await SharedPreferences.getInstance());

  String? get vaultUrl => _prefs.getString(_urlKey);
  String? get familyCode => _prefs.getString(_codeKey);
  bool get connected => vaultUrl != null && familyCode != null;

  /// Asked once during onboarding: connected, or "later".
  bool get decided => _prefs.getBool(_decidedKey) ?? false;
  Future<void> later() => _prefs.setBool(_decidedKey, true);

  static String normalise(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    if (!RegExp(r':\d+').hasMatch(Uri.parse(u).authority) && u.startsWith('http://')) {
      u = '${u.replaceAll(RegExp(r'/+$'), '')}:8787';
    }
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  /// Is a Winger Home Vault answering at [url]?
  Future<bool> reachable(String url) async {
    try {
      final r = await _http.get(Uri.parse('${normalise(url)}/api/health')).timeout(timeout);
      return r.statusCode == 200 && (jsonDecode(r.body) as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Makes this phone's family code (once), claims the household on the
  /// Vault, and shares the first snapshot. Returns the code, or null.
  Future<String?> connect(String url) async {
    final base = normalise(url);
    final code = familyCode ?? FamilyCrypto.newCode();
    final k = await FamilyCrypto.derive(code);
    try {
      final r = await _http
          .post(Uri.parse('$base/api/households/${k.householdId}'),
              headers: {'Authorization': 'Bearer ${k.accessToken}'})
          .timeout(timeout);
      if (r.statusCode != 200) return null;
    } catch (_) {
      return null;
    }
    await _prefs.setString(_urlKey, base);
    await _prefs.setString(_codeKey, code);
    await _prefs.setBool(_decidedKey, true);
    unawaited(share());
    return code;
  }

  Future<void> disconnect() async {
    await _prefs.remove(_urlKey);
    await _prefs.remove(_codeKey);
  }

  /// Seals the family view and sends it. True when the Vault took it.
  Future<bool> share({DateTime? now}) async {
    if (!connected) return false;
    try {
      final k = await FamilyCrypto.derive(familyCode!);
      final snapshot = await buildSnapshot(_prefs, now: now ?? DateTime.now());
      final box = await FamilyCrypto.seal(k.dataKey, jsonEncode(snapshot), '${k.householdId}:snapshot');
      final r = await _http
          .put(
            Uri.parse('$vaultUrl/api/households/${k.householdId}/snapshot'),
            headers: {'Authorization': 'Bearer ${k.accessToken}', 'Content-Type': 'application/json'},
            body: jsonEncode(box.toJson()),
          )
          .timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Appends one event (an alert, a check-in) to the family timeline.
  Future<bool> event(Map<String, Object?> e) async {
    if (!connected) return false;
    try {
      final k = await FamilyCrypto.derive(familyCode!);
      final box = await FamilyCrypto.seal(k.dataKey, jsonEncode(e), '${k.householdId}:event');
      final r = await _http
          .post(
            Uri.parse('$vaultUrl/api/households/${k.householdId}/events'),
            headers: {'Authorization': 'Bearer ${k.accessToken}', 'Content-Type': 'application/json'},
            body: jsonEncode(box.toJson()),
          )
          .timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// What the family portal shows: who, what they take, today's doses and the
/// last two weeks. Only what a person already approved; no photos, no audio.
Future<Map<String, Object?>> buildSnapshot(SharedPreferences prefs, {required DateTime now}) async {
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  final meds = store.active();
  final today = DateTime(now.year, now.month, now.day);

  Map<String, Object?> med(ScheduledMedicine m) => {
        'name': m.name,
        'strength': m.strength,
        'slots': [for (final s in m.sig.slots) s.name],
        'food': m.sig.food.name,
        'durationDays': m.sig.durationDays,
        'sos': m.sig.sos,
        'purpose': m.purpose,
      };

  final todaySlots = [
    for (final e in ScheduleEngine.dueOn(meds, today).entries)
      {
        'slot': e.key.name,
        'dueAt': DoseClock.dueAt(today, e.key).toIso8601String(),
        'status': logs.statusOf(now, today, e.key).name,
        'medicines': [for (final m in e.value) m.name],
      },
  ];

  final days = [
    for (var i = 13; i >= 0; i--)
      () {
        final d = today.subtract(Duration(days: i));
        return {'date': d.toIso8601String().substring(0, 10), 'mark': logs.markFor(now, d, meds).name};
      }(),
  ];

  return {
    'v': 1,
    'at': now.toIso8601String(),
    'patient': {
      'name': prefs.getString('user_name'),
      'age': prefs.getInt('health_age'),
    },
    'medicines': [for (final m in meds) med(m)],
    'today': todaySlots,
    'days': days,
    'slotsOrder': [for (final s in DoseSlot.values) s.name],
  };
}
