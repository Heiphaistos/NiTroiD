import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nitroid/core/benchmark.dart';
import 'package:nitroid/core/format.dart';
import 'package:nitroid/core/native.dart';
import 'package:nitroid/core/report.dart';
import 'package:nitroid/core/threats.dart';
import 'package:nitroid/screens/dashboard.dart';

AppEntry app(Map<String, dynamic> m) => AppEntry({
      'pkg': 'com.example.app',
      'label': 'Example',
      'system': false,
      'launcher': true,
      'installer': 'com.android.vending',
      'targetSdk': 34,
      ...m,
    });

void main() {
  group('format', () {
    test('formatBytes', () {
      expect(formatBytes(512), '512 o');
      expect(formatBytes(1536), '1.5 Ko');
      expect(formatBytes(8 * 1024 * 1024 * 1024), '8.0 Go');
      expect(formatBytes(null), '—');
    });

    test('formatFreqKhz', () {
      expect(formatFreqKhz(2841600), '2.84 GHz');
      expect(formatFreqKhz(576000), '576 MHz');
      expect(formatFreqKhz(0), '—');
    });

    test('normalizeThermal gère milli/déci-degrés et valeurs aberrantes', () {
      expect(normalizeThermal(42000), 42.0);
      expect(normalizeThermal(385), 38.5);
      expect(normalizeThermal(37), 37.0);
      expect(normalizeThermal(-273000), isNull);
      expect(normalizeThermal(999999), isNull);
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(days: 2, hours: 3, minutes: 4)), '2j 3h 4min');
      expect(formatDuration(const Duration(seconds: 42)), '42s');
    });
  });

  group('threats', () {
    final db = ThreatDb({'com.spy.bad': 'SpyBad'}, {'AABBCC': 'CertSpy'}, '2026-10-02');

    test('parseIocYaml lit paquets et certificats', () {
      const yaml = '''
- name: TheSpy
  names:
  - Other
  type: stalkerware
  packages:
  - com.thespy.a
  - 'com.thespy.b'
  certificates:
  - aa11bb22
  websites:
  - thespy.com
- name : NoIndicators
  websites:
  - nothing.example
''';
      final json = parseIocYaml(yaml);
      final apps = json['apps'] as List;
      expect(apps, hasLength(1));
      expect(apps.first['n'], 'TheSpy');
      expect(apps.first['p'], ['com.thespy.a', 'com.thespy.b']);
      expect(apps.first['c'], ['AA11BB22']);
    });

    test('la base embarquée se charge et contient des indicateurs', () {
      final json = jsonDecode(File('assets/threat_db.json').readAsStringSync()) as Map<String, dynamic>;
      final loaded = ThreatDb.fromJson(json);
      expect(loaded.byPackage.length, greaterThan(100));
      expect(loaded.byCert.length, greaterThan(100));
    });

    test('correspondance par paquet et par certificat', () {
      expect(assessApp(app({'pkg': 'com.spy.bad'}), db).threat, 'SpyBad');
      expect(assessApp(app({'certSha1': ['aabbcc']}), db).threat, 'CertSpy');
      expect(assessApp(app({'pkg': 'com.spy.bad'}), db).level, 'bad');
    });

    test('une app propre du Play Store reste OK', () {
      final r = assessApp(app({}), db);
      expect(r.score, 0);
      expect(r.level, 'ok');
    });

    test('app masquée, sideloadée, accessibilité + SMS = risque élevé', () {
      final r = assessApp(
        app({
          'installer': null,
          'launcher': false,
          'special': ['accessibility', 'notificationListener'],
          'granted': ['android.permission.READ_SMS', 'android.permission.RECORD_AUDIO'],
        }),
        db,
      );
      expect(r.threat, isNull);
      expect(r.level, 'bad');
      expect(r.reasons, contains('Aucune icône dans le lanceur (application masquée)'));
    });

    test('les accès des apps système pèsent moins', () {
      final user = assessApp(app({'special': ['accessibility']}), db);
      final sys = assessApp(app({'system': true, 'special': ['accessibility']}), db);
      expect(sys.score, lessThan(user.score));
    });
  });

  group('report', () {
    final report = DiagnosticReport(
      generated: DateTime(2026, 10, 2, 12),
      platform: 'Test Phone — Android 16',
      sections: {
        'system': [InfoSection('Appareil', const [MapEntry('Modèle', 'X|1')])],
      },
      checks: [SecurityCheck(id: 'root', title: 'Root', status: 'ok', detail: 'Non rooté')],
      flaggedApps: const [('Spy', 'com.spy', 100, ['connu'])],
    );

    test('texte', () {
      final t = report.toText();
      expect(t, contains('Modèle : X|1'));
      expect(t, contains('[OK] Root'));
      expect(t, contains('Spy (com.spy)'));
    });

    test('markdown échappe les barres verticales', () {
      expect(report.toMarkdown(), contains('| Modèle | X\\|1 |'));
    });

    test('json valide', () {
      final j = jsonDecode(report.toJson()) as Map<String, dynamic>;
      expect(j['generator'], 'NiTroiD');
      expect((j['flaggedApps'] as List).first['package'], 'com.spy');
    });
  });

  group('santé', () {
    test('score pénalisé par les contrôles et le stockage plein', () {
      final perfect = healthScore(checks: const [], dash: const {});
      expect(perfect, 100);
      final degraded = healthScore(
        checks: [
          SecurityCheck(id: 'a', title: 'a', status: 'bad', detail: ''),
          SecurityCheck(id: 'b', title: 'b', status: 'warn', detail: ''),
        ],
        dash: const {'storageTotal': 100, 'storageFree': 5, 'batteryHealthOk': false},
        hottest: 50,
      );
      expect(degraded, 100 - 10 - 4 - 10 - 15 - 10);
    });
  });

  test('cpuWorkload est déterministe', () {
    expect(cpuWorkload(1), cpuWorkload(1));
  });
}
