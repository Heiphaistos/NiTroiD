/// Formatage lisible des valeurs remontées par les ponts natifs.
String formatBytes(num? bytes, {int decimals = 1}) {
  if (bytes == null || bytes < 0) return '—';
  const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '${days}j ${hours}h ${minutes}min';
  if (hours > 0) return '${hours}h ${minutes}min';
  if (minutes > 0) return '${minutes}min ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

String formatFreqKhz(num? khz) {
  if (khz == null || khz <= 0) return '—';
  if (khz >= 1000000) return '${(khz / 1000000).toStringAsFixed(2)} GHz';
  return '${(khz / 1000).round()} MHz';
}

String formatPercent(num? ratio, {int decimals = 0}) {
  if (ratio == null || ratio.isNaN) return '—';
  return '${(ratio * 100).toStringAsFixed(decimals)} %';
}

String formatDate(int? epochMs) {
  if (epochMs == null || epochMs <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Les zones thermiques Linux exposent des millidegrés, parfois des degrés
/// ou des décidegrés selon le pilote. On ramène tout en °C plausibles.
double? normalizeThermal(num? raw) {
  if (raw == null) return null;
  var v = raw.toDouble();
  if (v.abs() >= 1000) {
    v /= 1000;
  } else if (v.abs() >= 200) {
    v /= 10;
  }
  if (v < -40 || v > 150) return null;
  return v;
}
