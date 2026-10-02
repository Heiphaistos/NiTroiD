import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/lan.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DiagnosticHub extends StatelessWidget {
  const DiagnosticHub({super.key});

  @override
  Widget build(BuildContext context) {
    final android = Native.isAndroid;
    final entries = <(IconData, String, String, Widget)>[
      (Icons.phone_android, 'Système', 'Modèle, OS, noyau, bootloader, Treble', const InfoScreen(title: 'Système', category: 'system')),
      (Icons.developer_board, 'Processeur (SoC)', 'Cœurs, fréquences, gouverneur, architecture', const CpuScreen()),
      (Icons.battery_full, 'Batterie', 'Santé, cycles, capacité, courant, tension', const BatteryScreen()),
      (Icons.thermostat, 'Températures', 'Zones thermiques, état thermique', const ThermalScreen()),
      (Icons.memory, 'Mémoire', 'RAM, swap/zRAM, seuils', const InfoScreen(title: 'Mémoire', category: 'memory', refreshEvery: Duration(seconds: 3))),
      (Icons.sd_storage, 'Stockage', 'Partitions, volumes, chiffrement', const InfoScreen(title: 'Stockage', category: 'storage')),
      (Icons.smartphone, 'Écran', 'Résolution, densité, fréquences, HDR', const InfoScreen(title: 'Écran', category: 'display')),
      (Icons.sensors, 'Capteurs', 'Liste complète et mesures en direct', const SensorsScreen()),
      (Icons.photo_camera, 'Caméras', 'Capteurs photo, focales, niveau matériel', const InfoScreen(title: 'Caméras', category: 'cameras')),
      (Icons.wifi, 'Réseau', 'Wi-Fi, mobile, IP, DNS, interfaces', const InfoScreen(title: 'Réseau', category: 'network')),
      (Icons.extension, 'Fonctions matérielles', 'NFC, Bluetooth, GPU, Vulkan, OpenGL', const InfoScreen(title: 'Fonctions matérielles', category: 'features')),
      if (android) (Icons.movie, 'Médias & DRM', 'Codecs, Widevine, niveau de sécurité', const InfoScreen(title: 'Médias & DRM', category: 'media')),
      if (android) (Icons.terminal, 'Propriétés système', 'getprop : toutes les propriétés lisibles', const PropsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, sub, page) = entries[i];
          return NxCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: NxColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: TextStyle(fontSize: 12, color: NxColors.muted)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            ),
          );
        },
      ),
    );
  }
}

/// Mixin de rafraîchissement périodique des mesures temps réel.
mixin LivePolling<T extends StatefulWidget> on State<T> {
  Map<String, dynamic> live = {};
  Timer? _timer;

  void onLive(Map<String, dynamic> data) {}

  void startPolling([Duration every = const Duration(seconds: 1)]) {
    _poll();
    _timer = Timer.periodic(every, (_) => _poll());
  }

  Future<void> _poll() async {
    final data = await Native.live();
    if (!mounted) return;
    setState(() {
      live = data;
      onLive(data);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class CpuScreen extends StatefulWidget {
  const CpuScreen({super.key});

  @override
  State<CpuScreen> createState() => _CpuScreenState();
}

class _CpuScreenState extends State<CpuScreen> with LivePolling {
  final _avg = <double>[];

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  void onLive(Map<String, dynamic> data) {
    final f = (data['cpuFreqs'] as List?)?.whereType<num>().toList() ?? [];
    if (f.isEmpty) return;
    _avg.add(f.fold<double>(0, (a, b) => a + b) / f.length / 1000);
    if (_avg.length > 60) _avg.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final freqs = (live['cpuFreqs'] as List?)?.whereType<num>().toList() ?? const <num>[];
    final maxF = (live['cpuMaxFreqs'] as List?)?.whereType<num>().toList() ?? const <num>[];
    return InfoScreen(
      title: 'Processeur',
      category: 'cpu',
      header: freqs.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fréquence moyenne (MHz)', style: TextStyle(color: NxColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Sparkline(_avg),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < freqs.length; i++)
                      Container(
                        width: 92,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NxColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(children: [
                          Text('CPU$i', style: TextStyle(fontSize: 11, color: NxColors.muted)),
                          Text(freqs[i] <= 0 ? 'repos' : formatFreqKhz(freqs[i]),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          if (i < maxF.length)
                            Text('max ${formatFreqKhz(maxF[i])}', style: TextStyle(fontSize: 10, color: NxColors.muted)),
                        ]),
                      ),
                  ]),
                ]),
              ),
            ),
    );
  }
}

class BatteryScreen extends StatefulWidget {
  const BatteryScreen({super.key});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> with LivePolling {
  final _current = <double>[];
  final _power = <double>[];

  /// Test du chargeur : 30 mesures (une par seconde) pendant la charge.
  static const _testSamples = 30;
  List<double>? _test;
  (String, String)? _verdict;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  void onLive(Map<String, dynamic> data) {
    final ma = (data['batteryCurrentMa'] as num?)?.toDouble();
    final mv = (data['batteryVoltageMv'] as num?)?.toDouble();
    final test = _test;
    if (test != null) {
      if (data['charging'] != true) {
        _test = null;
        _verdict = ('bad', 'Test interrompu : le téléphone n’est plus branché.');
      } else if (ma != null) {
        test.add(ma.abs());
        if (test.length >= _testSamples) {
          final avg = test.reduce((a, b) => a + b) / test.length;
          final (status, text) = rateCharger(avg);
          _verdict = (status, 'Moyenne ${avg.round()} mA — $text');
          _test = null;
        }
      }
    }
    if (ma != null) {
      _current.add(ma);
      if (_current.length > 90) _current.removeAt(0);
      if (mv != null) {
        _power.add(ma * mv / 1e6);
        if (_power.length > 90) _power.removeAt(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ma = (live['batteryCurrentMa'] as num?)?.toDouble();
    final mv = (live['batteryVoltageMv'] as num?)?.toDouble();
    final t = (live['batteryTemp'] as num?)?.toDouble();
    return InfoScreen(
      title: 'Batterie',
      category: 'battery',
      refreshEvery: const Duration(seconds: 10),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NxCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _big('Courant', ma == null ? '—' : '${ma.round()} mA')),
              Expanded(child: _big('Tension', mv == null ? '—' : '${(mv / 1000).toStringAsFixed(2)} V')),
              Expanded(child: _big('Puissance', ma == null || mv == null ? '—' : '${(ma * mv / 1e6).toStringAsFixed(2)} W')),
            ]),
            const SizedBox(height: 4),
            Text(
              t == null ? '' : 'Température : ${t.toStringAsFixed(1)} °C',
              style: TextStyle(color: NxColors.muted, fontSize: 12),
            ),
            if (_current.length > 2) ...[
              const SizedBox(height: 12),
              Text('Courant (positif = charge)', style: TextStyle(color: NxColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Sparkline(_current, color: NxColors.ok),
            ],
            if (ma != null) ...[
              const Divider(height: 28),
              const Text('Test du chargeur et du câble', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Branche le chargeur, laisse l’écran allumé 30 s sans utiliser le téléphone.',
                  style: TextStyle(color: NxColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              if (_test != null) ...[
                LinearProgressIndicator(value: _test!.length / _testSamples),
                const SizedBox(height: 6),
                Text('Mesure… ${_test!.length}/$_testSamples s', style: const TextStyle(fontSize: 12)),
              ] else
                OutlinedButton.icon(
                  onPressed: live['charging'] == true
                      ? () => setState(() {
                            _test = [];
                            _verdict = null;
                          })
                      : null,
                  icon: const Icon(Icons.power),
                  label: Text(live['charging'] == true ? 'Lancer le test (30 s)' : 'Branche le chargeur pour tester'),
                ),
              if (_verdict != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  StatusDot(_verdict!.$1),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_verdict!.$2, style: const TextStyle(fontSize: 13))),
                ]),
              ],
            ],
          ]),
        ),
      ),
    );
  }

  Widget _big(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: NxColors.muted, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]);
}

class ThermalScreen extends StatefulWidget {
  const ThermalScreen({super.key});

  @override
  State<ThermalScreen> createState() => _ThermalScreenState();
}

class _ThermalScreenState extends State<ThermalScreen> with LivePolling {
  final _history = <String, List<double>>{};

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 2));
  }

  @override
  void onLive(Map<String, dynamic> data) {
    for (final z in (data['thermalZones'] as List? ?? const [])) {
      final t = normalizeThermal(z['temp'] as num?);
      if (t == null) continue;
      final h = _history.putIfAbsent(z['name'].toString(), () => []);
      h.add(t);
      if (h.length > 30) h.removeAt(0);
    }
    final b = (data['batteryTemp'] as num?)?.toDouble();
    if (b != null) {
      final h = _history.putIfAbsent('Batterie', () => []);
      h.add(b);
      if (h.length > 30) h.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = _history.entries.toList()..sort((a, b) => b.value.last.compareTo(a.value.last));
    return Scaffold(
      appBar: AppBar(title: const Text('Températures')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('État thermique système', style: TextStyle(color: NxColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(live['thermalStatus']?.toString() ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (live['thermalHeadroom'] != null)
                Text('Marge avant bridage : ${live['thermalHeadroom']}', style: TextStyle(color: NxColors.muted, fontSize: 12)),
            ]),
          ),
          const SectionHeader('Capteurs de température'),
          if (zones.isEmpty)
            const EmptyState(
              icon: Icons.thermostat,
              text: 'Ce système ne laisse lire aucune zone thermique en dehors de la batterie.',
            ),
          for (final z in zones)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NxCard(
                child: Row(children: [
                  Expanded(
                    flex: 4,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(z.key, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text('${z.value.last.toStringAsFixed(1)} °C',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: z.value.last > 60 ? NxColors.bad : z.value.last > 45 ? NxColors.warn : NxColors.ok,
                          )),
                    ]),
                  ),
                  Expanded(flex: 5, child: Sparkline(z.value, color: NxColors.accent, height: 36)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  List<Map<String, dynamic>>? _sensors;

  @override
  void initState() {
    super.initState();
    Native.sensors().then((s) => mounted ? setState(() => _sensors = s) : null);
  }

  @override
  Widget build(BuildContext context) {
    final sensors = _sensors;
    return Scaffold(
      appBar: AppBar(title: Text('Capteurs${sensors == null ? '' : ' (${sensors.length})'}')),
      body: sensors == null
          ? const Center(child: CircularProgressIndicator())
          : sensors.isEmpty
              ? const EmptyState(icon: Icons.sensors_off, text: 'Aucun capteur exposé.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sensors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = sensors[i];
                    return NxCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(s['name']?.toString() ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [s['kind'], s['vendor'], if (s['power'] != null) '${s['power']} mA']
                              .whereType<Object>()
                              .join(' · '),
                          style: TextStyle(fontSize: 12, color: NxColors.muted),
                        ),
                        trailing: s['live'] == true ? const Icon(Icons.play_circle_outline) : null,
                        onTap: s['live'] == true
                            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => SensorLiveScreen(sensor: s)))
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}

class SensorLiveScreen extends StatefulWidget {
  const SensorLiveScreen({super.key, required this.sensor});

  final Map<String, dynamic> sensor;

  @override
  State<SensorLiveScreen> createState() => _SensorLiveScreenState();
}

class _SensorLiveScreenState extends State<SensorLiveScreen> {
  StreamSubscription<List<double>>? _sub;
  List<double> _values = [];
  final _history = <List<double>>[];

  @override
  void initState() {
    super.initState();
    final type = (widget.sensor['type'] as num).toInt();
    _sub = Native.sensorStream(type).listen((v) {
      if (!mounted) return;
      setState(() {
        _values = v;
        _history.add(v);
        if (_history.length > 120) _history.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const axes = ['X', 'Y', 'Z', 'W', 'V5', 'V6'];
    final colors = [NxColors.primary, NxColors.accent, NxColors.secondary, NxColors.ok, NxColors.bad, NxColors.muted];
    final unit = widget.sensor['unit']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.sensor['name']?.toString() ?? 'Capteur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _values.length && i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_values.length == 1 ? 'Valeur' : axes[i]} : ${_values[i].toStringAsFixed(3)} $unit',
                      style: TextStyle(fontWeight: FontWeight.w800, color: colors[i])),
                  const SizedBox(height: 6),
                  Sparkline([for (final h in _history) if (h.length > i) h[i]], color: colors[i], height: 40),
                ]),
              ),
            ),
          if (_values.isEmpty) const EmptyState(icon: Icons.hourglass_empty, text: 'En attente de mesures…'),
        ],
      ),
    );
  }
}

class PropsScreen extends StatefulWidget {
  const PropsScreen({super.key});

  @override
  State<PropsScreen> createState() => _PropsScreenState();
}

class _PropsScreenState extends State<PropsScreen> {
  List<MapEntry<String, String>>? _props;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Native.info('props').then((s) {
      if (mounted) setState(() => _props = [for (final sec in s) ...sec.items]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final props = _props?.where((p) => _filter.isEmpty || p.key.contains(_filter) || p.value.contains(_filter)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Propriétés${props == null ? '' : ' (${props.length})'}')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filtrer (ex. ro.boot, dalvik, vendor)'),
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
        ),
        Expanded(
          child: props == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: props.length,
                  itemBuilder: (_, i) => KeyValueRow(props[i].key, props[i].value),
                ),
        ),
      ]),
    );
  }
}
