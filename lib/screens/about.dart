import 'dart:io';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/common.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.release});

  /// Release déjà récupérée (bandeau de l'accueil), pour éviter un second appel.
  final ReleaseInfo? release;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  List<String> _abis = [];
  ReleaseInfo? _release;
  String? _error;
  bool _checking = false;
  double? _progress;
  String? _status;
  File? _downloaded;

  @override
  void initState() {
    super.initState();
    _release = widget.release;
    Native.appInfo().then((info) {
      if (!mounted) return;
      setState(() {
        _version = info['version']?.toString() ?? '';
        _abis = (info['abis'] as List?)?.map((e) => e.toString()).toList() ?? [];
      });
      if (_release == null) _check();
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final r = await Updater.latest();
      if (mounted) setState(() => _release = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Vérification impossible : $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool get _updateAvailable =>
      _release != null && _version.isNotEmpty && compareVersions(_release!.version, _version) > 0;

  Future<void> _update() async {
    final asset = _release?.apkFor(_abis);
    if (asset == null) {
      Native.openUrl(_release?.pageUrl ?? Updater.releasesPage);
      return;
    }
    setState(() {
      _progress = 0;
      _status = 'Téléchargement de ${asset.name}…';
      _error = null;
    });
    try {
      final file = _downloaded ??
          await Updater.download(asset, (received, total) {
            if (!mounted) return;
            setState(() {
              _progress = total > 0 ? received / total : null;
              _status = '${formatBytes(received)} / ${formatBytes(total)}';
            });
          });
      _downloaded = file;
      if (!mounted) return;
      setState(() => _status = 'Ouverture de l’installateur…');
      final res = await Updater.install(file);
      if (!mounted) return;
      setState(() {
        _progress = null;
        _status = switch (res) {
          'ok' => 'Confirme l’installation dans la fenêtre Android.',
          'permission' => 'Autorise « Installer des applis inconnues » pour NiTroiD, reviens ici puis touche à nouveau Mettre à jour.',
          _ => null,
        };
        if (res == 'error') _error = 'L’installateur n’a pas pu s’ouvrir.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _status = null;
          _error = 'Échec du téléchargement : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _release;
    return Scaffold(
      appBar: AppBar(title: const Text('À propos & mises à jour')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/icon.png', width: 64, height: 64),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('NiTroiD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('Version ${_version.isEmpty ? '…' : _version}', style: const TextStyle(color: NxColors.muted)),
                  const Text('Édition mobile de NiTriTe', style: TextStyle(color: NxColors.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Mise à jour'),
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_checking) const LinearProgressIndicator(),
              if (r != null && !_updateAvailable)
                const Row(children: [
                  StatusDot('ok'),
                  SizedBox(width: 10),
                  Expanded(child: Text('NiTroiD est à jour.', style: TextStyle(fontWeight: FontWeight.w700))),
                ]),
              if (_updateAvailable) ...[
                Row(children: [
                  const StatusDot('warn'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Version ${r!.version} disponible',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
                if (r.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.notes.split('\n## ').first.replaceAll('## ', '').trim(),
                      maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: NxColors.muted)),
                ],
                const SizedBox(height: 12),
                if (_progress != null || _status != null) ...[
                  LinearProgressIndicator(value: _progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 6),
                ],
                if (_status != null) Text(_status!, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                if (Native.isAndroid)
                  FilledButton.icon(
                    onPressed: _progress != null ? null : _update,
                    icon: const Icon(Icons.system_update),
                    label: const Text('Mettre à jour'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => Native.openUrl(r.pageUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir la page de téléchargement'),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: NxColors.bad, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _checking ? null : _check,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Vérifier maintenant'),
              ),
            ]),
          ),
          const SectionHeader('Liens'),
          NxCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Site NiTriTe'),
                subtitle: const Text('nitrite.heiphaistos.org'),
                onTap: () => Native.openUrl('https://nitrite.heiphaistos.org/nitroid/'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Code source & signaler un bug'),
                subtitle: const Text('github.com/Heiphaistos/NiTroiD'),
                onTap: () => Native.openUrl('https://github.com/Heiphaistos/NiTroiD/issues'),
              ),
            ]),
          ),
          const SectionHeader('Crédits'),
          const NxCard(
            child: Text(
              'Indicateurs de logiciels espions : association Échap (stalkerware-indicators, licence CC-BY 4.0).\n'
              'Aucune donnée ne quitte le téléphone : NiTroiD ne contacte GitHub que pour les mises à jour '
              'et la base anti-espion, et les sites des outils réseau que tu lances.',
              style: TextStyle(fontSize: 12, color: NxColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
