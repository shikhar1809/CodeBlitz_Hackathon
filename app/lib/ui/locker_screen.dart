import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/evidence_chain.dart';
import '../core/pin_vault.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

String _date(DateTime t) => '${t.day}/${t.month}/${t.year} ${hhmm(t)}';

class LockerScreen extends StatelessWidget {
  const LockerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Locker')),
      body: app.recordings.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'Recordings from Active duty and journeys are kept here, encrypted and sealed in a hash chain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: W.text2)),
              ),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final r in app.recordings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WCard(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => _RecordingScreen(r))),
                    child: Row(children: [
                      const GradientIcon(WIcons.record, W.violet, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(_date(r.startedAt), style: const TextStyle(color: W.text2, fontSize: 13)),
                          Text(
                              '${r.gpsPoints} location points · ${r.photos} photos'
                              '${r.audioChunks > 0 ? ' · ${mmss(r.audioLength)} audio' : ''}',
                              style: const TextStyle(color: W.text2, fontSize: 13)),
                        ]),
                      ),
                      if (r.inProgress)
                        const Chip(label: Text('Recording now'), backgroundColor: Color(0xFFFFE1E1))
                      else if (r.interrupted)
                        const Chip(label: Text('Interrupted')),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _RecordingScreen extends StatelessWidget {
  final Recording r;
  const _RecordingScreen(this.r);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final intact = EvidenceChain.verify(r.chain.chunks);
    return Scaffold(
      appBar: AppBar(title: Text(r.title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (intact ? W.watching : W.sos).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Icon(intact ? WIcons.tick : WIcons.danger, color: intact ? W.leaf : W.sos),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                intact
                    ? 'Intact. All ${r.chain.chunks.length} chunks verified just now.'
                    : 'Changed. This recording no longer matches its seal.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        WCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kv('Started', _date(r.startedAt)),
            if (r.endedAt != null) _kv('Ended', _date(r.endedAt!)),
            _kv('First location', '${r.first ?? '—'}'),
            _kv('Last location', '${r.last ?? '—'}'),
            _kv('Location points', '${r.gpsPoints}'),
            _kv('Photos', '${r.photos}'),
            _kv('Seal', r.chain.head.substring(0, 16)),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(
                text: 'Winger proof of integrity\nRecording: ${r.title}, ${_date(r.startedAt)}\n'
                    'Chunks: ${r.chain.chunks.length}\nFinal SHA-256: ${r.chain.head}'));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Proof of integrity copied')));
          },
          icon: const Icon(WIcons.share),
          label: const Text('Share proof of integrity'),
        ),
        const SizedBox(height: 10),
        if (!r.inProgress)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: W.sos),
            onPressed: () async {
              final pin = await askPin(context, title: 'PIN to delete');
              if (pin == null || !context.mounted) return;
              if (app.vault.check(pin) == PinResult.real) {
                app.deleteRecording(r);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
              }
            },
            icon: const Icon(WIcons.trash),
            label: const Text('Delete'),
          ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: W.text2))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
