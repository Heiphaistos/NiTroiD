import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Analyse détaillée du root (Android) ou du jailbreak (iOS).
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  // Gestionnaires de root connus : on tente de les ouvrir s'ils sont installés.
  static const _managers = [
    'com.topjohnwu.magisk',
    'io.github.vvb2060.magisk',
    'me.weishu.kernelsu',
    'me.bmax.apatch',
  ];

  Future<void> _openManager(BuildContext context) async {
    for (final pkg in _managers) {
      if (await Native.launchApp(pkg)) return;
    }
    if (context.mounted) showSnack(context, 'Aucun gestionnaire de root (Magisk, KernelSU…) installé');
  }

  @override
  Widget build(BuildContext context) {
    final android = Native.isAndroid;
    return InfoScreen(
      title: android ? 'Root' : 'Jailbreak',
      category: 'root',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(android ? Icons.terminal : Icons.lock_open, color: NxColors.primary),
                const SizedBox(width: 8),
                Text(android ? 'Accès superutilisateur' : 'Intégrité du système',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(
                android
                    ? 'NiTroiD détecte le root (Magisk, KernelSU, APatch…), les applications qui le demandent, '
                      'les modules installés et l’état du bootloader. Le root donne un contrôle total mais '
                      'affaiblit l’isolation entre applications : n’accorde l’accès qu’aux apps de confiance.'
                    : 'NiTroiD recherche les traces de jailbreak (Cydia, Sileo, bibliothèques injectées, '
                      'écriture hors du bac à sable). Un jailbreak désactive les protections d’iOS.',
                style: TextStyle(color: NxColors.muted, fontSize: 13),
              ),
              if (android) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () => _openManager(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ouvrir le gestionnaire de root'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Native.openSettings('android.settings.APPLICATION_DEVELOPMENT_SETTINGS'),
                    icon: const Icon(Icons.developer_mode, size: 18),
                    label: const Text('Options développeur'),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
