import 'package:flutter_test/flutter_test.dart';
import 'package:nitroid/core/battery_life.dart';

void main() {
  test('autonomie : compteur de charge, capacité et santé', () {
    // 30 min, 4000 -> 3800 mAh, 80 % -> 75 % : 400 mA, 4000 mAh réels.
    final r = computeBatteryLife([
      BatterySample(ms: 0, level: 80, chargeMah: 4000),
      BatterySample(ms: 1800000, level: 75, chargeMah: 3800),
    ], designMah: 5000)!;
    expect(r.avgMa, closeTo(400, 0.01));
    expect(r.realCapacityMah, closeTo(4000, 0.01));
    expect(r.healthPercent, closeTo(80, 0.01));
    expect(r.remainingHours, closeTo(9.5, 0.01));
    expect(r.fullHours, closeTo(10, 0.01));
    expect(r.dropPerHour, closeTo(10, 0.01));
  });

  test('autonomie : sans compteur de charge, moyenne du courant', () {
    final r = computeBatteryLife([
      BatterySample(ms: 0, level: 50, currentMa: -300),
      BatterySample(ms: 600000, level: 50, currentMa: -500),
    ])!;
    expect(r.avgMa, closeTo(400, 0.01));
    expect(r.realCapacityMah, isNull);
  });

  test('autonomie : compteur figé, jamais de capacité à 0', () {
    // Le % baisse de 3 points mais le compteur ne bouge pas (émulateur, certains téléphones).
    final r = computeBatteryLife([
      BatterySample(ms: 0, level: 80, chargeMah: 10, currentMa: -900),
      BatterySample(ms: 210000, level: 77, chargeMah: 10, currentMa: -900),
    ], designMah: 1000)!;
    expect(r.avgMa, closeTo(900, 0.01));
    // 900 mA x 210 s = 52,5 mAh pour 3 % -> 1750 mAh, > 1,5 x l'origine : écarté.
    expect(r.realCapacityMah, isNull);
    expect(r.healthPercent, isNull);
    // Repli : 3 % en 210 s -> 51,4 %/h -> 77 % restants = 1,5 h.
    expect(r.remainingHours, closeTo(77 / (3 / (210 / 3600)), 0.01));
  });

  test('autonomie : pas assez de mesures', () {
    expect(computeBatteryLife([BatterySample(ms: 0, level: 50)]), isNull);
  });
}
