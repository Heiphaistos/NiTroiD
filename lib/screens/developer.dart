import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dev_catalog.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'settings.dart';

/// Centre développeur : état root, octroi de permissions, options développeur,
/// journal en direct. Conçu pour faire de NiTroiD un vrai outil power-user.
class DeveloperHub extends StatefulWidget {
  const DeveloperHub({super.key});

  @override
  State<DeveloperHub> createState() => _DeveloperHubState();
}

class _DeveloperHubState extends State<DeveloperHub> with WidgetsBindingObserver {
  bool? _root;
  Map<String, dynamic> _perms = {};
  bool _granting = false;

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
    if (state == AppLifecycleState.resumed) _loadPerms();
  }

  Future<void> _load() async {
    _loadPerms();
    final r = await Native.rootAvailable();
    if (mounted) setState(() => _root = r);
  }

  Future<void> _loadPerms() async {
    final p = await Native.permissions();
    if (mounted) setState(() => _perms = p);
  }

  Future<void> _grant() async {
    setState(() => _granting = true);
    final res = await Native.grantSelf();
    if (!mounted) return;
    setState(() => _granting = false);
    final results = (res['results'] as List?) ?? [];
    final ok = results.where((r) => r['ok'] == true).length;
    showSnack(context, res['root'] == true
        ? '$ok/${results.length} permissions accordées via root'
        : 'Root indisponible : utilise la méthode ADB');
    _loadPerms();
  }

  @override
  Widget build(BuildContext context) {
    final root = _root;
    final held = _perms.entries.where((e) => e.value == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Développeur'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(root == true ? Icons.verified_user : Icons.gpp_maybe,
                    color: root == true ? NxColors.ok : NxColors.warn),
                const SizedBox(width: 8),
                Text(root == null ? 'Vérification du root…' : (root ? 'Root disponible' : 'Pas de root'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(
                root == true
                    ? 'NiTroiD peut s’accorder les permissions avancées et agir sur le système en un geste.'
                    : 'Sans root, les permissions avancées (réglages système, journal complet, dumpsys) '
                      's’accordent une fois depuis un PC via ADB.',
                style: TextStyle(color: NxColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (root == true)
                FilledButton.icon(
                  onPressed: _granting ? null : _grant,
                  icon: _granting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.flash_on),
                  label: const Text('Débloquer toutes les permissions (root)'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdbGuideScreen())),
                  icon: const Icon(Icons.usb),
                  label: const Text('Méthode ADB (sans root)'),
                ),
            ]),
          ),
          SectionHeader('Permissions avancées détenues ($held)'),
          NxCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final e in const [
                ('writeSecure', 'Réglages système (WRITE_SECURE_SETTINGS)'),
                ('readLogs', 'Journal complet (READ_LOGS)'),
                ('dump', 'dumpsys (DUMP)'),
                ('usageAccess', 'Données d’utilisation'),
                ('writeSettings', 'Modifier les paramètres système'),
              ])
                ListTile(
                  dense: true,
                  leading: StatusDot(_perms[e.$1] == true ? 'ok' : 'warn'),
                  title: Text(e.$2, style: const TextStyle(fontSize: 13)),
                ),
            ]),
          ),
          const SectionHeader('Outils'),
          NxCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Options pour les développeurs', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Débogage, animations, rendu, réseau — appliqués en direct', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevOptionsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Journal système en direct', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('logcat live, filtres, pause, copie', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLogcatScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class DevOptionsScreen extends StatefulWidget {
  const DevOptionsScreen({super.key});

  @override
  State<DevOptionsScreen> createState() => _DevOptionsScreenState();
}

class _DevOptionsScreenState extends State<DevOptionsScreen> {
  Map<String, String?> _values = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await Native.getSettings(allDevKeys());
    if (mounted) {
      setState(() {
        _values = v;
        _loading = false;
      });
    }
  }

  Future<void> _set(String ns, String key, String value) async {
    final err = await Native.putSetting(ns, key, value);
    if (!mounted) return;
    if (err != null && err.isNotEmpty) {
      showSnack(context, err);
    } else {
      setState(() => _values['$ns:$key'] = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Options développeur')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NxCard(
                  child: Text(
                    'Ces réglages exigent WRITE_SECURE_SETTINGS (via ADB) ou le root. Sans l’un des deux, '
                    'l’écriture est refusée et NiTroiD te le signale.',
                    style: TextStyle(fontSize: 12, color: NxColors.muted),
                  ),
                ),
                for (final g in devGroups) ...[
                  SectionHeader(g.title),
                  NxCard(
                    child: Column(children: [
                      for (final t in g.toggles)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.title),
                          subtitle: t.desc == null ? null : Text(t.desc!, style: const TextStyle(fontSize: 11)),
                          value: isToggleOn(t, _values[t.full]),
                          onChanged: (v) => _set(t.ns, t.key, v ? t.onValue : t.offValue),
                        ),
                      for (final c in g.choices) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final opt in c.options)
                            ChoiceChip(
                              label: Text(opt.key),
                              selected: _values[c.full] == opt.value,
                              onSelected: (_) => _set(c.ns, c.key, opt.value),
                            ),
                        ]),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class LiveLogcatScreen extends StatefulWidget {
  const LiveLogcatScreen({super.key});

  @override
  State<LiveLogcatScreen> createState() => _LiveLogcatScreenState();
}

class _LiveLogcatScreenState extends State<LiveLogcatScreen> {
  final _lines = <String>[];
  final _controller = ScrollController();
  StreamSubscription<String>? _sub;
  bool _paused = false;
  bool _errorsOnly = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _sub = Native.logcatStream().listen((line) {
      if (_paused || !mounted) return;
      setState(() {
        _lines.add(line);
        if (_lines.length > 5000) _lines.removeRange(0, 1000);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var lines = _lines;
    if (_errorsOnly) lines = lines.where((l) => RegExp(r'\s[EF]\s|FATAL|Exception|ANR').hasMatch(l)).toList();
    if (_filter.isNotEmpty) lines = lines.where((l) => l.toLowerCase().contains(_filter)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Logcat en direct'), actions: [
        IconButton(
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          tooltip: _paused ? 'Reprendre' : 'Pause',
          onPressed: () => setState(() => _paused = !_paused),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: lines.take(2000).join('\n')));
            showSnack(context, 'Copié');
          },
        ),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(_lines.clear)),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filtrer'),
                onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              ),
            ),
            FilterChip(label: const Text('Erreurs'), selected: _errorsOnly, onSelected: (v) => setState(() => _errorsOnly = v)),
          ]),
        ),
        Expanded(
          child: _lines.isEmpty
              ? const EmptyState(
                  icon: Icons.hourglass_empty,
                  text: 'En attente du journal…\nAvec la permission READ_LOGS, tout le système s’affiche.')
              : ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.all(8),
                  itemCount: lines.length,
                  itemBuilder: (_, i) {
                    final l = lines[i];
                    final color = RegExp(r'\s[EF]\s|FATAL').hasMatch(l)
                        ? NxColors.bad
                        : RegExp(r'\sW\s').hasMatch(l)
                            ? NxColors.warn
                            : null;
                    return Text(l, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: color));
                  },
                ),
        ),
      ]),
    );
  }
}
