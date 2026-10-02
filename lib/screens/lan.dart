import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/lan.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Liste les appareils connectés au même réseau Wi-Fi.
class LanScreen extends StatefulWidget {
  const LanScreen({super.key});

  @override
  State<LanScreen> createState() => _LanScreenState();
}

class _LanScreenState extends State<LanScreen> {
  String? _ip;
  final _hosts = <LanHost>[];
  int _done = 0;
  int _total = 0;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final ip = await localIpv4();
    if (!mounted) return;
    if (ip == null) {
      setState(() => _error = 'Pas d’adresse locale : connecte-toi à un réseau Wi-Fi.');
      return;
    }
    setState(() {
      _ip = ip;
      _hosts.clear();
      _done = 0;
      _total = 254;
      _scanning = true;
      _error = null;
    });
    await scanLan(
      ip,
      onProgress: (d, t) {
        if (mounted) {
          setState(() {
            _done = d;
            _total = t;
          });
        }
      },
      onHost: (h) {
        if (mounted) {
          setState(() {
            _hosts.add(h);
            _hosts.sort((a, b) => int.parse(a.ip.split('.').last).compareTo(int.parse(b.ip.split('.').last)));
          });
        }
      },
    );
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appareils du réseau'), actions: [
        IconButton(onPressed: _scanning ? null : _scan, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_error ?? 'Ce téléphone : ${_ip ?? '…'}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _error == null ? null : NxColors.bad)),
              const SizedBox(height: 4),
              Text(
                _scanning
                    ? 'Analyse $_done/$_total — ${_hosts.length} appareil(s) trouvé(s)'
                    : '${_hosts.length} appareil(s) trouvé(s) sur le réseau.',
                style: TextStyle(color: NxColors.muted, fontSize: 12),
              ),
              if (_scanning) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
              ],
              const SizedBox(height: 8),
              Text(
                'Un appareil inconnu sur ton Wi-Fi peut être un intrus : change alors le mot de passe de la box.',
                style: TextStyle(fontSize: 11, color: NxColors.muted),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final h in _hosts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NxCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.devices_other),
                  title: Text(h.name ?? h.ip, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${h.name == null ? '' : '${h.ip} · '}${h.kind}'
                    '${h.openPorts.isEmpty ? '' : '\nPorts ouverts : ${h.openPorts.join(', ')}'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: h.openPorts.isNotEmpty,
                  trailing: Text('${h.latencyMs} ms', style: TextStyle(color: NxColors.muted, fontSize: 12)),
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: h.ip));
                    showSnack(context, '${h.ip} copié');
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
