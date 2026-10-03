import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage/app_prefs.dart';
import '../sync/sync_queue.dart';
import '../sync/sync_service.dart';
import 'health_profile.dart';
import 'pmjay_client.dart';

enum PmjayState {
  idle,
  fetching,
  found,
  notFound,
  badFormat,
  confirmed,

  /// No signal: the lookup waits in the sync queue.
  queued,
}

/// The health screen's decisions, with no widgets: validation, the PM-JAY
/// lookup, and the "yes, this is me" confirmation.
class HealthProfileController extends ChangeNotifier {
  HealthProfileController({required this.prefs, PmjayClient? pmjay, this.sync})
    : pmjay = pmjay ?? MockPmjayClient();

  final AppPrefs prefs;
  final PmjayClient pmjay;

  /// With no signal, the lookup is queued rather than failed.
  final SyncService? sync;

  PmjayState state = PmjayState.idle;
  AyushmanCard? card;

  HealthError? ageError;
  HealthError? heightError;
  HealthError? weightError;

  Future<void> fetch(String id) async {
    if (!PmjayClient.validFormat(id)) {
      state = PmjayState.badFormat;
      card = null;
      notifyListeners();
      return;
    }
    final s = sync;
    if (s != null && !await s.network.isOnline()) {
      await s.enqueue(
        SyncJob(
          id: 'pmjay',
          kind: 'pmjay',
          payload: {'id': PmjayClient.clean(id)},
          createdAt: DateTime.now(),
        ),
      );
      await s.savedOffline();
      state = PmjayState.queued;
      card = null;
      notifyListeners();
      return;
    }
    state = PmjayState.fetching;
    card = null;
    notifyListeners();
    final result = await pmjay.fetch(id);
    switch (result) {
      case PmjayFound(:final card):
        this.card = card;
        state = PmjayState.found;
      case PmjayNotFound():
        state = PmjayState.notFound;
      case PmjayBadFormat():
        state = PmjayState.badFormat;
    }
    notifyListeners();
  }

  /// Nothing is saved until the patient says the card is theirs.
  void confirmCard() {
    if (card == null) return;
    state = PmjayState.confirmed;
    notifyListeners();
  }

  void rejectCard() {
    card = null;
    state = PmjayState.idle;
    notifyListeners();
  }

  /// Validate and save. Returns false, with errors set, when something is
  /// wrong; nothing is written until everything is right.
  Future<bool> submit({
    required String age,
    required String height,
    required String weight,
    required String ayushmanId,
  }) async {
    ageError = HealthProfile.checkAge(age);
    heightError = HealthProfile.checkOptional(
      height,
      HealthProfile.minHeight,
      HealthProfile.maxHeight,
    );
    weightError = HealthProfile.checkOptional(
      weight,
      HealthProfile.minWeight,
      HealthProfile.maxWeight,
    );
    notifyListeners();
    if (ageError != null || heightError != null || weightError != null) {
      return false;
    }
    final confirmed = state == PmjayState.confirmed ? card : null;
    await prefs.setHealth(
      age: int.parse(age.trim()),
      heightCm: int.tryParse(height.trim()),
      weightKg: int.tryParse(weight.trim()),
      // An ID typed but not confirmed is kept as typed; a confirmed card
      // brings its own, cleaned ID.
      ayushmanId:
          confirmed?.pmjayId ??
          (ayushmanId.trim().isEmpty ? null : PmjayClient.clean(ayushmanId)),
      ayushmanCardJson: confirmed == null
          ? null
          : jsonEncode(confirmed.toJson()),
    );
    return true;
  }
}
