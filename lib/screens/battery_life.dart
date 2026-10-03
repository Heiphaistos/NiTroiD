import 'dart:async';

import 'package:flutter/material.dart';

import '../core/battery_life.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Test d'autonomie : mesure la consommation réelle, téléphone débranché.
class BatteryLifeTest extends StatefulWidget {
  const BatteryLifeTest({super.key});

  @override
  State<BatteryLifeTest> createState() => _BatteryLifeTestState();
}

class _BatteryLifeTestState extends State<BatteryLifeTest> {
  static const _durations = [5, 15, 30];
  int _minutes = 15;
  final _samples = <BatterySample>[];
  final _currents = <double>[];
  Timer? _timer;
  DateTime? _start;
  double? _design;
  bool _plugged = false;
  String? _stopReason;

  bool get _running => _timer != null;

  @override
  void initState() {
    super.initState();
    _peek();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Native.keepScreenOn(false);
    super.dispose();
  }

  Future<void> _peek() async {
    final m = await Native.batterySample();
    if (!mounted) return;
    setState(() {
      _plugged = m['plugged'] == true;
      _design = (m['designMah'] as num?)?.toDouble();
    });
  }

  Future<void> _startTest() async {
    _samples.clear();
    _currents.clear();
    _stopReason = null;
    _start = DateTime.now();
    await Native.keepScreenOn(true);
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    if (mounted) setState(() {});
  }

  void _stop([String? reason]) {
    _timer?.cancel();
    _timer = null;
    Native.keepScreenOn(false);
    if (mounted) setState(() => _stopReason = reason);
  }

  Future<void> _tick() async {
    final m = await Native.batterySample();
    if (!mounted) return;
    if (m['plugged'] == true) {
      _stop('Chargeur branché : mesure interrompue.');
      return;
    }
    setState(() {
      _design ??= (m['designMah'] as num?)?.toDouble();
      final s = BatterySample.fromMap(m);
      _samples.add(s);
      final c = s.currentMa;
      if (c != null) {
        _currents.add(c.abs());
        if (_currents.length > 120) _currents.removeAt(0);
      }
    });
    final start = _start;
    if (start != null && DateTime.now().difference(start).inMinutes >= _minutes) _stop();
  }

  String _h(double? h) {
    if (h == null || h.isInfinite || h.isNaN) return '—';
    final total = (h * 60).round();
    return '${total ~/ 60} h ${(total % 60).toString().padLeft(2, '0')}';
  }

  Widget _stat(String label, String value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: NxColors.muted, fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ]);

  String _verdict(double? health) {
    if (health == null) return 'Santé non calculable sur cette mesure.';
    if (health >= 80) return 'Batterie en bon état.';
    if (health >= 65) return 'Batterie fatiguée : l’autonomie a nettement baissé.';
    return 'Batterie usée : un remplacement est conseillé.';
  }

  @override
  Widget build(BuildContext context) {
    final r = computeBatteryLife(_samples, designMah: _design);
    final start = _start;
    final elapsed = start == null ? Duration.zero : DateTime.now().difference(start);
    final progress = _running ? (elapsed.inSeconds / (_minutes * 60)).clamp(0.0, 1.0) : (_samples.length > 1 ? 1.0 : 0.0);
    final health = r?.healthPercent;
    final design = _design;
    return Scaffold(
      appBar: AppBar(title: const Text('Autonomie batterie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mesure de la consommation réelle', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Débranche le chargeur et utilise le téléphone normalement, ou laisse-le sur cet écran pour la '
                'consommation au repos écran allumé. NiTroiD lit le compteur de charge toutes les 5 s et en déduit '
                'l’autonomie et l’usure réelle de la batterie. Plus la mesure est longue, plus le résultat est fiable.',
                style: TextStyle(color: NxColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final d in _durations)
                  ChoiceChip(
                    label: Text('$d min'),
                    selected: _minutes == d,
                    onSelected: _running ? null : (_) => setState(() => _minutes = d),
                  ),
              ]),
              const SizedBox(height: 12),
              if (_plugged && !_running)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Débranche le chargeur pour lancer le test.', style: TextStyle(color: NxColors.warn, fontSize: 13)),
                ),
              Row(children: [
                FilledButton.icon(
                  onPressed: _running
                      ? () => _stop('Arrêté manuellement.')
                      : () async {
                          await _peek();
                          if (!_plugged) await _startTest();
                        },
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? 'Arrêter' : 'Lancer le test'),
                ),
                const SizedBox(width: 12),
                if (_running) Text('${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')} / $_minutes:00'),
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
              if (_stopReason != null) ...[
                const SizedBox(height: 8),
                Text(_stopReason!, style: TextStyle(color: NxColors.muted, fontSize: 12)),
              ],
            ]),
          ),
          if (_currents.length > 1) ...[
            const SectionHeader('Consommation en direct (mA)'),
            NxCard(child: Sparkline(_currents, color: NxColors.accent, height: 60)),
          ],
          if (r != null) ...[
            const SectionHeader('Résultats'),
            NxCard(
              child: Wrap(spacing: 24, runSpacing: 14, children: [
                _stat('Consommation moyenne', '${r.avgMa.round()} mA'),
                _stat('Perte par heure', '${r.dropPerHour.toStringAsFixed(1)} %'),
                _stat('Autonomie restante', _h(r.remainingHours)),
                _stat('Autonomie sur charge pleine', _h(r.fullHours)),
              ]),
            ),
            const SectionHeader('Santé de la batterie'),
            NxCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 24, runSpacing: 14, children: [
                  _stat('Capacité réelle', r.realCapacityMah == null ? '—' : '${r.realCapacityMah!.round()} mAh'),
                  _stat('Capacité d’origine', design == null ? '—' : '${design.round()} mAh'),
                  _stat('Santé', health == null ? '—' : '${health.round()} %',
                      color: health == null ? null : health >= 80 ? NxColors.ok : health >= 65 ? NxColors.warn : NxColors.bad),
                ]),
                const SizedBox(height: 10),
                Text(_verdict(health), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  r.realCapacityMah == null
                      ? 'Mesure de capacité impossible ou incohérente sur ce téléphone (compteur de charge figé ou absent) : '
                          'l’autonomie est extrapolée à partir du % perdu.'
                      : r.levelDrop >= 2
                          ? 'Capacité mesurée sur ${r.levelDrop.toStringAsFixed(0)} points de batterie consommés.'
                          : 'Estimation à partir de la charge actuelle : laisse le test descendre d’au moins 2 % pour une mesure directe.',
                  style: TextStyle(color: NxColors.muted, fontSize: 11),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
