import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Is there a connection? Injectable, so a test can pull the plug.
abstract class NetworkStatus {
  factory NetworkStatus() => _ConnectivityStatus();

  Future<bool> isOnline();

  /// True when a connection appears, false when it goes.
  Stream<bool> get changes;
}

class _ConnectivityStatus implements NetworkStatus {
  // Built on first use: the plugin talks to the platform.
  Connectivity? _lazy;
  Connectivity get _c => _lazy ??= Connectivity();

  static bool _online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _c.checkConnectivity());
    } catch (_) {
      // No plugin here (a desktop test runner): assume online, and let the
      // request itself fail if it must.
      return true;
    }
  }

  @override
  Stream<bool> get changes {
    try {
      return _c.onConnectivityChanged.map(_online).distinct();
    } catch (_) {
      return const Stream.empty();
    }
  }
}

/// A switch a test can flip.
class FakeNetworkStatus implements NetworkStatus {
  FakeNetworkStatus({bool online = true}) {
    _online = online;
  }

  late bool _online;
  final _changes = StreamController<bool>.broadcast();

  bool get online => _online;

  set online(bool v) {
    if (v == _online) return;
    _online = v;
    _changes.add(v);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get changes => _changes.stream;
}
