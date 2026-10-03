import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'server/hub_server.dart';
import 'server/store.dart';

/// Owns the store and the server for the desktop UI.
class HubController extends ChangeNotifier {
  late final HubStore store;
  late final HubServer server;
  final List<HubEvent> events = [];
  List<String> lanAddresses = [];
  String? dataPath;
  String? error;
  Timer? _tick;

  bool get running => server.running;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}hub.json');
    dataPath = file.path;
    store = HubStore(file);
    await store.load();
    final track = await rootBundle.loadString('assets/web/track.html');
    server = HubServer(store: store, trackPage: track, onEvent: _event);
    await refreshAddresses();
    await start();
    // Redraw for uptime, the pairing countdown and session counts.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void _event(HubEvent e) {
    events.insert(0, e);
    if (events.length > 200) events.removeLast();
    notifyListeners();
  }

  Future<void> start() async {
    error = null;
    try {
      await server.start();
    } on SocketException catch (e) {
      error = 'Port ${store.settings.port} is busy or blocked (${e.osError?.message ?? e.message}). Pick another port in Settings.';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await server.stop();
    notifyListeners();
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> refreshAddresses() async {
    final found = <String>[];
    try {
      for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          if (!a.isLoopback && !a.isLinkLocal) found.add(a.address);
        }
      }
    } catch (_) {}
    // Home networks first.
    int rank(String ip) => ip.startsWith('192.168.') ? 0 : (ip.startsWith('10.') ? 1 : (ip.startsWith('172.') ? 2 : 3));
    found.sort((a, b) => rank(a).compareTo(rank(b)));
    lanAddresses = found;
    notifyListeners();
  }

  int get port => server.port ?? store.settings.port;

  /// The address phones on this Wi-Fi use.
  String get localUrl => 'http://${lanAddresses.isEmpty ? 'localhost' : lanAddresses.first}:$port';

  /// The address guardian links use.
  String get linkBase => store.settings.publicUrl.trim().isNotEmpty ? store.settings.publicUrl.trim() : localUrl;

  String newPairingCode() {
    final c = server.newPairingCode();
    notifyListeners();
    return c;
  }

  void revoke(String id) {
    server.revoke(id);
    notifyListeners();
  }

  Future<void> saveSettings({required int port, required String publicUrl, required bool acceptUnpaired}) async {
    final portChanged = port != store.settings.port;
    store.settings
      ..port = port
      ..publicUrl = publicUrl.trim()
      ..acceptUnpaired = acceptUnpaired;
    await store.flush();
    if (portChanged && running) await restart();
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    server.stop();
    super.dispose();
  }
}
