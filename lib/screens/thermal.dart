import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'adb_wireless.dart';
import 'diagnostic.dart';

/// Nom lisible d'une zone /sys/class/thermal (types constructeur bruts).
String thermalZoneLabel(String raw) {
  final n = raw.toLowerCase();
  const map = [
    ('gpu', 'GPU'),
    ('cpu', 'CPU'),
    ('skin', 'Coque'),
    ('batt', 'Batterie'),
    ('bms', 'Batterie'),
    ('usb', 'Port USB'),
    ('charger', 'Chargeur'),
    ('chg', 'Chargeur'),
    ('modem', 'Modem'),
    ('mdm', 'Modem'),
    ('pa-', 'Amplificateur radio'),
    ('xo', 'Quartz (XO)'),
    ('npu', 'NPU (IA)'),
    ('camera', 'Caméra'),
    ('cam', 'Caméra'),
    ('wifi', 'Wi-Fi'),
    ('wlan', 'Wi-Fi'),
    ('ddr', 'Mémoire'),
    ('pmic', 'Gestion d’alimentation'),
    ('disp', 'Écran'),
    ('soc', 'SoC'),
    ('aoss', 'SoC'),
  ];
  for (final (k, v) in map) {
    if (n.contains(k)) return '$v · $raw';
  }
  return raw;
}

class _Track {
  final values = <double>[];
  double min = double.infinity;
  double max = double.negativeInfinity;

  void add(double v) {
    values.add(v);
    if (values.length > 60) values.removeAt(0);
    if (v < min) min = v;
    if (v > max) max = v;
  }
}

class ThermalScreen extends StatefulWidget {
  const ThermalScreen({super.key});

  @override
  State<ThermalScreen> createState() => _ThermalScreenState();
}

class _ThermalScreenState extends State<ThermalScreen> with LivePolling {
  final _tracks = <String, _Track>{};
  Map<String, dynamic> _detail = {};
  Timer? _detailTimer;

  static const _statusText = ['Normal', 'Léger', 'Modéré', 'Sévère', 'Critique', 'Urgence', 'Arrêt'];

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 2));
    _loadDetail();
    _detailTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadDetail());
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    super.dispose();
  }

  void _track(String key, double v) => _tracks.putIfAbsent(key, _Track.new).add(v);

  Future<void> _loadDetail() async {
    final d = await Native.thermalDetail();
    if (!mounted) return;
    setState(() {
      _detail = d;
      for (final s in (d['sensors'] as List? ?? const [])) {
        final t = (s['temp'] as num?)?.toDouble();
        if (t != null) _track('hal:${s['name']}', t);
      }
      for (final z in (d['zones'] as List? ?? const [])) {
        final t = normalizeThermal(z['temp'] as num?);
        if (t != null) _track('zone:${z['name']}', t);
      }
    });
  }

  @override
  void onLive(Map<String, dynamic> data) {
    // Zones lisibles par l'app elle-même (sans droits) : utiles seulement sans le HAL.
    for (final z in (data['thermalZones'] as List? ?? const [])) {
      final t = normalizeThermal(z['temp'] as num?);
      if (t != null) _track('zone:${z['name']}', t);
    }
    final b = (data['batteryTemp'] as num?)?.toDouble();
    if (b != null) _track('bat', b);
  }

  Color _color(double t, double? severe) {
    final limit = severe ?? 60;
    if (t >= limit) return NxColors.bad;
    if (t >= limit - 12) return NxColors.warn;
    return NxColors.ok;
  }

  Widget _row(String title, String? subtitle, _Track tr, {double? severe, int status = 0}) {
    final t = tr.values.last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NxCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(color: NxColors.muted, fontSize: 11), overflow: TextOverflow.ellipsis),
                Text('${t.toStringAsFixed(1)} °C',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _color(t, severe))),
              ]),
            ),
            Expanded(flex: 5, child: Sparkline(tr.values, color: _color(t, severe), height: 36)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 10, children: [
            Text('min ${tr.min.toStringAsFixed(1)} · max ${tr.max.toStringAsFixed(1)} °C',
                style: TextStyle(color: NxColors.muted, fontSize: 11)),
            if (severe != null)
              Text('bridage à ${severe.toStringAsFixed(0)} °C', style: TextStyle(color: NxColors.muted, fontSize: 11)),
            if (status > 0)
              Text('bridage ${_statusText[status.clamp(0, 6)].toLowerCase()}',
                  style: TextStyle(color: NxColors.warn, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensors = (_detail['sensors'] as List? ?? const []).cast<Map>();
    final hal = sensors.isNotEmpty;
    final forecast = (_detail['headroom10s'] as num?)?.toDouble();
    final hottest = _tracks.values.where((t) => t.values.isNotEmpty).map((t) => t.values.last).fold<double?>(
        null, (a, b) => a == null || b > a ? b : a);

    // Capteurs HAL regroupés par catégorie (CPU, GPU, Coque…), du plus chaud au plus froid.
    final groups = <String, List<Map>>{};
    for (final s in sensors) {
      groups.putIfAbsent(s['kind'].toString(), () => []).add(s);
    }
    final kinds = groups.keys.toList()
      ..sort((a, b) {
        double top(String k) => groups[k]!.map((s) => (s['temp'] as num).toDouble()).reduce((x, y) => x > y ? x : y);
        return top(b).compareTo(top(a));
      });
    final zoneKeys = _tracks.keys.where((k) => k.startsWith('zone:')).toList()
      ..sort((a, b) => _tracks[b]!.values.last.compareTo(_tracks[a]!.values.last));

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
              const SizedBox(height: 6),
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (hottest != null) Text('Point le plus chaud : ${hottest.toStringAsFixed(1)} °C', style: const TextStyle(fontSize: 12)),
                if (live['thermalHeadroom'] != null)
                  Text('Marge avant bridage : ${live['thermalHeadroom']}', style: const TextStyle(fontSize: 12)),
                if (forecast != null)
                  Text('Dans 10 s : ${((1 - forecast).clamp(0, 1) * 100).toStringAsFixed(0)} %',
                      style: TextStyle(fontSize: 12, color: forecast >= 0.9 ? NxColors.bad : null)),
              ]),
            ]),
          ),
          if (!hal) ...[
            const SizedBox(height: 10),
            NxCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Plus de capteurs disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Android cache la plupart des capteurs (CPU, GPU, coque, port USB, modem…) et leurs seuils de bridage. '
                  'Avec les droits ADB (sans PC) ou le root, NiTroiD les affiche tous.',
                  style: TextStyle(color: NxColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdbWirelessScreen())),
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Activer l’ADB sans fil'),
                ),
              ]),
            ),
          ],
          if (_tracks['bat'] != null) ...[
            const SectionHeader('Batterie'),
            _row('Batterie', 'capteur de la jauge', _tracks['bat']!, severe: 45),
          ],
          for (final k in kinds) ...[
            SectionHeader('$k (${groups[k]!.length})'),
            for (final s in groups[k]!..sort((a, b) => (b['temp'] as num).compareTo(a['temp'] as num)))
              if (_tracks['hal:${s['name']}'] != null)
                _row(s['name'].toString(), null, _tracks['hal:${s['name']}']!,
                    severe: (s['severe'] as num?)?.toDouble(), status: (s['status'] as num?)?.toInt() ?? 0),
          ],
          if (!hal && zoneKeys.isNotEmpty) ...[
            SectionHeader('Zones thermiques (${zoneKeys.length})'),
            for (final k in zoneKeys) _row(thermalZoneLabel(k.substring(5)), null, _tracks[k]!),
          ],
          if (!hal && zoneKeys.isEmpty && _tracks['bat'] == null)
            const EmptyState(icon: Icons.thermostat, text: 'Aucune température lisible sur ce système.'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
