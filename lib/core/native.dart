import 'dart:io';

import 'package:flutter/services.dart';

/// Une section clé/valeur renvoyée par le pont natif (`getInfo`).
class InfoSection {
  InfoSection(this.title, this.items);

  final String title;
  final List<MapEntry<String, String>> items;

  factory InfoSection.fromMap(Map<dynamic, dynamic> map) {
    final raw = (map['items'] as List?) ?? const [];
    return InfoSection(
      map['title']?.toString() ?? '',
      [
        for (final item in raw)
          if (item is List && item.length >= 2) MapEntry(item[0].toString(), item[1]?.toString() ?? '—'),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': {for (final e in items) e.key: e.value},
      };
}

/// Un contrôle de sécurité de l'appareil (chiffrement, verrouillage, root…).
class SecurityCheck {
  SecurityCheck({
    required this.id,
    required this.title,
    required this.status,
    required this.detail,
    this.action,
  });

  final String id;
  final String title;

  /// `ok`, `warn`, `bad` ou `info`.
  final String status;
  final String detail;

  /// Identifiant d'écran de paramètres à ouvrir pour corriger, si pertinent.
  final String? action;

  factory SecurityCheck.fromMap(Map<dynamic, dynamic> m) => SecurityCheck(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        status: m['status']?.toString() ?? 'info',
        detail: m['detail']?.toString() ?? '',
        action: m['action']?.toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'status': status, 'detail': detail};
}

/// Une application installée (Android uniquement : iOS n'expose pas la liste).
class AppEntry {
  AppEntry(this.raw);

  final Map<dynamic, dynamic> raw;

  String get package => raw['pkg']?.toString() ?? '';
  String get label => raw['label']?.toString() ?? package;
  String get version => raw['version']?.toString() ?? '';
  bool get system => raw['system'] == true;
  bool get enabled => raw['enabled'] != false;
  bool get hasLauncher => raw['launcher'] == true;
  bool get debuggable => raw['debuggable'] == true;
  String? get installer => raw['installer']?.toString();
  int get targetSdk => (raw['targetSdk'] as num?)?.toInt() ?? 0;
  int get firstInstall => (raw['firstInstall'] as num?)?.toInt() ?? 0;
  int get lastUpdate => (raw['lastUpdate'] as num?)?.toInt() ?? 0;
  List<String> get grantedPermissions => _strings(raw['granted']);
  List<String> get requestedPermissions => _strings(raw['requested']);

  /// Capacités spéciales effectivement actives : accessibility, deviceAdmin,
  /// notificationListener, overlay, installPackages, defaultSms…
  List<String> get specialAccess => _strings(raw['special']);
  List<String> get certSha1 => _strings(raw['certSha1']).map((c) => c.toUpperCase()).toList();
  String get certSha256 => raw['certSha256']?.toString() ?? '';

  static List<String> _strings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
}

/// Point d'entrée unique vers le code natif (Kotlin sur Android, Swift sur iOS).
class Native {
  Native._();

  static const _channel = MethodChannel('nitroid/native');
  static const _sensors = EventChannel('nitroid/sensors');

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;

  static Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<List<InfoSection>> info(String category) async {
    final res = await _call<List<dynamic>>('getInfo', {'category': category});
    return [for (final s in res ?? const []) InfoSection.fromMap(s as Map)];
  }

  static Future<Map<String, dynamic>> dashboard() async {
    final res = await _call<Map<dynamic, dynamic>>('getDashboard');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<Map<String, dynamic>> live() async {
    final res = await _call<Map<dynamic, dynamic>>('getLive');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<List<SecurityCheck>> securityChecks() async {
    final res = await _call<List<dynamic>>('securityChecks');
    return [for (final m in res ?? const []) SecurityCheck.fromMap(m as Map)];
  }

  static Future<List<AppEntry>> apps({bool includeSystem = false}) async {
    final res = await _call<List<dynamic>>('listApps', {'system': includeSystem});
    return [for (final m in res ?? const []) AppEntry(m as Map)];
  }

  static Future<Uint8List?> appIcon(String pkg) => _call<Uint8List>('appIcon', {'pkg': pkg});

  static Future<List<Map<String, dynamic>>> sensors() async {
    final res = await _call<List<dynamic>>('listSensors');
    return [for (final m in res ?? const []) Map<String, dynamic>.from(m as Map)];
  }

  static Stream<List<double>> sensorStream(int type) => _sensors
      .receiveBroadcastStream({'type': type})
      .map((e) => (e as List).map((v) => (v as num).toDouble()).toList());

  static Future<bool> openSettings(String action, {String? package}) async =>
      await _call<bool>('openSettings', {'action': action, 'pkg': package}) ?? false;

  static Future<bool> openComponent(String package, String cls) async =>
      await _call<bool>('openComponent', {'pkg': package, 'cls': cls}) ?? false;

  static Future<bool> uninstall(String pkg) async => await _call<bool>('uninstall', {'pkg': pkg}) ?? false;
  static Future<bool> launchApp(String pkg) async => await _call<bool>('launchApp', {'pkg': pkg}) ?? false;

  static Future<Map<String, dynamic>> launchers() async {
    final res = await _call<Map<dynamic, dynamic>>('launchers');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<bool> torch(bool on) async => await _call<bool>('torch', {'on': on}) ?? false;
  static Future<bool> vibrate(int ms, {int amplitude = 255}) async =>
      await _call<bool>('vibrate', {'ms': ms, 'amplitude': amplitude}) ?? false;
  static Future<bool> tone(int ms) async => await _call<bool>('tone', {'ms': ms}) ?? false;

  static Future<String> exec(String tool, Map<String, dynamic> args) async =>
      await _call<String>('exec', {'tool': tool, ...args}) ?? '';

  static Future<Map<String, dynamic>> permissions() async {
    final res = await _call<Map<dynamic, dynamic>>('permissions');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<bool> requestPermission(String name) async =>
      await _call<bool>('requestPermission', {'name': name}) ?? false;

  static Future<List<Map<String, dynamic>>> usageStats(int days) async {
    final res = await _call<List<dynamic>>('usageStats', {'days': days});
    return [for (final m in res ?? const []) Map<String, dynamic>.from(m as Map)];
  }

  static Future<List<Map<String, dynamic>>> wifiScan() async {
    final res = await _call<List<dynamic>>('wifiScan');
    return [for (final m in res ?? const []) Map<String, dynamic>.from(m as Map)];
  }

  static Future<Map<String, dynamic>> tweaks() async {
    final res = await _call<Map<dynamic, dynamic>>('getTweaks');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<String?> setTweak(String key, Object value) =>
      _call<String>('setTweak', {'key': key, 'value': value.toString()});

  static Future<List<Map<String, dynamic>>> listDir(String path) async {
    final res = await _call<List<dynamic>>('listDir', {'path': path});
    return [for (final m in res ?? const []) Map<String, dynamic>.from(m as Map)];
  }

  static Future<String?> readFile(String path) => _call<String>('readFile', {'path': path});

  /// Version installée et architectures prises en charge.
  static Future<Map<String, dynamic>> appInfo() async {
    final res = await _call<Map<dynamic, dynamic>>('appInfo');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<String> installApk(String path) async =>
      await _call<String>('installApk', {'path': path}) ?? 'error';

  static Future<bool> openUrl(String url) async => await _call<bool>('openUrl', {'url': url}) ?? false;

  // --- Outils développeur / root (Android) ---

  static const _logcat = EventChannel('nitroid/logcat');

  static Future<bool> rootAvailable({bool force = false}) async =>
      await _call<bool>('rootAvailable', {'force': force}) ?? false;

  /// Accorde à NiTroiD les permissions avancées via root. {root, results:[{perm,ok,detail}]}
  static Future<Map<String, dynamic>> grantSelf() async {
    final res = await _call<Map<dynamic, dynamic>>('grantSelf');
    return Map<String, dynamic>.from(res ?? const {});
  }

  /// Lit un lot de réglages « ns:key » → valeur (ou null).
  static Future<Map<String, String?>> getSettings(List<String> keys) async {
    final res = await _call<Map<dynamic, dynamic>>('getSettings', {'keys': keys});
    return {for (final e in (res ?? const {}).entries) e.key.toString(): e.value?.toString()};
  }

  /// Écrit un réglage. Renvoie null si OK, sinon un message d'erreur.
  static Future<String?> putSetting(String ns, String key, String value) =>
      _call<String>('putSetting', {'ns': ns, 'key': key, 'value': value});

  /// Action avancée sur une app (root requis) : forceStop, clearData, clearCache, disable, enable.
  static Future<String> appAction(String action, String pkg) async =>
      await _call<String>('appAction', {'action': action, 'pkg': pkg}) ?? 'error';

  /// Températures détaillées : {source: hal|shell|none, sensors:[{name,kind,type,temp,status,severe,critical}],
  /// zones:[{name,temp}], dump, headroom10s}.
  static Future<Map<String, dynamic>> thermalDetail() async {
    final res = await _call<Map<dynamic, dynamic>>('thermalDetail');
    return Map<String, dynamic>.from(res ?? const {});
  }

  /// Mesure pour le test d'autonomie : {time, level, chargeMah, currentMa, voltageMv, temp, plugged, designMah}.
  static Future<Map<String, dynamic>> batterySample() async {
    final res = await _call<Map<dynamic, dynamic>>('batterySample');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<void> keepScreenOn(bool on) => _call<bool>('keepScreenOn', {'on': on});

  // --- ADB sans fil (Android 11+) ---

  /// {supported, paired, connected, wirelessOn, searching, pairingPort, mode: root|adb|none}
  static Future<Map<String, dynamic>> adbStatus() async {
    final res = await _call<Map<dynamic, dynamic>>('adbStatus');
    return Map<String, dynamic>.from(res ?? const {});
  }

  static Future<bool> adbSearch() async => await _call<bool>('adbSearch') ?? false;
  static Future<void> adbStopSearch() => _call<void>('adbStopSearch');

  /// null si OK, sinon le message d'erreur.
  static Future<String?> adbPair(String code, {int port = -1}) =>
      _call<String>('adbPair', {'code': code, 'port': port});

  static Future<String?> adbConnect() => _call<String>('adbConnect');
  static Future<void> adbDisconnect() => _call<void>('adbDisconnect');

  /// Commande avec les droits root ou ADB : {ok, out, mode}.
  static Future<Map<String, dynamic>> privShell(String command) async {
    final res = await _call<Map<dynamic, dynamic>>('privShell', {'command': command});
    return Map<String, dynamic>.from(res ?? const {'ok': false, 'out': 'Indisponible', 'mode': 'none'});
  }

  static Stream<String> logcatStream({String? filter}) =>
      _logcat.receiveBroadcastStream({'filter': filter}).map((e) => e.toString());

  // --- Tests matériel ---

  static const _mic = EventChannel('nitroid/mic');
  static const _keys = EventChannel('nitroid/keys');

  /// Joue un son. [channel] : 'left', 'right' ou 'both'. [sweep] = balayage de fréquence.
  static Future<bool> playTone({double freq = 1000, int ms = 1500, String channel = 'both', bool sweep = false}) async =>
      await _call<bool>('playTone', {'freq': freq, 'ms': ms, 'channel': channel, 'sweep': sweep}) ?? false;

  static Future<void> stopTone() => _call('stopTone');

  /// Niveau du micro en direct : [rms, peak] entre 0 et 1.
  static Stream<List<double>> micStream() =>
      _mic.receiveBroadcastStream().map((e) => (e as List).map((v) => (v as num).toDouble()).toList());

  /// Appuis sur les boutons physiques : {key, down}.
  static Stream<Map<String, dynamic>> keyStream() =>
      _keys.receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e as Map));
}
