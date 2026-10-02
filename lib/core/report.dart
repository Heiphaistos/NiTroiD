import 'dart:convert';

import 'native.dart';

/// Données rassemblées pour un rapport de diagnostic.
class DiagnosticReport {
  DiagnosticReport({
    required this.generated,
    required this.platform,
    required this.sections,
    required this.checks,
    this.flaggedApps = const [],
  });

  final DateTime generated;
  final String platform;

  /// Catégorie → sections.
  final Map<String, List<InfoSection>> sections;
  final List<SecurityCheck> checks;

  /// (libellé, paquet, score, raisons)
  final List<(String, String, int, List<String>)> flaggedApps;

  static const categoryTitles = {
    'system': 'Système',
    'cpu': 'Processeur',
    'battery': 'Batterie',
    'memory': 'Mémoire',
    'storage': 'Stockage',
    'display': 'Écran',
    'network': 'Réseau',
    'cameras': 'Caméras',
    'features': 'Fonctions matérielles',
    'media': 'Médias & DRM',
  };

  static const _statusLabel = {'ok': 'OK', 'warn': 'ATTENTION', 'bad': 'CRITIQUE', 'info': 'INFO'};

  String toText() {
    final b = StringBuffer()
      ..writeln('NiTroiD — rapport de diagnostic')
      ..writeln('Généré le ${generated.toIso8601String()} ($platform)')
      ..writeln('=' * 48);
    sections.forEach((cat, list) {
      b
        ..writeln()
        ..writeln('## ${categoryTitles[cat] ?? cat}');
      for (final s in list) {
        b.writeln('[${s.title}]');
        for (final e in s.items) {
          b.writeln('  ${e.key} : ${e.value}');
        }
      }
    });
    b
      ..writeln()
      ..writeln('## Sécurité');
    for (final c in checks) {
      b.writeln('  [${_statusLabel[c.status] ?? c.status}] ${c.title} — ${c.detail}');
    }
    if (flaggedApps.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Applications à vérifier');
      for (final (label, pkg, score, reasons) in flaggedApps) {
        b.writeln('  $label ($pkg) — score $score : ${reasons.join(', ')}');
      }
    }
    return b.toString();
  }

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# NiTroiD — rapport de diagnostic')
      ..writeln()
      ..writeln('_Généré le ${generated.toIso8601String()} · ${platform}_');
    sections.forEach((cat, list) {
      b
        ..writeln()
        ..writeln('## ${categoryTitles[cat] ?? cat}');
      for (final s in list) {
        b
          ..writeln()
          ..writeln('### ${s.title}')
          ..writeln()
          ..writeln('| Élément | Valeur |')
          ..writeln('|---|---|');
        for (final e in s.items) {
          b.writeln('| ${_md(e.key)} | ${_md(e.value)} |');
        }
      }
    });
    b
      ..writeln()
      ..writeln('## Sécurité')
      ..writeln()
      ..writeln('| État | Contrôle | Détail |')
      ..writeln('|---|---|---|');
    for (final c in checks) {
      b.writeln('| ${_statusLabel[c.status] ?? c.status} | ${_md(c.title)} | ${_md(c.detail)} |');
    }
    if (flaggedApps.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Applications à vérifier')
        ..writeln();
      for (final (label, pkg, score, reasons) in flaggedApps) {
        b.writeln('- **${_md(label)}** (`$pkg`) — score $score : ${_md(reasons.join(', '))}');
      }
    }
    return b.toString();
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert({
        'generator': 'NiTroiD',
        'generated': generated.toIso8601String(),
        'platform': platform,
        'sections': sections.map((k, v) => MapEntry(k, v.map((s) => s.toJson()).toList())),
        'security': checks.map((c) => c.toJson()).toList(),
        'flaggedApps': [
          for (final (label, pkg, score, reasons) in flaggedApps)
            {'label': label, 'package': pkg, 'score': score, 'reasons': reasons},
        ],
      });

  static String _md(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');
}
