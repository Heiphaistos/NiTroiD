import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'native.dart';

/// Base d'indicateurs de logiciels espions (stalkerware) maintenue par
/// l'association Échap — https://github.com/AssoEchap/stalkerware-indicators
/// (licence CC-BY 4.0). Une copie est embarquée, et peut être rafraîchie.
class ThreatDb {
  ThreatDb(this.byPackage, this.byCert, this.fetched);

  final Map<String, String> byPackage;
  final Map<String, String> byCert;
  final String fetched;

  static const updateUrl = 'https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/ioc.yaml';

  int get size => byPackage.length + byCert.length;

  factory ThreatDb.fromJson(Map<String, dynamic> json) {
    final pkgs = <String, String>{};
    final certs = <String, String>{};
    for (final app in (json['apps'] as List? ?? const [])) {
      final name = app['n'].toString();
      for (final p in (app['p'] as List? ?? const [])) {
        pkgs[p.toString()] = name;
      }
      for (final c in (app['c'] as List? ?? const [])) {
        certs[c.toString().toUpperCase()] = name;
      }
    }
    return ThreatDb(pkgs, certs, json['fetched']?.toString() ?? '');
  }

  /// Nom de la menace si le paquet ou un de ses certificats est connu.
  String? match(AppEntry app) {
    final byPkg = byPackage[app.package];
    if (byPkg != null) return byPkg;
    for (final c in app.certSha1) {
      final hit = byCert[c];
      if (hit != null) return hit;
    }
    return null;
  }

  static Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/threat_db.json');
  }

  static Future<ThreatDb> load() async {
    try {
      final cached = await _cacheFile();
      if (await cached.exists()) {
        return ThreatDb.fromJson(jsonDecode(await cached.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {
      // Cache illisible : on retombe sur la copie embarquée.
    }
    final bundled = await rootBundle.loadString('assets/threat_db.json');
    return ThreatDb.fromJson(jsonDecode(bundled) as Map<String, dynamic>);
  }

  /// Télécharge la dernière version de la base et la met en cache.
  static Future<ThreatDb> update() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(updateUrl));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final yaml = await res.transform(utf8.decoder).join();
      final json = parseIocYaml(yaml);
      json['fetched'] = DateTime.now().toIso8601String().substring(0, 10);
      await (await _cacheFile()).writeAsString(jsonEncode(json));
      return ThreatDb.fromJson(json);
    } finally {
      client.close();
    }
  }
}

/// Lecteur minimal du format ioc.yaml d'Échap : une liste d'entrées
/// `- name:` contenant des listes `packages:` et `certificates:`.
Map<String, dynamic> parseIocYaml(String yaml) {
  final apps = <Map<String, dynamic>>[];
  Map<String, dynamic>? current;
  String? list;
  for (final rawLine in const LineSplitter().convert(yaml)) {
    final line = rawLine.replaceAll('\t', '  ');
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final entry = RegExp(r'^- name\s*:(.*)$').firstMatch(line);
    if (entry != null) {
      current = {'n': entry.group(1)!.trim(), 't': 'stalkerware', 'p': <String>[], 'c': <String>[]};
      apps.add(current);
      list = null;
      continue;
    }
    if (current == null) continue;
    final indent = line.length - line.trimLeft().length;
    final trimmed = line.trim();
    if (indent <= 2 && !trimmed.startsWith('- ')) {
      final colon = trimmed.indexOf(':');
      final key = (colon < 0 ? trimmed : trimmed.substring(0, colon)).trim();
      list = key == 'packages' ? 'p' : key == 'certificates' ? 'c' : null;
      if (key == 'type' && colon >= 0) current['t'] = trimmed.substring(colon + 1).trim();
      continue;
    }
    if (list != null && trimmed.startsWith('- ')) {
      var value = trimmed.substring(2).trim();
      if (value.startsWith("'") || value.startsWith('"')) value = value.substring(1, value.length - 1);
      if (list == 'c') value = value.toUpperCase();
      (current[list] as List<String>).add(value);
    }
  }
  apps.removeWhere((a) => (a['p'] as List).isEmpty && (a['c'] as List).isEmpty);
  return {'source': 'https://github.com/AssoEchap/stalkerware-indicators', 'license': 'CC-BY 4.0', 'apps': apps};
}

/// Résultat d'analyse d'une application.
class AppRisk {
  AppRisk(this.app, this.score, this.reasons, {this.threat});

  final AppEntry app;
  final int score;
  final List<String> reasons;
  final String? threat;

  /// `bad` (menace connue ou score élevé), `warn` ou `ok`.
  String get level => threat != null || score >= 60 ? 'bad' : score >= 30 ? 'warn' : 'ok';
}

const _trustedInstallers = {
  'com.android.vending',
  'com.google.android.packageinstaller',
  'com.sec.android.app.samsungapps',
  'com.huawei.appmarket',
  'com.xiaomi.market',
  'com.xiaomi.mipicks',
  'com.oppo.market',
  'com.heytap.market',
  'com.bbk.appstore',
  'com.amazon.venezia',
  'org.fdroid.fdroid',
  'com.aurora.store',
  'com.android.shell',
};

const _dangerousPerms = <String, (int, String)>{
  'android.permission.READ_SMS': (12, 'lit les SMS'),
  'android.permission.RECEIVE_SMS': (8, 'intercepte les SMS reçus'),
  'android.permission.SEND_SMS': (10, 'envoie des SMS'),
  'android.permission.READ_CALL_LOG': (10, 'lit le journal d’appels'),
  'android.permission.PROCESS_OUTGOING_CALLS': (8, 'surveille les appels sortants'),
  'android.permission.RECORD_AUDIO': (8, 'enregistre le micro'),
  'android.permission.CAMERA': (5, 'utilise la caméra'),
  'android.permission.ACCESS_FINE_LOCATION': (5, 'localisation précise'),
  'android.permission.ACCESS_BACKGROUND_LOCATION': (10, 'localisation en arrière-plan'),
  'android.permission.READ_CONTACTS': (5, 'lit les contacts'),
  'android.permission.READ_PHONE_STATE': (3, 'identifiants téléphoniques'),
};

const _specialWeights = <String, (int, String)>{
  'accessibility': (30, 'service d’accessibilité actif (peut lire et contrôler l’écran)'),
  'deviceAdmin': (25, 'administrateur de l’appareil'),
  'notificationListener': (18, 'lit toutes les notifications'),
  'overlay': (8, 'peut s’afficher par-dessus les autres apps'),
  'installPackages': (10, 'peut installer d’autres applications'),
  'usageAccess': (8, 'accès aux statistiques d’utilisation'),
  'vpn': (10, 'service VPN (peut voir le trafic)'),
  'defaultSms': (10, 'application SMS par défaut'),
};

/// Heuristiques inspirées des outils d'analyse anti-stalkerware : combinaison
/// d'accès sensibles, installation hors magasin, icône masquée…
AppRisk assessApp(AppEntry app, ThreatDb? db) {
  final threat = db?.match(app);
  final reasons = <String>[];
  var score = 0;

  if (threat != null) {
    score = 100;
    reasons.add('Correspond à la base Échap : $threat');
  }

  if (!app.system) {
    final installer = app.installer;
    if (installer == null || installer.isEmpty) {
      score += 15;
      reasons.add('Installée hors magasin d’applications (APK)');
    } else if (!_trustedInstallers.contains(installer)) {
      score += 8;
      reasons.add('Installée par $installer');
    }
    if (!app.hasLauncher) {
      score += 15;
      reasons.add('Aucune icône dans le lanceur (application masquée)');
    }
  }

  for (final special in app.specialAccess) {
    final w = _specialWeights[special];
    if (w != null) {
      // Les composants système ont légitimement ces accès.
      score += app.system ? w.$1 ~/ 4 : w.$1;
      reasons.add(w.$2);
    }
  }

  var sensitive = 0;
  for (final p in app.grantedPermissions) {
    final w = _dangerousPerms[p];
    if (w != null) {
      sensitive++;
      if (!app.system) score += w.$1;
      reasons.add(w.$2);
    }
  }
  if (!app.system && sensitive >= 5) {
    score += 10;
    reasons.add('Cumule $sensitive permissions sensibles');
  }

  if (!app.system && app.targetSdk > 0 && app.targetSdk < 23) {
    score += 12;
    reasons.add('Cible Android ${app.targetSdk} : contourne les permissions à l’exécution');
  }
  if (app.debuggable && !app.system) {
    score += 5;
    reasons.add('Compilée en mode débogage');
  }

  return AppRisk(app, score.clamp(0, 100), reasons, threat: threat);
}
