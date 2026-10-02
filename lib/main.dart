import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/dashboard.dart';
import 'screens/diagnostic.dart';
import 'screens/security.dart';
import 'screens/settings.dart';
import 'screens/tools.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themes = await ThemeController.load();
  applySystemBars();
  runApp(NitroidApp(themes: themes));
}

class NitroidApp extends StatelessWidget {
  const NitroidApp({super.key, required this.themes});

  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themes,
      builder: (context, _) => MaterialApp(
        title: 'NiTroiD',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(themes.theme),
        home: HomeShell(themes: themes),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themes});

  final ThemeController themes;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    const DashboardScreen(),
    const DiagnosticHub(),
    const SecurityScreen(),
    const ToolsHub(),
    SettingsHub(themes: widget.themes),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.biotech_outlined), selectedIcon: Icon(Icons.biotech), label: 'Diagnostic'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Sécurité'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Outils'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Réglages'),
        ],
      ),
    );
  }
}
