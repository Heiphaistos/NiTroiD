import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../core/threats.dart';
import '../widgets/common.dart';

class AppIcon extends StatefulWidget {
  const AppIcon(this.package, {super.key, this.size = 40});

  final String package;
  final double size;

  static final _cache = <String, Uint8List?>{};

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = AppIcon._cache[widget.package];
    if (!AppIcon._cache.containsKey(widget.package)) {
      Native.appIcon(widget.package).then((b) {
        AppIcon._cache[widget.package] = b;
        if (mounted) setState(() => _bytes = b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: b == null
          ? Icon(Icons.android, color: NxColors.muted)
          : Image.memory(b, gaplessPlayback: true, filterQuality: FilterQuality.medium),
    );
  }
}

enum _Sort { name, recent, risk }

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<AppEntry>? _apps;
  ThreatDb? _db;
  bool _system = false;
  String _query = '';
  _Sort _sort = _Sort.name;

  @override
  void initState() {
    super.initState();
    ThreatDb.load().then((db) => _db = db);
    _load();
  }

  Future<void> _load() async {
    setState(() => _apps = null);
    final apps = await Native.apps(includeSystem: _system);
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) {
    var apps = _apps;
    final risks = <String, AppRisk>{};
    if (apps != null) {
      for (final a in apps) {
        risks[a.package] = assessApp(a, _db);
      }
      final q = _query.toLowerCase();
      apps = apps.where((a) => q.isEmpty || a.label.toLowerCase().contains(q) || a.package.contains(q)).toList();
      switch (_sort) {
        case _Sort.name:
          apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        case _Sort.recent:
          apps.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
        case _Sort.risk:
          apps.sort((a, b) => risks[b.package]!.score.compareTo(risks[a.package]!.score));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications${apps == null ? '' : ' (${apps.length})'}'),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.name, child: Text('Nom')),
              PopupMenuItem(value: _Sort.recent, child: Text('Mises à jour récentes')),
              PopupMenuItem(value: _Sort.risk, child: Text('Niveau de risque')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher une application'),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SwitchListTile(
          title: const Text('Inclure les applications système'),
          value: _system,
          onChanged: (v) {
            setState(() => _system = v);
            _load();
          },
        ),
        Expanded(
          child: apps == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, i) {
                    final a = apps![i];
                    final r = risks[a.package]!;
                    return ListTile(
                      leading: AppIcon(a.package),
                      title: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${a.package} · ${a.version}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      trailing: r.level == 'ok' ? null : StatusDot(r.level),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AppDetailScreen(app: a, risk: r)),
                      ).then((_) => _load()),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

const _specialLabels = {
  'accessibility': 'Service d’accessibilité actif',
  'deviceAdmin': 'Administrateur de l’appareil',
  'notificationListener': 'Accès aux notifications',
  'overlay': 'Superposition à l’écran',
  'installPackages': 'Installation d’applications',
  'usageAccess': 'Accès aux données d’utilisation',
  'vpn': 'Service VPN',
  'defaultSms': 'Application SMS par défaut',
  'defaultLauncher': 'Lanceur par défaut',
};

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app, required this.risk});

  final AppEntry app;
  final AppRisk risk;

  @override
  Widget build(BuildContext context) {
    final perms = app.grantedPermissions.map((p) => p.split('.').last).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(app.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Row(children: [
              AppIcon(app.package, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(app.package, style: TextStyle(color: NxColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    StatusDot(risk.level),
                    const SizedBox(width: 6),
                    Text(
                      risk.threat != null ? 'Logiciel espion connu : ${risk.threat}' : 'Score de risque : ${risk.score}/100',
                      style: TextStyle(color: NxColors.forStatus(risk.level), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (app.hasLauncher)
              FilledButton.tonalIcon(
                onPressed: () => Native.launchApp(app.package),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir'),
              ),
            FilledButton.tonalIcon(
              onPressed: () => Native.openSettings('android.settings.APPLICATION_DETAILS_SETTINGS', package: app.package),
              icon: const Icon(Icons.settings),
              label: const Text('Paramètres'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Native.openSettings('android.settings.APP_NOTIFICATION_SETTINGS', package: app.package),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Notifications'),
            ),
            if (!app.system || app.lastUpdate != app.firstInstall)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: NxColors.bad),
                onPressed: () async {
                  final ok = await Native.uninstall(app.package);
                  if (!ok && context.mounted) showSnack(context, 'Désinstallation refusée par le système');
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(app.system ? 'Désinstaller les MAJ' : 'Désinstaller'),
              ),
          ]),
          if (risk.reasons.isNotEmpty) ...[
            const SectionHeader('Pourquoi ce score'),
            NxCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final r in risk.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('•  ', style: TextStyle(color: NxColors.accent)),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
              ]),
            ),
          ],
          if (app.specialAccess.isNotEmpty) ...[
            const SectionHeader('Accès spéciaux actifs'),
            NxCard(
              child: Column(children: [
                for (final s in app.specialAccess) KeyValueRow(_specialLabels[s] ?? s, 'oui'),
              ]),
            ),
          ],
          const SectionHeader('Informations'),
          NxCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              KeyValueRow('Version', app.version),
              KeyValueRow('Type', app.system ? 'Système' : 'Utilisateur'),
              KeyValueRow('Activée', app.enabled ? 'oui' : 'non'),
              KeyValueRow('Installée par', app.installer ?? 'inconnu (APK manuel)'),
              KeyValueRow('Installée le', formatDate(app.firstInstall)),
              KeyValueRow('Mise à jour le', formatDate(app.lastUpdate)),
              KeyValueRow('SDK cible', app.targetSdk.toString()),
              KeyValueRow('Débogable', app.debuggable ? 'oui' : 'non'),
              if (app.certSha256.isNotEmpty) KeyValueRow('Certificat SHA-256', app.certSha256),
            ]),
          ),
          SectionHeader('Permissions accordées (${perms.length})'),
          NxCard(
            child: perms.isEmpty
                ? Text('Aucune permission sensible accordée.', style: TextStyle(color: NxColors.muted))
                : Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in perms)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: NxColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p, style: const TextStyle(fontSize: 11)),
                      ),
                  ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Temps d'écran par application (nécessite l'accès aux données d'utilisation).
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _stats;
  bool _granted = true;
  int _days = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final perms = await Native.permissions();
    final granted = perms['usageAccess'] == true;
    final stats = granted ? await Native.usageStats(_days) : <Map<String, dynamic>>[];
    if (mounted) {
      setState(() {
        _granted = granted;
        _stats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final maxMs = stats == null || stats.isEmpty ? 1 : (stats.first['foregroundMs'] as num).toInt().clamp(1, 1 << 62);
    return Scaffold(
      appBar: AppBar(title: const Text('Temps d’écran')),
      body: !_granted
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_clock, size: 48, color: NxColors.muted),
                const SizedBox(height: 12),
                const Text(
                  'Android protège ces statistiques. Autorise NiTroiD dans « Accès aux données d’utilisation », '
                  'puis reviens ici.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Native.openSettings('android.settings.USAGE_ACCESS_SETTINGS'),
                  child: const Text('Autoriser'),
                ),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('24 h')),
                    ButtonSegment(value: 7, label: Text('7 jours')),
                    ButtonSegment(value: 30, label: Text('30 jours')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) {
                    setState(() => _days = s.first);
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                if (stats == null) const Center(child: CircularProgressIndicator()),
                for (final s in stats ?? const <Map<String, dynamic>>[])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(s['pkg'].toString()),
                    title: Text(s['label']?.toString() ?? s['pkg'].toString()),
                    subtitle: LinearProgressIndicator(
                      value: (s['foregroundMs'] as num) / maxMs,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    trailing: Text(formatDuration(Duration(milliseconds: (s['foregroundMs'] as num).toInt()))),
                  ),
              ],
            ),
    );
  }
}
