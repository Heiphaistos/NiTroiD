import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/privacy.dart';
import '../core/theme.dart';
import '../core/threats.dart';
import '../widgets/common.dart';
import 'apps.dart';

const _icons = <String, IconData>{
  'location': Icons.location_on_outlined,
  'camera': Icons.photo_camera_outlined,
  'mic': Icons.mic_none,
  'contacts': Icons.contacts_outlined,
  'sms': Icons.sms_outlined,
  'calls': Icons.call_outlined,
  'media': Icons.photo_library_outlined,
  'calendar': Icons.calendar_month_outlined,
  'body': Icons.favorite_border,
  'nearby': Icons.bluetooth_searching,
  'screen': Icons.visibility_outlined,
  'control': Icons.admin_panel_settings_outlined,
};

/// Tableau de bord « qui a accès à quoi ».
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  List<AppEntry>? _apps;
  ThreatDb? _db;
  bool _system = false;

  @override
  void initState() {
    super.initState();
    ThreatDb.load().then((db) => _db = db);
    _load();
  }

  Future<void> _load() async {
    setState(() => _apps = null);
    final apps = await Native.apps(includeSystem: true);
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final groups = apps == null ? null : groupByPrivacy(apps, includeSystem: _system);
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: groups == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const NxCard(
                  child: Text(
                    'Qui a accès à quoi : chaque catégorie liste les applications qui ont reçu l’autorisation. '
                    'Touche une application pour la révoquer ou la désinstaller.',
                    style: TextStyle(fontSize: 13, color: NxColors.muted),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Inclure les applications système'),
                  value: _system,
                  onChanged: (v) => setState(() => _system = v),
                ),
                for (final entry in groups.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NxCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        shape: const Border(),
                        leading: Icon(_icons[entry.key.id] ?? Icons.lock_outline,
                            color: entry.value.isEmpty ? NxColors.muted : NxColors.primary),
                        title: Text(entry.key.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (entry.value.isEmpty ? NxColors.muted : NxColors.primary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${entry.value.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        children: [
                          if (entry.value.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Aucune application.', style: TextStyle(color: NxColors.muted)),
                            ),
                          for (final a in entry.value)
                            ListTile(
                              dense: true,
                              leading: AppIcon(a.package, size: 32),
                              title: Text(a.label),
                              subtitle: Text(a.package, style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AppDetailScreen(app: a, risk: assessApp(a, _db))),
                              ).then((_) => _load()),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
