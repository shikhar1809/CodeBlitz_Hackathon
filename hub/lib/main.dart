import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'hub_controller.dart';
import 'server/hub_server.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HubApp());
}

/// Same tokens as the Winger app.
class C {
  static const page = Color(0xFFFAF7FC);
  static const card = Color(0xFFFFFFFF);
  static const container = Color(0xFFF2EEF7);
  static const outline = Color(0xFFE5DEEC);
  static const text = Color(0xFF241519);
  static const text2 = Color(0xFF6E5A5F);
  static const plum = Color(0xFF6B2A55);
  static const gold = Color(0xFFF6B042);
  static const green = Color(0xFF3DBE7B);
  static const red = Color(0xFFE5383B);
  static const shadow = [BoxShadow(color: Color(0x14101418), blurRadius: 18, offset: Offset(0, 6))];
}

class HubApp extends StatefulWidget {
  const HubApp({super.key});
  @override
  State<HubApp> createState() => _HubAppState();
}

class _HubAppState extends State<HubApp> {
  final hub = HubController();
  late final Future<void> _ready = hub.init();

  @override
  void dispose() {
    hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: C.plum, primary: C.plum, surface: C.page, error: C.red);
    return MaterialApp(
      title: 'Winger Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: C.page,
        fontFamily: 'Segoe UI',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.container,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      home: FutureBuilder(
        future: _ready,
        builder: (context, snap) {
          if (snap.hasError) return Scaffold(body: Center(child: Text('Winger Hub could not start: ${snap.error}')));
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return ListenableBuilder(listenable: hub, builder: (context, _) => Dashboard(hub: hub));
        },
      ),
    );
  }
}

class Dashboard extends StatelessWidget {
  final HubController hub;
  const Dashboard({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 920;
        final main = [
          _Header(hub: hub),
          if (hub.error != null) _Banner(hub.error!),
          _Stats(hub: hub),
          _ConnectCard(hub: hub),
          _PairCard(hub: hub),
        ];
        final side = [
          _ActivityCard(hub: hub),
          _SettingsCard(hub: hub),
          const _PrivacyCard(),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: _Col(main)),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _Col([const SizedBox(height: 60), ...side])),
                    ])
                  : _Col([...main, ...side]),
            ),
          ),
        );
      }),
    );
  }
}

class _Col extends StatelessWidget {
  final List<Widget> children;
  const _Col(this.children);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ],
      );
}

class _Card extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  const _Card({this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22), boxShadow: C.shadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(
                  child: Text(title!,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.3)),
                ),
                ?trailing,
              ]),
            ),
          child,
        ]),
      );
}

class _Header extends StatelessWidget {
  final HubController hub;
  const _Header({required this.hub});

  @override
  Widget build(BuildContext context) {
    final on = hub.running;
    return Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/brand/mark.png', width: 52, height: 52)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Winger Hub',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: C.text)),
          Text('This computer is your household\'s Winger server.',
              style: TextStyle(color: C.text2.withValues(alpha: 0.9))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: on ? const Color(0xFFE3F6EB) : C.container, borderRadius: BorderRadius.circular(99)),
        child: Row(children: [
          Container(
              width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.green : C.text2)),
          const SizedBox(width: 8),
          Text(on ? 'Running' : 'Stopped',
              style: TextStyle(fontWeight: FontWeight.w700, color: on ? const Color(0xFF1D6B43) : C.text2)),
        ]),
      ),
      const SizedBox(width: 12),
      on
          ? OutlinedButton.icon(onPressed: hub.stop, icon: const Icon(Icons.stop_rounded), label: const Text('Stop'))
          : FilledButton.icon(onPressed: hub.start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start')),
    ]);
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFDE7E7), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: C.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: C.text))),
        ]),
      );
}

class _Stats extends StatelessWidget {
  final HubController hub;
  const _Stats({required this.hub});

  String _uptime() {
    final s = hub.server.startedAt;
    if (s == null) return '—';
    final d = DateTime.now().difference(s);
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  @override
  Widget build(BuildContext context) {
    final dark = hub.server.darkSessions;
    final tiles = [
      ('Live sessions', '${hub.server.liveSessions}', C.plum),
      ('Phones gone dark', '$dark', dark > 0 ? C.red : C.text),
      ('Paired phones', '${hub.store.devices.length}', C.text),
      ('Up for', _uptime(), C.text),
    ];
    return Row(children: [
      for (final (i, t) in tiles.indexed) ...[
        if (i > 0) const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), boxShadow: C.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$1, style: const TextStyle(color: C.text2, fontSize: 13)),
              const SizedBox(height: 4),
              Text(t.$2, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.$3)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _ConnectCard extends StatelessWidget {
  final HubController hub;
  const _ConnectCard({required this.hub});

  @override
  Widget build(BuildContext context) {
    final url = hub.localUrl;
    return _Card(
      title: 'Connect a phone',
      trailing: IconButton(
          tooltip: 'Look for network addresses again', onPressed: hub.refreshAddresses, icon: const Icon(Icons.refresh)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: C.outline), borderRadius: BorderRadius.circular(16)),
          child: QrImageView(
            data: url,
            size: 150,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.plum),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.text),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hub address on this Wi-Fi', style: TextStyle(color: C.text2, fontSize: 13)),
            const SizedBox(height: 4),
            _Copyable(url, big: true),
            if (hub.lanAddresses.length > 1) ...[
              const SizedBox(height: 6),
              Text('Also: ${hub.lanAddresses.skip(1).map((a) => 'http://$a:${hub.port}').join('   ')}',
                  style: const TextStyle(color: C.text2, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            const _Step(1, 'Keep the phone on the same Wi-Fi, or set a public address in Settings.'),
            const _Step(2, 'Scan the code to check the phone can reach the Hub.'),
            const _Step(3, 'In Winger, use this address as the backend. Guardian links will open here.'),
            if (hub.store.settings.publicUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Guardian links use ${hub.linkBase}', style: const TextStyle(color: C.plum, fontSize: 13)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step(this.n, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: C.container, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.plum)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: C.text, height: 1.4))),
        ]),
      );
}

class _Copyable extends StatelessWidget {
  final String text;
  final bool big;
  const _Copyable(this.text, {this.big = false});
  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(
          child: SelectableText(text,
              style: TextStyle(fontSize: big ? 20 : 13, fontWeight: big ? FontWeight.w800 : FontWeight.w400, color: C.text)),
        ),
        IconButton(
          tooltip: 'Copy',
          iconSize: 18,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
          },
          icon: const Icon(Icons.copy_rounded),
        ),
      ]);
}

class _PairCard extends StatelessWidget {
  final HubController hub;
  const _PairCard({required this.hub});

  @override
  Widget build(BuildContext context) {
    final code = hub.server.pairingCode;
    final left = hub.server.pairingUntil?.difference(DateTime.now());
    final devices = hub.store.devices.values.toList()..sort((a, b) => b.pairedAt.compareTo(a.pairedAt));
    return _Card(
      title: 'Paired phones',
      trailing: FilledButton.tonalIcon(
        onPressed: hub.newPairingCode,
        icon: const Icon(Icons.add_link_rounded),
        label: Text(code == null ? 'Pairing code' : 'New code'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (code != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.container, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Text('${code.substring(0, 3)} ${code.substring(3)}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 4, color: C.plum)),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  'One phone can pair with this code. It expires in ${left!.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}.',
                  style: const TextStyle(color: C.text2),
                ),
              ),
            ]),
          ),
        if (devices.isEmpty)
          Text(
            hub.store.settings.acceptUnpaired
                ? 'No phones paired yet. Phones on your network can still start sessions; turn that off in Settings once your phones are paired.'
                : 'No phones paired yet. Only paired phones can start sessions.',
            style: const TextStyle(color: C.text2, height: 1.4),
          ),
        for (final d in devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: C.container, child: Icon(Icons.smartphone_rounded, color: C.plum)),
            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Paired ${_date(d.pairedAt)} · last seen ${_date(d.lastSeen)}'),
            trailing: TextButton(onPressed: () => hub.revoke(d.id), child: const Text('Remove')),
          ),
      ]),
    );
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ActivityCard extends StatelessWidget {
  final HubController hub;
  const _ActivityCard({required this.hub});

  @override
  Widget build(BuildContext context) => _Card(
        title: 'Activity',
        child: SizedBox(
          height: 220,
          child: hub.events.isEmpty
              ? const Center(child: Text('Nothing yet.', style: TextStyle(color: C.text2)))
              : ListView.builder(
                  itemCount: hub.events.length,
                  itemBuilder: (context, i) => _EventRow(hub.events[i]),
                ),
        ),
      );
}

class _EventRow extends StatelessWidget {
  final HubEvent e;
  const _EventRow(this.e);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 50,
            child: Text('${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: C.text2, fontSize: 13)),
          ),
          if (e.alert) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.warning_rounded, size: 16, color: C.red)),
          Expanded(
              child: Text(e.text,
                  style: TextStyle(fontSize: 13, color: e.alert ? C.red : C.text, fontWeight: e.alert ? FontWeight.w700 : null))),
        ]),
      );
}

class _SettingsCard extends StatefulWidget {
  final HubController hub;
  const _SettingsCard({required this.hub});
  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  late final _port = TextEditingController(text: '${widget.hub.store.settings.port}');
  late final _public = TextEditingController(text: widget.hub.store.settings.publicUrl);
  late bool _open = widget.hub.store.settings.acceptUnpaired;
  String? _err;

  Future<void> _save() async {
    final p = int.tryParse(_port.text.trim());
    final pub = _public.text.trim();
    if (p == null || p < 1024 || p > 65535) return setState(() => _err = 'Port must be between 1024 and 65535.');
    if (pub.isNotEmpty && !(pub.startsWith('https://') || pub.startsWith('http://'))) {
      return setState(() => _err = 'Public address must start with https://');
    }
    setState(() => _err = null);
    await widget.hub.saveSettings(port: p, publicUrl: pub, acceptUnpaired: _open);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) => _Card(
        title: 'Settings',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _port,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _public,
            decoration: const InputDecoration(
              labelText: 'Public address (optional)',
              hintText: 'https://your-hub.tailnet.ts.net',
              helperText: 'So guardians outside your home can open links. Tailscale Funnel gives one free.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _open,
            onChanged: (v) => setState(() => _open = v),
            title: const Text('Accept phones that are not paired'),
            subtitle: const Text('Turn off once every phone is paired.'),
          ),
          if (_err != null) Text(_err!, style: const TextStyle(color: C.red)),
          const SizedBox(height: 6),
          Row(children: [
            FilledButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Data: ${widget.hub.dataPath ?? ''}',
                  style: const TextStyle(color: C.text2, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
          ]),
        ]),
      );
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.container, borderRadius: BorderRadius.circular(22)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_outlined, color: C.plum),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This screen never shows names, numbers or locations. A live session is visible only to the guardians who '
              'were sent its link. Keep this computer plugged in and set it not to sleep when the lid closes.',
              style: TextStyle(color: C.text, height: 1.45, fontSize: 13),
            ),
          ),
        ]),
      );
}
