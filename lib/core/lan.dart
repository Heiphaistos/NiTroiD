import 'dart:async';
import 'dart:io';

/// Appareil trouvé sur le réseau local.
class LanHost {
  LanHost(this.ip, this.openPorts, this.latencyMs, {this.name});

  final String ip;
  final List<int> openPorts;
  final int latencyMs;
  String? name;

  /// Devine le type d'appareil à partir des ports qui répondent.
  String get kind {
    if (openPorts.contains(62078)) return 'iPhone / iPad';
    if (openPorts.contains(554)) return 'Caméra / NVR';
    if (openPorts.contains(9100) || openPorts.contains(631)) return 'Imprimante';
    if (openPorts.contains(8009)) return 'Chromecast / TV';
    if (openPorts.contains(445) || openPorts.contains(139)) return 'Ordinateur / NAS (partage)';
    if (openPorts.contains(22)) return 'Serveur / Linux (SSH)';
    if (openPorts.contains(53)) return 'Box / routeur (DNS)';
    if (openPorts.contains(80) || openPorts.contains(443)) return 'Interface web';
    return 'Appareil';
  }
}

const lanPorts = [80, 443, 22, 53, 139, 445, 554, 631, 8009, 8080, 9100, 62078];

/// Les 254 adresses du /24 qui contient [ip] (hors adresse elle-même).
List<String> subnetHosts(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) return const [];
  final base = parts.take(3).join('.');
  return [for (var i = 1; i < 255; i++) '$base.$i'].where((h) => h != ip).toList();
}

bool _isPrivate(InternetAddress a) {
  final b = a.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
}

/// Adresse IPv4 privée de l'appareil (Wi-Fi de préférence).
Future<String?> localIpv4() async {
  final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  ifaces.sort((a, b) {
    int score(NetworkInterface i) => i.name.startsWith('wlan') || i.name.startsWith('en') ? 0 : 1;
    return score(a) - score(b);
  });
  for (final i in ifaces) {
    for (final a in i.addresses) {
      if (_isPrivate(a)) return a.address;
    }
  }
  return null;
}

/// Un hôte est vivant si un port accepte la connexion ou la refuse
/// activement (RST) ; seul un délai dépassé signifie « personne ».
Future<LanHost?> probeHost(String ip, {Duration timeout = const Duration(milliseconds: 600)}) async {
  final open = <int>[];
  var alive = false;
  var best = 1 << 30;
  await Future.wait(lanPorts.map((port) async {
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(ip, port, timeout: timeout);
      s.destroy();
      open.add(port);
      alive = true;
      if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds;
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      // ECONNREFUSED : 111 sous Linux/Android, 61 sous iOS.
      if (code == 111 || code == 61) {
        alive = true;
        if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds;
      }
    } catch (_) {}
  }));
  if (!alive) return null;
  open.sort();
  return LanHost(ip, open, best);
}

/// Balaye le /24 avec une concurrence limitée et rapporte chaque hôte trouvé.
Future<List<LanHost>> scanLan(
  String ip, {
  void Function(int done, int total)? onProgress,
  void Function(LanHost host)? onHost,
  int concurrency = 24,
}) async {
  final targets = subnetHosts(ip);
  final found = <LanHost>[];
  var next = 0;
  var done = 0;
  Future<void> worker() async {
    while (next < targets.length) {
      final target = targets[next++];
      final host = await probeHost(target);
      done++;
      onProgress?.call(done, targets.length);
      if (host != null) {
        try {
          final rev = await InternetAddress(target).reverse().timeout(const Duration(seconds: 1));
          if (rev.host != target) host.name = rev.host;
        } catch (_) {}
        found.add(host);
        onHost?.call(host);
      }
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  found.sort((a, b) => int.parse(a.ip.split('.').last).compareTo(int.parse(b.ip.split('.').last)));
  return found;
}

/// Verdict sur un chargeur à partir du courant moyen mesuré (mA).
(String, String) rateCharger(double avgMa) {
  if (avgMa <= 50) return ('bad', 'Le téléphone ne charge pas (câble, chargeur ou port à vérifier).');
  if (avgMa < 500) return ('bad', 'Charge très lente : câble abîmé ou chargeur USB d’ordinateur.');
  if (avgMa < 1200) return ('warn', 'Charge standard (5 W environ). Un chargeur rapide irait plus vite.');
  if (avgMa < 2500) return ('ok', 'Charge rapide.');
  return ('ok', 'Charge très rapide.');
}
