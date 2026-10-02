import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/theme.dart';
import '../core/threats.dart';
import '../widgets/common.dart';
import 'apps.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, this.autoScan = false});

  final bool autoScan;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  List<SecurityCheck>? _checks;
  ThreatDb? _db;
  List<AppRisk>? _risks;
  bool _scanning = false;
  int _scanned = 0;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadChecks();
    ThreatDb.load().then((db) {
      if (!mounted) return;
      setState(() => _db = db);
      if (widget.autoScan && Native.isAndroid) _scan();
    });
  }

  Future<void> _loadChecks() async {
    final checks = await Native.securityChecks();
    if (mounted) setState(() => _checks = checks);
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _risks = null;
    });
    final apps = await Native.apps(includeSystem: true);
    final risks = [for (final a in apps) if (a.package != 'com.heiphaistos.nitroid') assessApp(a, _db)]..sort((a, b) => b.score.compareTo(a.score));
    if (!mounted) return;
    setState(() {
      _scanned = apps.length;
      _risks = risks;
      _scanning = false;
    });
  }

  Future<void> _updateDb() async {
    setState(() => _updating = true);
    try {
      final db = await ThreatDb.update();
      if (!mounted) return;
      setState(() => _db = db);
      showSnack(context, 'Base mise à jour : ${db.size} indicateurs');
    } catch (e) {
      if (mounted) showSnack(context, 'Mise à jour impossible : $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checks = _checks;
    final risks = _risks;
    final flagged = risks?.where((r) => r.level != 'ok').toList() ?? const <AppRisk>[];
    final threats = risks?.where((r) => r.threat != null).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité')),
      body: RefreshIndicator(
        onRefresh: _loadChecks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (Native.isAndroid) ...[
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.radar, color: NxColors.primary),
                    SizedBox(width: 8),
                    Text('Analyse anti-malware', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Recherche des logiciels espions connus (paquets et certificats de signature), '
                    'des applications masquées, installées hors magasin ou disposant d’accès dangereux '
                    '(accessibilité, administrateur, lecture des notifications/SMS…).',
                    style: const TextStyle(color: NxColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _db == null ? 'Chargement de la base…' : 'Base Échap : ${_db!.size} indicateurs (${_db!.fetched})',
                    style: const TextStyle(fontSize: 12, color: NxColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _scanning || _db == null ? null : _scan,
                        icon: _scanning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: Text(_scanning ? 'Analyse…' : 'Analyser'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _updating ? null : _updateDb,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Base'),
                    ),
                  ]),
                ]),
              ),
              if (risks != null) ...[
                SectionHeader('Résultat — $_scanned applications analysées'),
                NxCard(
                  child: Row(children: [
                    StatusDot(threats > 0 ? 'bad' : flagged.isEmpty ? 'ok' : 'warn', size: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        threats > 0
                            ? '$threats logiciel(s) espion(s) connu(s) détecté(s) !'
                            : flagged.isEmpty
                                ? 'Aucune menace connue ni application suspecte.'
                                : 'Aucune menace connue. ${flagged.length} application(s) à vérifier.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                for (final r in flagged)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NxCard(
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AppDetailScreen(app: r.app, risk: r)),
                      ),
                      child: ListTile(
                        leading: AppIcon(r.app.package),
                        title: Text(r.app.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(r.reasons.take(3).join(' · '),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        trailing: _ScoreBadge(r),
                      ),
                    ),
                  ),
              ],
            ] else
              NxCard(
                child: const Text(
                  'iOS isole chaque application : aucune app ne peut lister ni analyser les autres. '
                  'NiTroiD vérifie donc l’intégrité du système (jailbreak, profils, code d’accès, VPN/proxy) '
                  'ci-dessous.',
                  style: TextStyle(color: NxColors.muted),
                ),
              ),
            const SectionHeader('Intégrité de l’appareil'),
            if (checks == null) const Center(child: CircularProgressIndicator()),
            for (final c in checks ?? const <SecurityCheck>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NxCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Padding(padding: const EdgeInsets.only(top: 6), child: StatusDot(c.status)),
                    title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.detail, style: const TextStyle(fontSize: 12)),
                    trailing: c.action == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.open_in_new, size: 20),
                            tooltip: 'Ouvrir le réglage',
                            onPressed: () async {
                              final ok = await Native.openSettings(c.action!);
                              if (!ok && context.mounted) showSnack(context, 'Écran indisponible sur cet appareil');
                            },
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge(this.risk);

  final AppRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = NxColors.forStatus(risk.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(risk.threat != null ? 'ESPION' : '${risk.score}',
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}
