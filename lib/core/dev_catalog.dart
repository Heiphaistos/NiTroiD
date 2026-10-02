/// Un réglage « développeur » modifiable (via WRITE_SECURE_SETTINGS ou root).
class DevToggle {
  const DevToggle(this.ns, this.key, this.title, {this.desc, this.onValue = '1', this.offValue = '0'});

  final String ns; // global | secure | system
  final String key;
  final String title;
  final String? desc;
  final String onValue;
  final String offValue;

  String get full => '$ns:$key';
}

class DevChoice {
  const DevChoice(this.ns, this.key, this.title, this.options, {this.desc});

  final String ns;
  final String key;
  final String title;
  final String? desc;

  /// Libellé → valeur.
  final List<MapEntry<String, String>> options;

  String get full => '$ns:$key';
}

class DevGroup {
  const DevGroup(this.title, {this.toggles = const [], this.choices = const []});

  final String title;
  final List<DevToggle> toggles;
  final List<DevChoice> choices;
}

/// Reproduit (et dépasse) le menu « Options pour les développeurs » d'Android.
const devGroups = <DevGroup>[
  DevGroup('Débogage', toggles: [
    DevToggle('global', 'adb_enabled', 'Débogage USB', desc: 'Contrôle de l’appareil par ADB depuis un PC'),
    DevToggle('global', 'adb_wifi_enabled', 'Débogage sans fil', desc: 'ADB via le réseau Wi-Fi'),
    DevToggle('global', 'development_settings_enabled', 'Options développeur activées'),
    DevToggle('secure', 'development_settings_enabled', 'Options développeur (secure)'),
    DevToggle('global', 'stay_on_while_plugged_in', 'Rester allumé en charge', onValue: '7'),
    DevToggle('global', 'verifier_verify_adb_installs', 'Vérifier les apps via ADB', onValue: '1', offValue: '0'),
  ]),
  DevGroup('Affichage & rendu', toggles: [
    DevToggle('system', 'show_touches', 'Afficher les appuis', desc: 'Un repère visuel à chaque toucher'),
    DevToggle('system', 'pointer_location', 'Position du pointeur', desc: 'Coordonnées et trace du doigt en haut de l’écran'),
    DevToggle('global', 'debug.layout', 'Limites de mise en page', desc: 'Bordures des éléments d’interface'),
    DevToggle('secure', 'debug_gpu_overdraw', 'Dépassement GPU (overdraw)', onValue: 'show', offValue: 'false'),
    DevToggle('global', 'show_wifi_mac_randomization_status', 'Statut d’anonymisation MAC'),
  ], choices: [
    DevChoice('global', 'window_animation_scale', 'Animations des fenêtres', _animScales),
    DevChoice('global', 'transition_animation_scale', 'Animations de transition', _animScales),
    DevChoice('global', 'animator_duration_scale', 'Durée des animations', _animScales),
  ]),
  DevGroup('Applications & processus', toggles: [
    DevToggle('global', 'always_finish_activities', 'Ne pas conserver les activités',
        desc: 'Détruit chaque écran dès qu’on le quitte'),
  ], choices: [
    DevChoice('global', 'app_standby_enabled', 'Veille des applications', [
      MapEntry('Activée', '1'),
      MapEntry('Désactivée', '0'),
    ]),
  ]),
  DevGroup('Réseau', toggles: [
    DevToggle('global', 'mobile_data_always_on', 'Données mobiles toujours actives'),
    DevToggle('global', 'wifi_scan_always_enabled', 'Recherche Wi-Fi toujours active'),
    DevToggle('global', 'netstats_enabled', 'Statistiques réseau'),
  ]),
];

const _animScales = [
  MapEntry('Désactivé', '0'),
  MapEntry('0,5×', '0.5'),
  MapEntry('1×', '1'),
  MapEntry('1,5×', '1.5'),
  MapEntry('2×', '2'),
];

/// Tous les réglages à lire d'un coup.
List<String> allDevKeys() => [
      for (final g in devGroups) ...[
        for (final t in g.toggles) t.full,
        for (final c in g.choices) c.full,
      ],
    ];

/// Un réglage est « actif » si sa valeur courante vaut onValue (ou ≠ offValue par défaut).
bool isToggleOn(DevToggle t, String? value) {
  if (value == null) return false;
  if (t.onValue == '1' && t.offValue == '0') return value != '0' && value.isNotEmpty;
  return value == t.onValue;
}
