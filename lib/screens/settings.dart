import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/settings_catalog.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'apps.dart';

class SettingsHub extends StatelessWidget {
  const SettingsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final android = Native.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramétrage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (android) ...[
            _tile(context, Icons.home_outlined, 'Lanceurs (launchers)', 'Voir, ouvrir et changer le lanceur par défaut',
                const LaunchersScreen()),
            _tile(context, Icons.tune, 'Réglages avancés', 'Animations, DNS privé, écran allumé, luminosité…',
                const TweaksScreen()),
            _tile(context, Icons.admin_panel_settings_outlined, 'Débloquer les accès (ADB)',
                'Donner à NiTroiD les permissions cachées depuis un PC', const AdbGuideScreen()),
          ],
          for (final group in android ? androidSettings : iosSettings) ...[
            SectionHeader(group.title),
            NxCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final s in group.items)
                  ListTile(
                    dense: true,
                    leading: Icon(s.hidden ? Icons.visibility_off_outlined : Icons.settings_outlined, size: 20),
                    title: Text(s.title),
                    subtitle: s.note == null ? null : Text(s.note!, style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _open(context, s),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NxCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        ),
      );

  Future<void> _open(BuildContext context, SettingsShortcut s) async {
    final component = s.component;
    bool ok;
    if (component != null) {
      final parts = component.split('/');
      ok = await Native.openComponent(parts[0], parts[1]);
    } else {
      ok = await Native.openSettings(s.action);
    }
    if (!ok && context.mounted) {
      showSnack(context, s.hidden ? 'Menu absent ou verrouillé par le constructeur' : 'Écran indisponible sur cet appareil');
    }
  }
}

class LaunchersScreen extends StatefulWidget {
  const LaunchersScreen({super.key});

  @override
  State<LaunchersScreen> createState() => _LaunchersScreenState();
}

class _LaunchersScreenState extends State<LaunchersScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _data;

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
    final d = await Native.launchers();
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final list = (data?['list'] as List?) ?? const [];
    final current = data?['default']?.toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Lanceurs')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NxCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                      'Android réserve le choix du lanceur à l’utilisateur : NiTroiD liste ceux qui sont installés '
                      'et ouvre directement l’écran système pour en changer.',
                      style: TextStyle(color: NxColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Native.openSettings('android.settings.HOME_SETTINGS'),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Changer le lanceur par défaut'),
                    ),
                  ]),
                ),
                SectionHeader('Installés (${list.length})'),
                for (final l in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NxCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: AppIcon(l['pkg'].toString()),
                        title: Text(l['label'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(l['pkg'].toString(), style: const TextStyle(fontSize: 11)),
                        trailing: l['pkg'] == current
                            ? const Chip(label: Text('Par défaut'), visualDensity: VisualDensity.compact)
                            : IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Ouvrir',
                                onPressed: () => Native.openComponent(l['pkg'].toString(), l['cls'].toString()),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class TweaksScreen extends StatefulWidget {
  const TweaksScreen({super.key});

  @override
  State<TweaksScreen> createState() => _TweaksScreenState();
}

class _TweaksScreenState extends State<TweaksScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _t;

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
    final t = await Native.tweaks();
    if (mounted) setState(() => _t = t);
  }

  Future<void> _set(String key, Object value) async {
    final err = await Native.setTweak(key, value);
    if (!mounted) return;
    if (err != null && err.isNotEmpty) showSnack(context, err);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return Scaffold(appBar: AppBar(title: const Text('Réglages avancés')), body: const Center(child: CircularProgressIndicator()));
    final ws = t['writeSettings'] == true;
    final wss = t['writeSecure'] == true;
    double anim(String k) => double.tryParse(t[k]?.toString() ?? '') ?? 1.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages avancés')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader('Écran', trailing: _badge(ws)),
          if (!ws)
            _unlock('Autorise « Modifier les paramètres système » pour NiTroiD.',
                () => Native.openSettings('android.settings.action.MANAGE_WRITE_SETTINGS')),
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mise en veille de l’écran'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, ms) in const [('15 s', 15000), ('30 s', 30000), ('1 min', 60000), ('2 min', 120000), ('5 min', 300000), ('10 min', 600000), ('30 min', 1800000)])
                  ChoiceChip(
                    label: Text(label),
                    selected: t['screen_off_timeout']?.toString() == ms.toString(),
                    onSelected: ws ? (_) => _set('screen_off_timeout', ms) : null,
                  ),
              ]),
              const SizedBox(height: 16),
              Text('Luminosité (${t['screen_brightness'] ?? '?'}/255)'),
              Slider(
                value: (double.tryParse(t['screen_brightness']?.toString() ?? '') ?? 128).clamp(1, 255),
                min: 1,
                max: 255,
                onChanged: ws ? (v) => setState(() => t['screen_brightness'] = v.round()) : null,
                onChangeEnd: ws ? (v) => _set('screen_brightness', v.round()) : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Luminosité adaptative'),
                value: t['screen_brightness_mode']?.toString() == '1',
                onChanged: ws ? (v) => _set('screen_brightness_mode', v ? 1 : 0) : null,
              ),
            ]),
          ),
          SectionHeader('Système (permission cachée)', trailing: _badge(wss)),
          if (!wss)
            _unlock('Ces réglages exigent WRITE_SECURE_SETTINGS, accordable une fois via ADB.',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdbGuideScreen()))),
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (key, label) in const [
                ('window_animation_scale', 'Animations des fenêtres'),
                ('transition_animation_scale', 'Animations de transition'),
                ('animator_duration_scale', 'Durée des animations'),
              ]) ...[
                Text('$label : ×${anim(key)}'),
                Wrap(spacing: 6, children: [
                  for (final v in const [0.0, 0.5, 1.0, 1.5, 2.0])
                    ChoiceChip(label: Text(v == 0 ? 'off' : '×$v'), selected: anim(key) == v, onSelected: wss ? (_) => _set(key, v) : null),
                ]),
                const SizedBox(height: 12),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rester allumé pendant la charge'),
                value: (int.tryParse(t['stay_on_while_plugged_in']?.toString() ?? '0') ?? 0) != 0,
                onChanged: wss ? (v) => _set('stay_on_while_plugged_in', v ? 7 : 0) : null,
              ),
              const SizedBox(height: 8),
              const Text('DNS privé (DNS-over-TLS)'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ChoiceChip(
                  label: const Text('Désactivé'),
                  selected: t['private_dns_mode'] == 'off',
                  onSelected: wss ? (_) => _set('private_dns', 'off') : null,
                ),
                ChoiceChip(
                  label: const Text('Automatique'),
                  selected: t['private_dns_mode'] == 'opportunistic',
                  onSelected: wss ? (_) => _set('private_dns', 'opportunistic') : null,
                ),
                for (final (label, host) in const [
                  ('Cloudflare', 'one.one.one.one'),
                  ('Quad9', 'dns.quad9.net'),
                  ('AdGuard (anti-pub)', 'dns.adguard-dns.com'),
                  ('Google', 'dns.google'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: t['private_dns_mode'] == 'hostname' && t['private_dns_specifier'] == host,
                    onSelected: wss ? (_) => _set('private_dns', host) : null,
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _badge(bool ok) => Text(ok ? 'autorisé' : 'verrouillé',
      style: TextStyle(fontSize: 11, color: ok ? NxColors.ok : NxColors.warn, fontWeight: FontWeight.w700));

  Widget _unlock(String text, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NxCard(
          onTap: onTap,
          child: Row(children: [
            const Icon(Icons.lock_outline, color: NxColors.warn),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
}

class AdbGuideScreen extends StatefulWidget {
  const AdbGuideScreen({super.key});

  static const package = 'com.heiphaistos.nitroid';

  @override
  State<AdbGuideScreen> createState() => _AdbGuideScreenState();
}

class _AdbGuideScreenState extends State<AdbGuideScreen> {
  Map<String, dynamic> _perms = {};

  static const _grants = [
    ('writeSecure', 'WRITE_SECURE_SETTINGS', 'Réglages avancés : animations, DNS privé, écran allumé'),
    ('readLogs', 'READ_LOGS', 'Journal système complet (logcat de tout l’appareil)'),
    ('dump', 'DUMP', 'dumpsys : batterie détaillée, mémoire par app, Wi-Fi, capteurs…'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await Native.permissions();
    if (mounted) setState(() => _perms = p);
  }

  @override
  Widget build(BuildContext context) {
    final all = _grants.map((g) => 'adb shell pm grant ${AdbGuideScreen.package} android.permission.${g.$2}').join('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Accès avancés (ADB)'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NxCard(
            child: Text(
              'Sans root, Android garde certaines permissions pour les outils de développement. '
              'Elles s’accordent une seule fois depuis un PC :\n\n'
              '1. Active les Options pour les développeurs puis le Débogage USB.\n'
              '2. Branche le téléphone et installe les platform-tools (adb).\n'
              '3. Lance les commandes ci-dessous. Elles restent actives jusqu’à la désinstallation.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SectionHeader('État'),
          NxCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (key, perm, desc) in _grants)
                ListTile(
                  leading: StatusDot(_perms[key] == true ? 'ok' : 'warn'),
                  title: Text(perm, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
                ),
            ]),
          ),
          const SectionHeader('Commandes'),
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SelectableText(all, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: all));
                  showSnack(context, 'Commandes copiées');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Native.openSettings('android.settings.APPLICATION_DEVELOPMENT_SETTINGS'),
            icon: const Icon(Icons.developer_mode),
            label: const Text('Ouvrir les options développeur'),
          ),
        ],
      ),
    );
  }
}
