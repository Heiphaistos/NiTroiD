import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// Charge de calcul déterministe : crible + arithmétique flottante.
/// Renvoie un checksum pour empêcher toute élimination du calcul.
int cpuWorkload(int rounds) {
  var checksum = 0;
  for (var r = 0; r < rounds; r++) {
    const n = 20000;
    final sieve = Uint8List(n + 1);
    var primes = 0;
    for (var i = 2; i <= n; i++) {
      if (sieve[i] == 0) {
        primes++;
        for (var j = i * i; j <= n; j += i) {
          sieve[j] = 1;
        }
      }
    }
    var x = 0.0;
    for (var i = 1; i < 20000; i++) {
      x += sqrt(i) * sin(i.toDouble());
    }
    checksum = (checksum + primes + x.toInt()) & 0x7fffffff;
  }
  return checksum;
}

class BenchResult {
  BenchResult(this.label, this.value, this.unit, {this.score});

  final String label;
  final double value;
  final String unit;
  final int? score;

  Map<String, dynamic> toJson() => {'label': label, 'value': value, 'unit': unit, 'score': score};
}

/// Itérations par seconde sur un cœur.
Future<double> _singleCore(Duration budget) => Isolate.run(() {
      final sw = Stopwatch()..start();
      var rounds = 0;
      while (sw.elapsed < budget) {
        cpuWorkload(1);
        rounds++;
      }
      return rounds / (sw.elapsedMicroseconds / 1e6);
    });

Future<BenchResult> benchSingleCore({Duration budget = const Duration(seconds: 3)}) async {
  final ips = await _singleCore(budget);
  return BenchResult('CPU mono-cœur', ips, 'it/s', score: (ips * 10).round());
}

Future<BenchResult> benchMultiCore({Duration budget = const Duration(seconds: 3)}) async {
  final cores = Platform.numberOfProcessors;
  final results = await Future.wait([for (var i = 0; i < cores; i++) _singleCore(budget)]);
  final total = results.fold<double>(0, (a, b) => a + b);
  return BenchResult('CPU multi-cœur ($cores threads)', total, 'it/s', score: (total * 10).round());
}

/// Débit de copie mémoire (Mo/s) sur des blocs de 32 Mo.
Future<BenchResult> benchMemory() => Isolate.run(() {
      const size = 32 * 1024 * 1024;
      final src = Uint8List(size);
      for (var i = 0; i < size; i += 4096) {
        src[i] = i & 0xff;
      }
      final dst = Uint8List(size);
      final sw = Stopwatch()..start();
      var copies = 0;
      while (sw.elapsedMilliseconds < 2000) {
        dst.setRange(0, size, src);
        copies++;
      }
      final mbps = copies * size / (1024 * 1024) / (sw.elapsedMicroseconds / 1e6);
      return BenchResult('Mémoire (copie)', mbps, 'Mo/s', score: (mbps / 10).round());
    });

/// Écriture séquentielle puis lecture d'un fichier de [mb] Mo.
Future<List<BenchResult>> benchStorage(Directory dir, {int mb = 128}) async {
  final file = File('${dir.path}/nitroid_bench.tmp');
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < block.length; i++) {
    block[i] = (i * 31) & 0xff;
  }
  try {
    final sw = Stopwatch()..start();
    final raf = await file.open(mode: FileMode.write);
    for (var i = 0; i < mb; i++) {
      await raf.writeFrom(block);
    }
    await raf.flush();
    await raf.close();
    final writeMbps = mb / (sw.elapsedMicroseconds / 1e6);

    sw
      ..reset()
      ..start();
    final reader = await file.open();
    final buffer = Uint8List(1024 * 1024);
    var read = 0;
    while (true) {
      final n = await reader.readInto(buffer);
      if (n == 0) break;
      read += n;
    }
    await reader.close();
    final readMbps = read / (1024 * 1024) / (sw.elapsedMicroseconds / 1e6);
    return [
      BenchResult('Stockage écriture', writeMbps, 'Mo/s', score: writeMbps.round()),
      BenchResult('Stockage lecture', readMbps, 'Mo/s', score: (readMbps / 2).round()),
    ];
  } finally {
    if (await file.exists()) await file.delete();
  }
}
