import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Choix du thème parmi la douzaine proposée, avec aperçu en direct.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key, required this.themes});

  final ThemeController themes;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  @override
  Widget build(BuildContext context) {
    final current = widget.themes.theme.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Thème')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
        children: [
          for (final t in nxThemes)
            _ThemeTile(
              theme: t,
              selected: t.id == current,
              onTap: () async {
                await widget.themes.select(t);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme, required this.selected, required this.onTap});

  final NxTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBg = theme.isDark ? Colors.white : const Color(0xFF0B1020);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.primary : theme.primary.withValues(alpha: 0.18),
            width: selected ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(theme.name,
                    style: TextStyle(color: onBg, fontWeight: FontWeight.w800, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
              if (selected) Icon(Icons.check_circle, color: theme.primary, size: 18),
            ]),
            const SizedBox(height: 4),
            Text(theme.isDark ? 'Sombre' : 'Clair',
                style: TextStyle(color: theme.muted, fontSize: 11)),
            const Spacer(),
            // Aperçu : une mini-carte avec les trois couleurs d'accent.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.primary.withValues(alpha: 0.12)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 54, height: 7, decoration: BoxDecoration(color: onBg.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 34, height: 6, decoration: BoxDecoration(color: theme.muted, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Row(children: [
                  _swatch(theme.primary),
                  _swatch(theme.secondary),
                  _swatch(theme.accent),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
