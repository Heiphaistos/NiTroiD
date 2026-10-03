/// Une mesure du test d'autonomie.
class BatterySample {
  BatterySample({required this.ms, required this.level, this.chargeMah, this.currentMa});

  factory BatterySample.fromMap(Map<String, dynamic> m) => BatterySample(
        ms: (m['time'] as num?)?.toInt() ?? 0,
        level: (m['level'] as num?)?.toDouble() ?? 0,
        chargeMah: (m['chargeMah'] as num?)?.toDouble(),
        currentMa: (m['currentMa'] as num?)?.toDouble(),
      );

  final int ms;
  final double level;
  final double? chargeMah;
  final double? currentMa;
}

/// Résultat du test d'autonomie.
class BatteryLifeResult {
  BatteryLifeResult({
    required this.hours,
    required this.avgMa,
    required this.levelDrop,
    this.realCapacityMah,
    this.healthPercent,
    this.remainingHours,
    this.fullHours,
  });

  final double hours;

  /// Consommation moyenne en mA (positive = décharge).
  final double avgMa;

  /// Points de % perdus pendant la mesure.
  final double levelDrop;
  final double? realCapacityMah;
  final double? healthPercent;
  final double? remainingHours;
  final double? fullHours;

  double get dropPerHour => hours > 0 ? levelDrop / hours : 0;
}

/// Calcule l'autonomie à partir des mesures. La consommation vient en priorité du
/// compteur de charge (mAh consommés / durée), sinon de la moyenne du courant
/// instantané. La capacité réelle se mesure sur au moins 2 points de % perdus
/// (sinon l'arrondi du % fausse tout) et n'est gardée que si elle est plausible.
BatteryLifeResult? computeBatteryLife(List<BatterySample> s, {double? designMah}) {
  if (s.length < 2) return null;
  final first = s.first;
  final last = s.last;
  final hours = (last.ms - first.ms) / 3600000.0;
  if (hours <= 0) return null;

  // Compteur de charge exploitable seulement s'il a réellement baissé : certains
  // téléphones (et l'émulateur) le laissent figé alors que le % descend.
  final c0 = first.chargeMah;
  final c1 = last.chargeMah;
  final counterUsed = c0 != null && c1 != null && c0 - c1 >= 1 ? c0 - c1 : null;
  double? avg = counterUsed != null ? counterUsed / hours : null;
  if (avg == null) {
    final currents = s.map((e) => e.currentMa).whereType<double>().map((c) => c.abs()).toList();
    if (currents.isEmpty) return null;
    avg = currents.reduce((a, b) => a + b) / currents.length;
  }
  if (avg <= 0) return null;

  final drop = first.level - last.level;
  final consumed = counterUsed ?? avg * hours;
  double? capacity = drop >= 2 ? consumed / drop * 100 : null;
  // Sans baisse suffisante : capacité déduite de la charge actuelle et du %.
  if (capacity == null && counterUsed != null && c1 != null && last.level >= 10) capacity = c1 * 100 / last.level;
  // Valeur invraisemblable (compteur faux, mesure trop courte) : on n'affiche rien plutôt qu'un faux verdict.
  bool plausible(double c) =>
      c >= 500 && c <= 20000 && (designMah == null || designMah <= 0 || (c / designMah >= 0.3 && c / designMah <= 1.5));
  if (capacity != null && !plausible(capacity)) capacity = null;

  final health = capacity != null && designMah != null && designMah > 0 ? (capacity / designMah * 100).clamp(0, 120).toDouble() : null;
  // Charge restante : lecture directe du compteur quand il fonctionne, sinon déduite de la capacité.
  final remainingMah = counterUsed != null ? c1 : (capacity != null ? capacity * last.level / 100 : null);
  return BatteryLifeResult(
    hours: hours,
    avgMa: avg,
    levelDrop: drop,
    realCapacityMah: capacity,
    healthPercent: health,
    // Repli sans capacité fiable : extrapolation du % perdu par heure.
    remainingHours: remainingMah != null ? remainingMah / avg : (drop >= 1 ? last.level / (drop / hours) : null),
    fullHours: capacity != null ? capacity / avg : (drop >= 1 ? 100 / (drop / hours) : null),
  );
}
