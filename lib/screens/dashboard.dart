import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/common.dart';
import 'about.dart';
import 'diagnostic.dart';
import 'report.dart';
import 'security.dart';

/// Score de santé global : contrôles de sécurité, batterie, stockage, chauffe.
int healthScore({
  required List<SecurityCheck> checks,
  required Map<String, dynamic> dash,
  double? hottest,
}) {
  var score = 100;
  for (final c in checks) {
    if (c.status == 'bad') score -= 10;
    if (c.status == 'warn') score -= 4;
  }
  final total = (dash['storageTotal'] as num?)?.toDouble() ?? 0;
  final free = (dash['storageFree'] as num?)?.toDouble() ?? 0;
  if (total > 0 && free / total < 0.1) score -= 10;
  if (dash['batteryHealthOk'] == false) score -= 15;
  if (hottest != null && hottest > 45) score -= 10;
  return score.clamp(0, 100);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dash = {};
  Map<String, dynamic> _live = {};
  List<SecurityCheck> _checks = [];
  final _tempHistory = <double>[];
  final _currentHistory = <double>[];
  Timer? _timer;
  bool _loading = true;
  ReleaseInfo? _update;

  @override
  void initState() {
    super.initState();
    _load();
    _checkUpdate();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([Native.dashboard(), Native.securityChecks()]);
    if (!mounted) return;
    setState(() {
      _dash = results[0] as Map<String, dynamic>;
      _checks = results[1] as List<SecurityCheck>;
      _loading = false;
    });
    await _poll();
  }

  /// Vérification silencieuse : en cas d'échec (hors ligne…), rien ne s'affiche.
  Future<void> _checkUpdate() async {
    try {
      final results = await Future.wait([Updater.latest(), Native.appInfo()]);
      final release = results[0] as ReleaseInfo;
      final current = (results[1] as Map<String, dynamic>)['version']?.toString() ?? '';
      if (mounted && current.isNotEmpty && compareVersions(release.version, current) > 0) {
        setState(() => _update = release);
      }
    } catch (_) {}
  }

  Future<void> _poll() async {
    final live = await Native.live();
    if (!mounted) return;
    setState(() {
      _live = live;
      final t = _hottest();
      if (t != null) _push(_tempHistory, t);
      final current = (live['batteryCurrentMa'] as num?)?.toDouble();
      if (current != null) _push(_currentHistory, current);
    });
  }

  void _push(List<double> list, double v) {
    list.add(v);
    if (list.length > 60) list.removeAt(0);
  }

  double? _hottest() {
    double? best;
    for (final z in (_live['thermalZones'] as List? ?? const [])) {
      final t = normalizeThermal(z['temp'] as num?);
      if (t != null && (best == null || t > best)) best = t;
    }
    final battery = (_live['batteryTemp'] as num?)?.toDouble();
    if (best == null || (battery != null && battery > best)) best = battery ?? best;
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final hottest = _hottest();
    final score = healthScore(checks: _checks, dash: _dash, hottest: hottest);
    final ramTotal = (_live['ramTotal'] ?? _dash['ramTotal']) as num?;
    final ramAvail = (_live['ramAvail'] ?? _dash['ramAvail']) as num?;
    final stTotal = _dash['storageTotal'] as num?;
    final stFree = _dash['storageFree'] as num?;
    final battery = (_live['batteryLevel'] ?? _dash['batteryLevel']) as num?;
    final freqs = (_live['cpuFreqs'] as List?)?.whereType<num>().toList() ?? const <num>[];
    final maxFreqs = (_live['cpuMaxFreqs'] as List?)?.whereType<num>().toList() ?? const <num>[];
    final bad = _checks.where((c) => c.status == 'bad').length;
    final warn = _checks.where((c) => c.status == 'warn').length;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/icon.png', width: 30, height: 30, errorBuilder: (_, _, _) => const SizedBox()),
          const SizedBox(width: 10),
          const Text('NiTroiD'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Rapport complet',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_update != null) ...[
                    NxCard(
                      onTap: () => _open(AboutScreen(release: _update)),
                      child: Row(children: [
                        Icon(Icons.system_update, color: NxColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('NiTroiD ${_update!.version} est disponible — toucher pour mettre à jour',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  NxCard(
                    child: Row(children: [
                      RingGauge(value: score / 100, label: 'santé'),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${_dash['manufacturer'] ?? ''} ${_dash['model'] ?? ''}'.trim(),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_dash['os']?.toString() ?? '', style: TextStyle(color: NxColors.muted)),
                          if (_dash['soc'] != null)
                            Text(_dash['soc'].toString(), style: TextStyle(color: NxColors.muted, fontSize: 12)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _chip(bad == 0 && warn == 0 ? 'Aucun problème' : '$bad critique(s)',
                                bad == 0 && warn == 0 ? NxColors.ok : NxColors.bad),
                            if (warn > 0) _chip('$warn avertissement(s)', NxColors.warn),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                  const SectionHeader('En direct'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      MetricTile(
                        icon: Icons.battery_charging_full,
                        label: 'Batterie',
                        value: battery == null ? '—' : '${battery.round()} %',
                        sub: _batterySub(),
                        progress: battery == null ? null : battery / 100,
                        color: NxColors.ok,
                        onTap: () => _open(const BatteryScreen()),
                      ),
                      MetricTile(
                        icon: Icons.thermostat,
                        label: 'Température max',
                        value: hottest == null ? '—' : '${hottest.toStringAsFixed(1)} °C',
                        sub: _live['thermalStatus']?.toString(),
                        color: hottest != null && hottest > 45 ? NxColors.bad : NxColors.accent,
                        onTap: () => _open(const ThermalScreen()),
                      ),
                      MetricTile(
                        icon: Icons.memory,
                        label: 'Mémoire vive',
                        value: ramTotal == null || ramAvail == null ? '—' : formatBytes(ramTotal - ramAvail),
                        sub: ramTotal == null ? null : 'sur ${formatBytes(ramTotal)}',
                        progress: ramTotal == null || ramAvail == null || ramTotal == 0 ? null : (ramTotal - ramAvail) / ramTotal,
                        color: NxColors.secondary,
                        onTap: () => _open(const InfoScreen(title: 'Mémoire', category: 'memory', refreshEvery: Duration(seconds: 3))),
                      ),
                      MetricTile(
                        icon: Icons.sd_storage,
                        label: 'Stockage',
                        value: stTotal == null || stFree == null ? '—' : formatBytes(stTotal - stFree),
                        sub: stFree == null ? null : '${formatBytes(stFree)} libres',
                        progress: stTotal == null || stFree == null || stTotal == 0 ? null : (stTotal - stFree) / stTotal,
                        color: NxColors.primary,
                        onTap: () => _open(const InfoScreen(title: 'Stockage', category: 'storage')),
                      ),
                    ],
                  ),
                  if (freqs.isNotEmpty) ...[
                    const SectionHeader('Processeur — fréquences par cœur'),
                    NxCard(
                      onTap: () => _open(const CpuScreen()),
                      child: Column(children: [
                        for (var i = 0; i < freqs.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              SizedBox(width: 56, child: Text('Cœur $i', style: TextStyle(fontSize: 12, color: NxColors.muted))),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: i < maxFreqs.length && maxFreqs[i] > 0 ? freqs[i] / maxFreqs[i] : 0,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                  backgroundColor: NxColors.primary.withValues(alpha: 0.12),
                                ),
                              ),
                              SizedBox(
                                width: 76,
                                child: Text(freqs[i] <= 0 ? 'repos' : formatFreqKhz(freqs[i]),
                                    textAlign: TextAlign.end, style: const TextStyle(fontSize: 12)),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                  if (_tempHistory.length > 2) ...[
                    const SectionHeader('Température (2 min)'),
                    NxCard(child: Sparkline(_tempHistory, color: NxColors.accent)),
                  ],
                  if (_currentHistory.length > 2) ...[
                    const SectionHeader('Courant batterie (mA)'),
                    NxCard(child: Sparkline(_currentHistory, color: NxColors.ok)),
                  ],
                  const SectionHeader('Contrôles rapides'),
                  NxCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final c in _checks.where((c) => c.status != 'ok').take(5))
                        ListTile(
                          leading: StatusDot(c.status),
                          title: Text(c.title),
                          subtitle: Text(c.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _open(const SecurityScreen()),
                        ),
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Lancer une analyse de sécurité complète'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(const SecurityScreen(autoScan: true)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String? _batterySub() {
    final parts = <String>[];
    final charging = _live['charging'] ?? _dash['charging'];
    if (charging == true) parts.add('en charge');
    final t = (_live['batteryTemp'] as num?)?.toDouble();
    if (t != null) parts.add('${t.toStringAsFixed(1)} °C');
    final ma = (_live['batteryCurrentMa'] as num?)?.toDouble();
    if (ma != null) parts.add('${ma.round()} mA');
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
