import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/l10n/strings_hub.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../platform/qr_scanner.dart';
import 'hub_client.dart';
import 'hub_pairing_code.dart';

/// Pair this phone with the Winger Hub at home — by its QR code, or by the
/// address and six-digit code typed off its screen — and, once paired, show
/// which Hub it is and a way to let go of it.
class HubConnectScreen extends StatefulWidget {
  const HubConnectScreen({
    super.key,
    required this.prefs,
    this.scanner,
    this.httpClient,
    this.popWhenConnected = false,
  });

  final AppPrefs prefs;
  final QrScanner? scanner;

  /// For tests. The app uses a real client.
  final http.Client? httpClient;

  /// Opened on the way to booking: go back with `true` as soon as the phone
  /// is paired, rather than showing the connected card.
  final bool popWhenConnected;

  @override
  State<HubConnectScreen> createState() => _HubConnectScreenState();
}

class _HubConnectScreenState extends State<HubConnectScreen> {
  QrScanner? _scanner;
  final _address = TextEditingController();
  final _code = TextEditingController();

  bool _busy = false;
  String? _error;

  /// The last QR text tried. A camera sees the same QR many times a second;
  /// one wrong code must not become thirty tries and a 429.
  String? _lastScan;

  /// Connected-card status: null while checking.
  HubHealth? _health;
  bool _healthFailed = false;

  AppPrefs get prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    if (prefs.hasHub) _check();
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  QrScanner get _camera => _scanner ??= widget.scanner ?? QrScanner();

  void _onScan(String raw) {
    if (_busy || raw == _lastScan) return;
    _lastScan = raw;
    final code = HubPairingCode.parse(raw);
    if (code == null) {
      Haptics.error();
      setState(() => _error = L10n.of(context).hubBadQr);
      return;
    }
    _pair(code);
  }

  void _onTyped() {
    final code = HubPairingCode.typed(address: _address.text, code: _code.text);
    if (code == null) {
      Haptics.error();
      setState(() => _error = L10n.of(context).hubBadTyped);
      return;
    }
    _pair(code);
  }

  Future<void> _pair(HubPairingCode code) async {
    final s = L10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = HubClient(baseUrl: code.baseUrl, client: widget.httpClient);
    try {
      final r = await client.pair(
        code: code.code,
        deviceName: s.hubDeviceName(prefs.name),
      );
      await prefs.setHubLink(
        url: code.baseUrl,
        token: r.token,
        deviceId: r.deviceId,
        name: r.hubName.isEmpty ? code.hubName : r.hubName,
      );
      Haptics.confirm();
      if (!mounted) return;
      if (widget.popWhenConnected) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _busy = false);
      _check();
    } on HubException catch (e) {
      Haptics.error();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = s.hubProblem(e.problem);
        });
      }
    } finally {
      if (widget.httpClient == null) client.close();
    }
  }

  /// Is the Hub on, and does it still know this phone? A 401 from `me`
  /// forgets the link, and the screen falls back to pairing.
  Future<void> _check() async {
    final client = HubClient.fromPrefs(prefs, client: widget.httpClient);
    if (client == null) return;
    setState(() {
      _health = null;
      _healthFailed = false;
    });
    try {
      final health = await client.health();
      await client.me();
      if (mounted) setState(() => _health = health);
    } on HubException catch (e) {
      if (!mounted) return;
      final s = L10n.of(context);
      setState(() {
        _healthFailed = true;
        if (e.problem == HubProblem.unlinked) {
          _error = s.hubProblem(HubProblem.unlinked);
        }
      });
    } finally {
      if (widget.httpClient == null) client.close();
    }
  }

  Future<void> _disconnect() async {
    Haptics.tap();
    final s = L10n.of(context);
    // Local only: there is no unpair route. The Hub keeps the phone in its
    // list until its owner removes it there.
    await prefs.clearHubLink();
    if (!mounted) return;
    setState(() {
      _health = null;
      _error = null;
      _lastScan = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.hubDisconnected)));
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final connected = prefs.hasHub;
    return VoicePrompt(
      text: connected
          ? s.hubConnectedTo(prefs.hubName ?? s.homeHub)
          : '${s.hubConnectWhy}. ${s.hubScanTitle}',
      child: Scaffold(
        appBar: AppBar(title: Text(s.homeHub)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: AppTheme.pagePadding,
            children: connected ? _connected(s) : _pairing(s),
          ),
        ),
      ),
    );
  }

  List<Widget> _connected(AppStrings s) {
    final text = Theme.of(context).textTheme;
    final health = _health;
    final (statusLine, statusColor) = _healthFailed
        ? (s.hubProblem(HubProblem.unreachable), AppColors.red)
        : health == null
        ? (s.hubChecking, AppColors.muted)
        : health.agentReady
        ? (s.hubReady, AppColors.green)
        : (s.hubAgentStarting, AppColors.warn);
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.green, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.computer_rounded,
                  color: AppColors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.hubConnectedTo(prefs.hubName ?? s.homeHub),
                    style: text.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.hubAddress, style: text.labelMedium),
            Text(prefs.hubUrl ?? '', style: text.bodyMedium),
            const SizedBox(height: 12),
            Text(
              statusLine,
              style: text.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (_healthFailed) ...[
        Pressable(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.hubTryAgain),
            onPressed: _check,
          ),
        ),
        const SizedBox(height: 12),
      ],
      Pressable(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.link_off_rounded),
          label: Text(s.hubDisconnect),
          onPressed: _disconnect,
        ),
      ),
    ];
  }

  List<Widget> _pairing(AppStrings s) {
    final text = Theme.of(context).textTheme;
    return [
      Text(s.hubConnectWhy, style: text.bodyLarge),
      const SizedBox(height: 16),
      // An https page may only call http://localhost: a Hub elsewhere on the
      // Wi-Fi is mixed content, and the browser blocks it.
      if (kIsWeb) ...[HintPill(text: s.hubWebNote), const SizedBox(height: 16)],
      Text(s.hubScanTitle, style: text.titleMedium),
      const SizedBox(height: 10),
      SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _camera.view(
            onCode: _onScan,
            problem: (why) => _problem(why, s),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(s.hubOrType, style: text.bodyMedium),
      const SizedBox(height: 10),
      BigTextField(
        controller: _address,
        hint: s.hubAddressHint,
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      BigTextField(
        controller: _code,
        hint: s.hubCodeHint,
        digits: 6,
        onSubmitted: (_) => _onTyped(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: AppColors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Pressable(
        enabled: !_busy,
        child: FilledButton.icon(
          icon: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded),
          label: Text(_busy ? s.hubConnecting : s.hubConnect),
          onPressed: _busy ? null : _onTyped,
        ),
      ),
    ];
  }

  Widget _problem(ScanProblem why, AppStrings s) {
    final text = switch (why) {
      ScanProblem.permissionDenied => s.cameraDenied,
      ScanProblem.unsupported => s.cannotScanHere,
      ScanProblem.failed => s.cameraFailed,
    };
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              if (why != ScanProblem.unsupported) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _camera.retry,
                  child: Text(s.hubTryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
