import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'native.dart';

/// Compare deux versions « x.y.z » (préfixe v et suffixe +build ignorés).
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^v'), '')
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = parse(a);
  final y = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

class ReleaseAsset {
  ReleaseAsset(this.name, this.url, this.size);

  final String name;
  final String url;
  final int size;
}

class ReleaseInfo {
  ReleaseInfo(this.version, this.notes, this.pageUrl, this.assets);

  final String version;
  final String notes;
  final String pageUrl;
  final List<ReleaseAsset> assets;

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) => ReleaseInfo(
        (j['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), ''),
        (j['body'] ?? '').toString(),
        (j['html_url'] ?? '').toString(),
        [
          for (final a in (j['assets'] as List? ?? const []))
            ReleaseAsset(a['name'].toString(), a['browser_download_url'].toString(), (a['size'] as num?)?.toInt() ?? 0),
        ],
      );

  /// APK adapté à l'architecture du téléphone : arm64 (19 Mo) plutôt que
  /// l'universel quand c'est possible.
  ReleaseAsset? apkFor(List<String> abis) {
    ReleaseAsset? find(String suffix) {
      for (final a in assets) {
        if (a.name.endsWith(suffix)) return a;
      }
      return null;
    }

    final primary = abis.isEmpty ? '' : abis.first;
    if (primary == 'arm64-v8a') return find('-android-arm64.apk') ?? find('-android.apk');
    if (primary.startsWith('armeabi')) return find('-android-armv7.apk') ?? find('-android.apk');
    return find('-android.apk');
  }
}

class Updater {
  static const repo = 'Heiphaistos/NiTroiD';
  static const releasesPage = 'https://github.com/$repo/releases/latest';

  static Future<ReleaseInfo> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'NiTroiD');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw HttpException('GitHub a répondu ${res.statusCode}');
      final body = await res.transform(utf8.decoder).join();
      return ReleaseInfo.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  /// Télécharge l'APK dans le cache (dossier partagé avec l'installateur
  /// via FileProvider) en signalant la progression. Un délai d'inactivité
  /// coupe proprement un téléchargement qui ne progresse plus.
  static Future<File> download(ReleaseAsset asset, void Function(int received, int total) onProgress) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/${asset.name}');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final sink = file.openWrite();
    try {
      final req = await client.getUrl(Uri.parse(asset.url));
      req.headers.set(HttpHeaders.userAgentHeader, 'NiTroiD');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('Téléchargement refusé (${res.statusCode})');
      final total = res.contentLength > 0 ? res.contentLength : asset.size;
      var received = 0;
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      if (total > 0 && received != total) {
        throw HttpException('Fichier incomplet ($received / $total octets)');
      }
      return file;
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// `ok`, `permission` (l'utilisateur doit autoriser NiTroiD à installer) ou `error`.
  static Future<String> install(File apk) => Native.installApk(apk.path);
}
