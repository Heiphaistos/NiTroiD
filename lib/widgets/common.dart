import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/theme.dart';

class NxCard extends StatelessWidget {
  const NxCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: NxColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: NxColors.muted),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Carte clé/valeur ; un appui long copie la valeur.
class InfoSectionCard extends StatelessWidget {
  const InfoSectionCard(this.section, {super.key});

  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NxCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(section.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: NxColors.primary)),
            ),
            for (final item in section.items) KeyValueRow(item.key, item.value),
          ],
        ),
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: '$label : $value'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« $label » copié')));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(label, style: const TextStyle(color: NxColors.muted, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(value,
                  textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 10});

  final String status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = NxColors.forStatus(status);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6),
      ]),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.color = NxColors.primary,
    this.progress,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(color: NxColors.muted, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: const TextStyle(color: NxColors.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jauge circulaire du score de santé.
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.value, required this.label, this.size = 132});

  final double value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.75 ? NxColors.ok : value >= 0.5 ? NxColors.warn : NxColors.bad;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1), color),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(value * 100).round()}', style: TextStyle(fontSize: size / 3.6, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: NxColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width / 11;
    final arcRect = rect.deflate(stroke / 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.12);
    canvas.drawArc(arcRect, 0, 2 * pi, false, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [NxColors.primary, color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -pi / 2, 2 * pi * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Petite courbe d'historique (températures, fréquences, courant…).
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.color = NxColors.primary, this.height = 48});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(values, color)));
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    if (hi - lo < 1e-6) {
      hi += 1;
      lo -= 1;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / (hi - lo) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: NxColors.muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: NxColors.muted)),
        ]),
      ),
    );
  }
}

/// Écran générique qui affiche les sections renvoyées par `Native.info`.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, required this.title, required this.category, this.header, this.refreshEvery});

  final String title;
  final String category;
  final Widget? header;
  final Duration? refreshEvery;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  List<InfoSection>? _sections;

  @override
  void initState() {
    super.initState();
    _load();
    final every = widget.refreshEvery;
    if (every != null) _tick(every);
  }

  Future<void> _tick(Duration every) async {
    while (mounted) {
      await Future.delayed(every);
      if (mounted) await _load();
    }
  }

  Future<void> _load() async {
    final data = await Native.info(widget.category);
    if (mounted) setState(() => _sections = data);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Actualiser'),
      ]),
      body: sections == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ?widget.header,
                  if (sections.isEmpty)
                    const EmptyState(icon: Icons.info_outline, text: 'Aucune donnée disponible sur cet appareil.'),
                  for (final s in sections) InfoSectionCard(s),
                ],
              ),
            ),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
