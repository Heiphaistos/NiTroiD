import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// ADB sans PC : appairage au « Débogage sans fil », puis droits ADB dans l'app.
class AdbWirelessScreen extends StatefulWidget {
  const AdbWirelessScreen({super.key});

  @override
  State<AdbWirelessScreen> createState() => _AdbWirelessScreenState();
}

class _AdbWirelessScreenState extends State<AdbWirelessScreen> with WidgetsBindingObserver {
  Map<String, dynamic> _s = {};
  bool _busy = false;
  Timer? _poll;
  final _code = TextEditingController();
  final _port = TextEditingController();

  bool get _connected => _s['connected'] == true;
  bool get _paired => _s['paired'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _code.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await Native.adbStatus();
    if (!mounted) return;
    setState(() => _s = s);
    final port = s['pairingPort'];
    if (port is int && port > 0 && _port.text.isEmpty) _port.text = '$port';
    // Pendant la recherche, on suit l'arrivée du port d'association.
    _poll?.cancel();
    if (s['searching'] == true) _poll = Timer(const Duration(seconds: 2), _refresh);
  }

  Future<void> _act(Future<String?> Function() action, String success) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, err == null || err.isEmpty ? success : err);
    _refresh();
  }

  Future<void> _startPairing() async {
    await Native.requestPermission('notifications');
    await Native.adbSearch();
    await Native.openSettings('android.settings.APPLICATION_DEVELOPMENT_SETTINGS');
    _refresh();
  }

  Future<void> _pairManually() => _act(() async {
        final err = await Native.adbPair(_code.text.trim(), port: int.tryParse(_port.text.trim()) ?? -1);
        return err ?? await Native.adbConnect();
      }, 'Associé et connecté');

  Future<void> _grantAll() async {
    setState(() => _busy = true);
    final res = await Native.grantSelf();
    if (!mounted) return;
    setState(() => _busy = false);
    final results = (res['results'] as List?) ?? [];
    final ok = results.where((r) => r['ok'] == true).length;
    showSnack(context, results.isEmpty ? 'Ni root ni ADB connecté' : '$ok/${results.length} permissions accordées');
  }

  @override
  Widget build(BuildContext context) {
    final supported = _s['supported'] != false;
    final mode = _s['mode'] ?? 'none';
    return Scaffold(
      appBar: AppBar(title: const Text('ADB sans fil'), actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_connected ? Icons.link : Icons.link_off, color: _connected ? NxColors.ok : NxColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !supported
                        ? 'Android 11 ou plus requis'
                        : _connected
                            ? 'ADB connecté — droits ADB actifs'
                            : _paired
                                ? 'Associé, non connecté'
                                : 'Pas encore associé',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'NiTroiD se connecte au débogage sans fil du téléphone lui-même : les droits ADB '
                '(réglages cachés, permissions spéciales, applis système, journal complet) sans PC ni câble. '
                'Droits actuels : ${mode == 'root' ? 'root' : mode == 'adb' ? 'ADB' : 'aucun'}.',
                style: TextStyle(color: NxColors.muted, fontSize: 13),
              ),
              if (supported) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (_paired && !_connected)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _act(Native.adbConnect, 'Connecté'),
                      icon: const Icon(Icons.power),
                      label: const Text('Se connecter'),
                    ),
                  if (_connected) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _grantAll,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Accorder toutes les permissions'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivShellScreen())),
                      icon: const Icon(Icons.terminal),
                      label: const Text('Terminal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Native.adbDisconnect();
                        _refresh();
                      },
                      child: const Text('Déconnecter'),
                    ),
                  ],
                ]),
              ],
            ]),
          ),
          if (supported && !_connected) ...[
            const SectionHeader('Association (une seule fois)'),
            NxCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final step in const [
                  '1. Connecte le téléphone au Wi-Fi (n’importe lequel, sans Internet c’est OK).',
                  '2. Options pour les développeurs › « Débogage sans fil » › active-le.',
                  '3. Touche « Associer l’appareil avec un code ».',
                  '4. Une notification NiTroiD apparaît : « Saisir le code », tape les 6 chiffres. Rien à recopier ailleurs.',
                ])
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(step, style: const TextStyle(fontSize: 13))),
                Text(
                  'Pas d’options développeur ? Paramètres › À propos › touche 7 fois « Numéro de build ».',
                  style: TextStyle(color: NxColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _startPairing,
                  icon: Icon(_s['searching'] == true ? Icons.wifi_find : Icons.play_arrow),
                  label: Text(_s['searching'] == true ? 'Recherche en cours… (ouvrir les options)' : 'Commencer l’association'),
                ),
              ]),
            ),
            const SectionHeader('Ou saisie manuelle (écran partagé)'),
            NxCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Port (après « : »)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Code à 6 chiffres', counterText: ''),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(onPressed: _busy ? null : _pairManually, child: const Text('Associer')),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Le débogage sans fil se coupe quand le Wi-Fi change ou au redémarrage : NiTroiD le rallume tout seul '
            'une fois la permission « réglages système » accordée. Pour tout révoquer : Débogage sans fil › '
            'appareils associés › NiTroiD › Supprimer.',
            style: TextStyle(color: NxColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Terminal : commandes avec les droits root (si présent) ou ADB.
class PrivShellScreen extends StatefulWidget {
  const PrivShellScreen({super.key});

  @override
  State<PrivShellScreen> createState() => _PrivShellScreenState();
}

class _PrivShellScreenState extends State<PrivShellScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _log = StringBuffer();
  String _mode = '';
  bool _running = false;

  static const _examples = [
    'pm list packages -s',
    'dumpsys battery',
    'settings list global',
    'getprop ro.build.fingerprint',
    'cmd package list packages -d',
    'wm size',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? cmd]) async {
    final command = (cmd ?? _input.text).trim();
    if (command.isEmpty || _running) return;
    setState(() => _running = true);
    final res = await Native.privShell(command);
    if (!mounted) return;
    setState(() {
      _running = false;
      _mode = res['mode']?.toString() ?? '';
      _log.writeln('${_mode == 'root' ? '#' : '\$'} $command');
      _log.writeln((res['out'] ?? '').toString());
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_mode.isEmpty ? 'Terminal' : 'Terminal ($_mode)'), actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _log.toString()));
            showSnack(context, 'Copié');
          },
        ),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(_log.clear)),
      ]),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              for (final e in _examples)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(label: Text(e, style: const TextStyle(fontSize: 11)), onPressed: () => _send(e)),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              _log.isEmpty ? 'Tape une commande (droits root si disponibles, sinon ADB).' : _log.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(hintText: 'commande', prefixIcon: Icon(Icons.chevron_right)),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                onPressed: _running ? null : _send,
                icon: _running
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
