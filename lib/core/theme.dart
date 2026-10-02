import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palette active de NiTroiD. Les champs sont mutables : changer de thème les
/// remplace puis reconstruit l'application. Les valeurs par défaut (« Cyan nuit »)
/// sont celles partagées avec le site et les éditions desktop.
class NxColors {
  static Color primary = const Color(0xFF00D4FF);
  static Color secondary = const Color(0xFF7C3AED);
  static Color accent = const Color(0xFFF59E0B);
  static Color dark = const Color(0xFF0A0E27);
  static Color surface = const Color(0xFF121735);
  static Color surfaceHigh = const Color(0xFF1A2046);
  static Color ok = const Color(0xFF22C55E);
  static Color warn = const Color(0xFFF59E0B);
  static Color bad = const Color(0xFFEF4444);
  static Color muted = const Color(0xFF8B93B8);
  static Brightness brightness = Brightness.dark;

  static Color forStatus(String status) {
    switch (status) {
      case 'ok':
        return ok;
      case 'warn':
        return warn;
      case 'bad':
        return bad;
      default:
        return primary;
    }
  }

  static void apply(NxTheme t) {
    primary = t.primary;
    secondary = t.secondary;
    accent = t.accent;
    dark = t.background;
    surface = t.surface;
    surfaceHigh = t.surfaceHigh;
    muted = t.muted;
    ok = t.ok;
    warn = t.warn;
    bad = t.bad;
    brightness = t.brightness;
  }
}

/// Un thème nommé : couleurs d'accent, fonds et luminosité.
class NxTheme {
  const NxTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    this.brightness = Brightness.dark,
    this.muted = const Color(0xFF8B93B8),
    this.ok = const Color(0xFF22C55E),
    this.warn = const Color(0xFFF59E0B),
    this.bad = const Color(0xFFEF4444),
  });

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Brightness brightness;
  final Color muted;
  final Color ok;
  final Color warn;
  final Color bad;

  bool get isDark => brightness == Brightness.dark;
}

/// Une douzaine de thèmes, comme les autres applications Forge/NiTriTe.
const nxThemes = <NxTheme>[
  NxTheme(
    id: 'cyan', name: 'Cyan nuit',
    primary: Color(0xFF00D4FF), secondary: Color(0xFF7C3AED), accent: Color(0xFFF59E0B),
    background: Color(0xFF0A0E27), surface: Color(0xFF121735), surfaceHigh: Color(0xFF1A2046),
  ),
  NxTheme(
    id: 'midnight', name: 'Minuit',
    primary: Color(0xFF5B8DEF), secondary: Color(0xFF8B5CF6), accent: Color(0xFF38BDF8),
    background: Color(0xFF0B1020), surface: Color(0xFF141B2E), surfaceHigh: Color(0xFF1E273B),
  ),
  NxTheme(
    id: 'emerald', name: 'Émeraude',
    primary: Color(0xFF10B981), secondary: Color(0xFF0EA5E9), accent: Color(0xFFFACC15),
    background: Color(0xFF05140F), surface: Color(0xFF0C1F18), surfaceHigh: Color(0xFF123026),
  ),
  NxTheme(
    id: 'amber', name: 'Ambre',
    primary: Color(0xFFF59E0B), secondary: Color(0xFFEF4444), accent: Color(0xFFFBBF24),
    background: Color(0xFF17120A), surface: Color(0xFF231A0E), surfaceHigh: Color(0xFF322414),
  ),
  NxTheme(
    id: 'rose', name: 'Rose néon',
    primary: Color(0xFFEC4899), secondary: Color(0xFF8B5CF6), accent: Color(0xFFF472B6),
    background: Color(0xFF170911), surface: Color(0xFF1E1119), surfaceHigh: Color(0xFF2B1826),
  ),
  NxTheme(
    id: 'crimson', name: 'Cramoisi',
    primary: Color(0xFFEF4444), secondary: Color(0xFFF59E0B), accent: Color(0xFFFB7185),
    background: Color(0xFF160909), surface: Color(0xFF211010), surfaceHigh: Color(0xFF301818),
  ),
  NxTheme(
    id: 'violet', name: 'Violet',
    primary: Color(0xFF8B5CF6), secondary: Color(0xFFEC4899), accent: Color(0xFF22D3EE),
    background: Color(0xFF110A1F), surface: Color(0xFF1A1030), surfaceHigh: Color(0xFF261844),
  ),
  NxTheme(
    id: 'teal', name: 'Sarcelle',
    primary: Color(0xFF14B8A6), secondary: Color(0xFF6366F1), accent: Color(0xFF2DD4BF),
    background: Color(0xFF04140F), surface: Color(0xFF0A1F1C), surfaceHigh: Color(0xFF102E2A),
  ),
  NxTheme(
    id: 'slate', name: 'Ardoise',
    primary: Color(0xFF64748B), secondary: Color(0xFF94A3B8), accent: Color(0xFF38BDF8),
    background: Color(0xFF0B0F17), surface: Color(0xFF151A24), surfaceHigh: Color(0xFF1F2733),
  ),
  NxTheme(
    id: 'matrix', name: 'Terminal',
    primary: Color(0xFF22C55E), secondary: Color(0xFF16A34A), accent: Color(0xFF86EFAC),
    background: Color(0xFF020A05), surface: Color(0xFF06140C), surfaceHigh: Color(0xFF0B2012),
    muted: Color(0xFF6B997E),
  ),
  NxTheme(
    id: 'amoled', name: 'AMOLED noir',
    primary: Color(0xFF00E0C6), secondary: Color(0xFF7C3AED), accent: Color(0xFFF59E0B),
    background: Color(0xFF000000), surface: Color(0xFF0B0B0D), surfaceHigh: Color(0xFF17171B),
  ),
  NxTheme(
    id: 'light', name: 'Clair',
    brightness: Brightness.light,
    primary: Color(0xFF0284C7), secondary: Color(0xFF7C3AED), accent: Color(0xFFD97706),
    background: Color(0xFFF4F6FB), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFECF0F7),
    muted: Color(0xFF64748B),
  ),
  NxTheme(
    id: 'light-warm', name: 'Clair chaud',
    brightness: Brightness.light,
    primary: Color(0xFFDB2777), secondary: Color(0xFF9333EA), accent: Color(0xFFEA580C),
    background: Color(0xFFFBF5F2), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFF3E9E3),
    muted: Color(0xFF78716C),
  ),
];

NxTheme themeById(String? id) => nxThemes.firstWhere((t) => t.id == id, orElse: () => nxThemes.first);

/// Thème actif, persisté, qui déclenche la reconstruction de l'application.
class ThemeController extends ChangeNotifier {
  ThemeController(this._theme);

  NxTheme _theme;
  NxTheme get theme => _theme;

  static const _key = 'nitroid_theme';

  static Future<ThemeController> load() async {
    String? id;
    try {
      id = (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {}
    final t = themeById(id);
    NxColors.apply(t);
    return ThemeController(t);
  }

  Future<void> select(NxTheme t) async {
    if (t.id == _theme.id) return;
    _theme = t;
    NxColors.apply(t);
    applySystemBars();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, t.id);
    } catch (_) {}
  }
}

/// Barres système transparentes avec icônes contrastées selon le thème.
void applySystemBars() {
  final dark = NxColors.brightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    // true : Android dessine un léger voile derrière les boutons de navigation
    // pour qu'ils restent distincts et ne « fusionnent » pas avec l'app.
    systemNavigationBarContrastEnforced: true,
  ));
}

ThemeData buildTheme(NxTheme t) {
  final scheme = ColorScheme.fromSeed(
    seedColor: t.primary,
    brightness: t.brightness,
  ).copyWith(
    primary: t.primary,
    secondary: t.secondary,
    tertiary: t.accent,
    surface: t.background,
    surfaceContainerLowest: t.background,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surfaceHigh,
    surfaceContainerHighest: t.surfaceHigh,
    error: t.bad,
  );
  final onSurface = t.isDark ? Colors.white : const Color(0xFF0B1020);
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.background,
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      // Chaque AppBar impose sinon son propre style de barres système et la
      // barre de navigation Android « fusionne » avec l'app sur certains écrans.
      // On force partout le même style transparent et contrasté.
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: t.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: true,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.primary.withValues(alpha: t.isDark ? 0.12 : 0.18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: t.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    listTileTheme: ListTileThemeData(iconColor: t.primary),
    dividerTheme: DividerThemeData(color: onSurface.withValues(alpha: 0.06), space: 1),
  );
}
