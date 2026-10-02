import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/native.dart';
import '../core/report.dart';
import '../core/theme.dart';
import '../core/threats.dart';
import '../widgets/common.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DiagnosticReport? _report;
  String _progress = 'Collecte des informations…';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final sections = <String, List<InfoSection>>{};
    for (final cat in DiagnosticReport.categoryTitles.keys) {
      if (cat == 'media' && !Native.isAndroid) continue;
      if (mounted) setState(() => _progress = 'Lecture : ${DiagnosticReport.categoryTitles[cat]}…');
      sections[cat] = await Native.info(cat);
    }
    if (mounted) setState(() => _progress = 'Contrôles de sécurité…');
    final checks = await Native.securityChecks();
    final flagged = <(String, String, int, List<String>)>[];
    if (Native.isAndroid) {
      if (mounted) setState(() => _progress = 'Analyse des applications…');
      final db = await ThreatDb.load();
      for (final a in await Native.apps(includeSystem: true)) {
        if (a.package == 'com.heiphaistos.nitroid') continue;
        final r = assessApp(a, db);
        if (r.level != 'ok') flagged.add((a.label, a.package, r.score, r.reasons));
      }
      flagged.sort((a, b) => b.$3.compareTo(a.$3));
    }
    final dash = await Native.dashboard();
    if (!mounted) return;
    setState(() {
      _report = DiagnosticReport(
        generated: DateTime.now(),
        platform: '${dash['manufacturer'] ?? ''} ${dash['model'] ?? ''} — ${dash['os'] ?? Platform.operatingSystemVersion}'.trim(),
        sections: sections,
        checks: checks,
        flaggedApps: flagged,
      );
    });
  }

  Future<void> _share(String ext, String content) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final file = File('${dir.path}/NiTroiD-rapport-$stamp.$ext');
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Rapport NiTroiD'));
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport de diagnostic')),
      body: r == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_progress, style: TextStyle(color: NxColors.muted)),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NxCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(r.platform, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${r.sections.values.fold<int>(0, (a, l) => a + l.length)} sections · ${r.checks.length} contrôles'
                      '${Native.isAndroid ? ' · ${r.flaggedApps.length} app(s) à vérifier' : ''}',
                      style: TextStyle(color: NxColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(onPressed: () => _share('txt', r.toText()), icon: const Icon(Icons.share), label: const Text('TXT')),
                      FilledButton.tonalIcon(onPressed: () => _share('md', r.toMarkdown()), icon: const Icon(Icons.share), label: const Text('Markdown')),
                      FilledButton.tonalIcon(onPressed: () => _share('json', r.toJson()), icon: const Icon(Icons.share), label: const Text('JSON')),
                    ]),
                  ]),
                ),
                const SectionHeader('Aperçu'),
                NxCard(
                  child: SelectableText(r.toText(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                ),
              ],
            ),
    );
  }
}
