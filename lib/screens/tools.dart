import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/benchmark.dart';
import '../core/format.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'apps.dart';
import 'lan.dart';
import 'privacy.dart';
import 'report.dart';

class ToolsHub extends StatelessWidget {
  const ToolsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final android = Native.isAndroid;
    final groups = <(String, List<(IconData, String, String, Widget)>)>[
      if (android)
        ('Applications', [
          (Icons.apps, 'Gestionnaire d’applications', 'Lister, analyser, désinstaller', const AppsScreen()),
          (Icons.timer_outlined, 'Temps d’écran', 'Utilisation par application', const UsageScreen()),
          (Icons.privacy_tip_outlined, 'Confidentialité', 'Qui a accès à la caméra, au micro, aux SMS…', const PrivacyScreen()),
        ]),
      ('Tests matériel', [
        (Icons.palette_outlined, 'Écran : pixels morts', 'Couleurs plein écran', const ScreenTest()),
        (Icons.touch_app_outlined, 'Écran tactile', 'Zones mortes et multipoint', const TouchTest()),
        (Icons.vibration, 'Vibreur, flash & haut-parleur', 'Tests rapides des actionneurs', const ActuatorTest()),
      ]),
      ('Performances', [
        (Icons.speed, 'Benchmark', 'CPU, mémoire, stockage', const BenchmarkScreen()),
      ]),
      ('Réseau', [
        (Icons.network_ping, 'Outils réseau', 'Ping, DNS, port, IP publique, débit', const NetworkTools()),
        (Icons.lan_outlined, 'Appareils du réseau', 'Qui est connecté à ton Wi-Fi', const LanScreen()),
        if (android) (Icons.wifi_find, 'Analyseur Wi-Fi', 'Réseaux voisins, canaux, signal', const WifiScanScreen()),
      ]),
      if (android)
        ('Système avancé', [
          (Icons.receipt_long, 'Journal système (logcat)', 'Erreurs et événements récents', const ShellToolScreen(tool: 'logcat', title: 'Logcat')),
          (Icons.bug_report_outlined, 'dumpsys', 'État interne des services Android', const DumpsysScreen()),
          (Icons.folder_open, 'Explorateur /proc & /sys', 'Fichiers noyau lisibles', const ProcExplorer(path: '/proc')),
        ]),
      ('Rapport', [
        (Icons.description_outlined, 'Rapport de diagnostic', 'Exporter et partager (TXT, Markdown, JSON)', const ReportScreen()),
      ]),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Outils')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, items) in groups) ...[
            SectionHeader(title),
            NxCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (icon, t, sub, page) in items)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
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

class ScreenTest extends StatefulWidget {
  const ScreenTest({super.key});

  @override
  State<ScreenTest> createState() => _ScreenTestState();
}

class _ScreenTestState extends State<ScreenTest> {
  static const _colors = [Colors.red, Colors.green, Colors.blue, Colors.white, Colors.black, Color(0xFF808080)];
  int _i = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_i == _colors.length - 1) {
          Navigator.pop(context);
        } else {
          setState(() => _i++);
        }
      },
      child: Container(
        color: _colors[_i],
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.all(32),
        child: _i == 0
            ? const Text('Touchez pour changer de couleur — repérez les points qui ne changent pas',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, decoration: TextDecoration.none, fontSize: 14))
            : null,
      ),
    );
  }
}

class TouchTest extends StatefulWidget {
  const TouchTest({super.key});

  @override
  State<TouchTest> createState() => _TouchTestState();
}

class _TouchTestState extends State<TouchTest> {
  static const _cols = 8;
  static const _rows = 14;
  final _hit = <int>{};
  final _pointers = <int, Offset>{};
  int _maxPointers = 0;

  void _mark(Offset p, Size size) {
    final c = (p.dx / size.width * _cols).floor().clamp(0, _cols - 1);
    final r = (p.dy / size.height * _rows).floor().clamp(0, _rows - 1);
    _hit.add(r * _cols + c);
  }

  @override
  Widget build(BuildContext context) {
    final done = _hit.length == _cols * _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Écran tactile OK ✔' : 'Glissez sur toutes les cases (${_hit.length}/${_cols * _rows})'),
        actions: [IconButton(onPressed: () => setState(_hit.clear), icon: const Icon(Icons.refresh))],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return Listener(
          onPointerDown: (e) => setState(() {
            _pointers[e.pointer] = e.localPosition;
            if (_pointers.length > _maxPointers) _maxPointers = _pointers.length;
            _mark(e.localPosition, size);
          }),
          onPointerMove: (e) => setState(() {
            _pointers[e.pointer] = e.localPosition;
            _mark(e.localPosition, size);
          }),
          onPointerUp: (e) => setState(() => _pointers.remove(e.pointer)),
          onPointerCancel: (e) => setState(() => _pointers.remove(e.pointer)),
          child: Stack(children: [
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: _cols,
              childAspectRatio: (size.width / _cols) / (size.height / _rows),
              children: [
                for (var i = 0; i < _cols * _rows; i++)
                  Container(
                    margin: const EdgeInsets.all(1),
                    color: _hit.contains(i) ? NxColors.ok.withValues(alpha: 0.6) : NxColors.surfaceHigh,
                  ),
              ],
            ),
            for (final p in _pointers.values)
              Positioned(
                left: p.dx - 30,
                top: p.dy - 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: NxColors.primary, width: 3)),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text('Doigts simultanés : ${_pointers.length} (max $_maxPointers)'),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class ActuatorTest extends StatefulWidget {
  const ActuatorTest({super.key});

  @override
  State<ActuatorTest> createState() => _ActuatorTestState();
}

class _ActuatorTestState extends State<ActuatorTest> {
  bool _torch = false;

  @override
  void dispose() {
    if (_torch) Native.torch(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actionneurs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Vibreur', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => Native.vibrate(80, amplitude: 80), child: const Text('Léger')),
                OutlinedButton(onPressed: () => Native.vibrate(300), child: const Text('Fort')),
                OutlinedButton(onPressed: () => Native.vibrate(1500), child: const Text('Long')),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          NxCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lampe torche (flash)', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _torch,
              onChanged: (v) async {
                final ok = await Native.torch(v);
                if (!context.mounted) return;
                if (ok) {
                  setState(() => _torch = v);
                } else {
                  showSnack(context, 'Flash indisponible');
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Haut-parleur', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Émet un bip de test : il doit être net, sans grésillement.',
                  style: TextStyle(color: NxColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Native.tone(800),
                icon: const Icon(Icons.volume_up),
                label: const Text('Jouer le son'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final _results = <BenchResult>[];
  String? _step;

  Future<void> _run() async {
    setState(() {
      _results.clear();
      _step = 'CPU mono-cœur…';
    });
    _add(await benchSingleCore());
    setState(() => _step = 'CPU multi-cœur…');
    _add(await benchMultiCore());
    setState(() => _step = 'Mémoire…');
    _add(await benchMemory());
    setState(() => _step = 'Stockage…');
    final dir = await getTemporaryDirectory();
    for (final r in await benchStorage(dir)) {
      _add(r);
    }
    setState(() => _step = null);
  }

  void _add(BenchResult r) {
    if (mounted) setState(() => _results.add(r));
  }

  @override
  Widget build(BuildContext context) {
    final total = _results.fold<int>(0, (a, r) => a + (r.score ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(children: [
              Text(_results.isEmpty ? '—' : '$total',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: NxColors.primary)),
              const Text('score NiTroiD', style: TextStyle(color: NxColors.muted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _step == null ? _run : null,
                icon: _step == null
                    ? const Icon(Icons.play_arrow)
                    : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                label: Text(_step ?? 'Lancer (≈15 s)'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final r in _results)
            ListTile(
              title: Text(r.label),
              subtitle: Text('${r.value.toStringAsFixed(1)} ${r.unit}'),
              trailing: Text('${r.score ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Le score permet de comparer deux téléphones ou de repérer un appareil qui bride (chauffe, '
              'mode économie). Relancez téléphone froid pour un résultat représentatif.',
              style: TextStyle(color: NxColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkTools extends StatefulWidget {
  const NetworkTools({super.key});

  @override
  State<NetworkTools> createState() => _NetworkToolsState();
}

class _NetworkToolsState extends State<NetworkTools> {
  final _host = TextEditingController(text: 'one.one.one.one');
  final _port = TextEditingController(text: '443');
  String _out = '';
  bool _busy = false;

  Future<void> _run(Future<String> Function() task) async {
    setState(() {
      _busy = true;
      _out = '…';
    });
    String out;
    try {
      out = await task();
    } catch (e) {
      out = 'Erreur : $e';
    }
    if (mounted) {
      setState(() {
        _out = out;
        _busy = false;
      });
    }
  }

  Future<String> _ping() async {
    final host = _host.text.trim();
    if (Native.isAndroid) {
      final r = await Native.exec('ping', {'host': host});
      if (r.trim().isNotEmpty) return r;
    }
    // Repli : latence d'établissement TCP.
    final buf = StringBuffer('Latence TCP vers $host:443\n');
    for (var i = 0; i < 4; i++) {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(host, 443, timeout: const Duration(seconds: 3));
      buf.writeln('  essai ${i + 1} : ${sw.elapsedMilliseconds} ms');
      s.destroy();
    }
    return buf.toString();
  }

  Future<String> _dns() async {
    final sw = Stopwatch()..start();
    final res = await InternetAddress.lookup(_host.text.trim());
    return 'Résolu en ${sw.elapsedMilliseconds} ms\n${res.map((a) => '${a.type.name.padRight(5)} ${a.address}').join('\n')}';
  }

  Future<String> _portCheck() async {
    final port = int.tryParse(_port.text) ?? 443;
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(_host.text.trim(), port, timeout: const Duration(seconds: 4));
      s.destroy();
      return 'Port $port OUVERT (${sw.elapsedMilliseconds} ms)';
    } on SocketException catch (e) {
      return 'Port $port fermé ou filtré (${e.osError?.message ?? e.message})';
    }
  }

  Future<String> _get(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final res = await (await c.getUrl(Uri.parse(url))).close();
      return (await res.transform(const SystemEncoding().decoder).join()).trim();
    } finally {
      c.close();
    }
  }

  Future<String> _publicIp() async {
    final v4 = await _get('https://api.ipify.org').catchError((_) => 'indisponible');
    final v6 = await _get('https://api64.ipify.org').catchError((_) => 'indisponible');
    return 'IPv4 publique : $v4\nIP préférée (v6 si dispo) : $v6';
  }

  Future<String> _speed() async {
    const bytes = 25 * 1000 * 1000;
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final latency = Stopwatch()..start();
      final req = await c.getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=$bytes'));
      final res = await req.close();
      final ttfb = latency.elapsedMilliseconds;
      final sw = Stopwatch()..start();
      var received = 0;
      await for (final chunk in res) {
        received += chunk.length;
      }
      final mbps = received * 8 / 1e6 / (sw.elapsedMicroseconds / 1e6);
      return 'Téléchargement : ${mbps.toStringAsFixed(1)} Mbit/s\n'
          'Données : ${formatBytes(received)} · premier octet : $ttfb ms\n(serveur Cloudflare le plus proche)';
    } finally {
      c.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outils réseau')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _host, decoration: const InputDecoration(labelText: 'Hôte'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonal(onPressed: _busy ? null : () => _run(_ping), child: const Text('Ping')),
            FilledButton.tonal(onPressed: _busy ? null : () => _run(_dns), child: const Text('DNS')),
            FilledButton.tonal(onPressed: _busy ? null : () => _run(_portCheck), child: const Text('Port')),
            FilledButton.tonal(onPressed: _busy ? null : () => _run(_publicIp), child: const Text('IP publique')),
            FilledButton.tonal(onPressed: _busy ? null : () => _run(_speed), child: const Text('Test de débit')),
          ]),
          const SizedBox(height: 16),
          NxCard(
            child: SelectableText(_out.isEmpty ? 'Résultats ici.' : _out,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class WifiScanScreen extends StatefulWidget {
  const WifiScanScreen({super.key});

  @override
  State<WifiScanScreen> createState() => _WifiScanScreenState();
}

class _WifiScanScreenState extends State<WifiScanScreen> {
  List<Map<String, dynamic>>? _nets;
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final perms = await Native.permissions();
    if (perms['location'] != true) {
      if (mounted) setState(() => _needsPermission = true);
      return;
    }
    setState(() {
      _needsPermission = false;
      _nets = null;
    });
    final nets = await Native.wifiScan();
    nets.sort((a, b) => (b['level'] as num).compareTo(a['level'] as num));
    if (mounted) setState(() => _nets = nets);
  }

  @override
  Widget build(BuildContext context) {
    final nets = _nets;
    return Scaffold(
      appBar: AppBar(title: const Text('Analyseur Wi-Fi'), actions: [IconButton(onPressed: _scan, icon: const Icon(Icons.refresh))]),
      body: _needsPermission
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Android exige la permission de localisation pour lister les réseaux Wi-Fi voisins.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await Native.requestPermission('location');
                    await Future.delayed(const Duration(seconds: 1));
                    _scan();
                  },
                  child: const Text('Autoriser'),
                ),
              ]),
            )
          : nets == null
              ? const Center(child: CircularProgressIndicator())
              : nets.isEmpty
                  ? const EmptyState(icon: Icons.wifi_off, text: 'Aucun réseau trouvé (Wi-Fi désactivé ou scan limité par Android).')
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: nets.length,
                      itemBuilder: (_, i) {
                        final n = nets[i];
                        final level = (n['level'] as num).toInt();
                        final status = level > -60 ? 'ok' : level > -75 ? 'warn' : 'bad';
                        return ListTile(
                          leading: Icon(Icons.wifi, color: NxColors.forStatus(status)),
                          title: Text((n['ssid'] as String?)?.isNotEmpty == true ? n['ssid'] : '(réseau masqué)'),
                          subtitle: Text('${n['bssid']} · canal ${n['channel']} · ${n['band']} · ${n['security']}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text('$level dBm', style: TextStyle(color: NxColors.forStatus(status), fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
    );
  }
}

/// Affiche la sortie d'un outil natif (logcat, dumpsys…).
class ShellToolScreen extends StatefulWidget {
  const ShellToolScreen({super.key, required this.tool, required this.title, this.args = const {}});

  final String tool;
  final String title;
  final Map<String, dynamic> args;

  @override
  State<ShellToolScreen> createState() => _ShellToolScreenState();
}

class _ShellToolScreenState extends State<ShellToolScreen> {
  String? _out;
  String _filter = '';
  bool _errorsOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _out = null);
    final out = await Native.exec(widget.tool, widget.args);
    if (mounted) setState(() => _out = out);
  }

  @override
  Widget build(BuildContext context) {
    var lines = (_out ?? '').split('\n');
    if (_errorsOnly) lines = lines.where((l) => RegExp(r'\s[EF]\s|FATAL|Exception|ANR').hasMatch(l)).toList();
    if (_filter.isNotEmpty) lines = lines.where((l) => l.toLowerCase().contains(_filter)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: lines.join('\n')));
            showSnack(context, 'Copié');
          },
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
            if (widget.tool == 'logcat')
              FilterChip(label: const Text('Erreurs'), selected: _errorsOnly, onSelected: (v) => setState(() => _errorsOnly = v)),
          ]),
        ),
        Expanded(
          child: _out == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
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

class DumpsysScreen extends StatelessWidget {
  const DumpsysScreen({super.key});

  static const _services = [
    ('battery', 'Batterie (santé, cycles selon constructeur)'),
    ('batterystats --charged', 'Consommation par application'),
    ('meminfo', 'Mémoire par processus'),
    ('cpuinfo', 'Charge CPU par processus'),
    ('thermalservice', 'Capteurs thermiques et seuils'),
    ('wifi', 'Wi-Fi détaillé'),
    ('connectivity', 'Réseaux et connectivité'),
    ('sensorservice', 'Capteurs et clients'),
    ('display', 'Écrans et modes'),
    ('package', 'Paquets (très long)'),
    ('diskstats', 'Stockage et latence'),
    ('deviceidle', 'Mode Doze'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dumpsys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NxCard(
            child: Text(
              'dumpsys interroge directement les services internes d’Android. '
              'Il nécessite la permission DUMP (Paramétrage › Débloquer les accès).',
              style: TextStyle(fontSize: 13, color: NxColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          for (final (svc, desc) in _services)
            ListTile(
              leading: const Icon(Icons.terminal),
              title: Text(svc, style: const TextStyle(fontFamily: 'monospace')),
              subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShellToolScreen(tool: 'dumpsys', title: 'dumpsys $svc', args: {'service': svc}),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProcExplorer extends StatefulWidget {
  const ProcExplorer({super.key, required this.path});

  final String path;

  @override
  State<ProcExplorer> createState() => _ProcExplorerState();
}

class _ProcExplorerState extends State<ProcExplorer> {
  List<Map<String, dynamic>>? _entries;

  @override
  void initState() {
    super.initState();
    Native.listDir(widget.path).then((e) {
      e.sort((a, b) {
        final d = (b['dir'] == true ? 1 : 0) - (a['dir'] == true ? 1 : 0);
        return d != 0 ? d : a['name'].toString().compareTo(b['name'].toString());
      });
      if (mounted) setState(() => _entries = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 15)),
        actions: [
          if (widget.path == '/proc')
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcExplorer(path: '/sys'))),
              child: const Text('/sys'),
            ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const EmptyState(icon: Icons.lock_outline, text: 'Dossier vide ou interdit par SELinux.')
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final path = '${widget.path}/${e['name']}';
                    final dir = e['dir'] == true;
                    final readable = e['readable'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(dir ? Icons.folder : Icons.description_outlined,
                          color: readable ? NxColors.primary : NxColors.muted, size: 20),
                      title: Text(e['name'].toString(),
                          style: TextStyle(fontFamily: 'monospace', color: readable ? null : NxColors.muted)),
                      onTap: !readable
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => dir ? ProcExplorer(path: path) : _FileView(path: path)),
                              ),
                    );
                  },
                ),
    );
  }
}

class _FileView extends StatelessWidget {
  const _FileView({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(path.split('/').last, style: const TextStyle(fontFamily: 'monospace'))),
      body: FutureBuilder<String?>(
        future: Native.readFile(path),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(snap.data ?? '(illisible)', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          );
        },
      ),
    );
  }
}
