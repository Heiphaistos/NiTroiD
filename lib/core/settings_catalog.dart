/// Raccourci vers un écran de réglages : une action d'Intent Android, une
/// activité précise (souvent cachée), ou une URL iOS.
class SettingsShortcut {
  const SettingsShortcut(this.title, this.action, {this.component, this.hidden = false, this.note});

  final String title;
  final String action;

  /// `paquet/classe` pour les menus cachés lancés explicitement.
  final String? component;
  final bool hidden;
  final String? note;
}

class SettingsGroup {
  const SettingsGroup(this.title, this.items);

  final String title;
  final List<SettingsShortcut> items;
}

const androidSettings = <SettingsGroup>[
  SettingsGroup('Menus cachés & diagnostic', [
    SettingsShortcut('Menu de test (*#*#4636#*#*)', '',
        component: 'com.android.settings/com.android.settings.Settings\$TestingSettingsActivity', hidden: true),
    SettingsShortcut('Infos radio / téléphone', '',
        component: 'com.android.phone/com.android.phone.settings.RadioInfo',
        hidden: true,
        note: 'Puissance du signal, type de réseau forcé, ping'),
    SettingsShortcut('Infos radio (ancien emplacement)', '',
        component: 'com.android.settings/com.android.settings.RadioInfo', hidden: true),
    SettingsShortcut('Historique des notifications (journal)', '',
        component: 'com.android.settings/com.android.settings.Settings\$NotificationStationActivity', hidden: true),
    SettingsShortcut('Statistiques d’utilisation (système)', '',
        component: 'com.android.settings/com.android.settings.UsageStatsActivity', hidden: true),
    SettingsShortcut('System UI Tuner', '',
        component: 'com.android.systemui/com.android.systemui.tuner.TunerActivity', hidden: true),
    SettingsShortcut('Administrateurs de l’appareil', '',
        component: 'com.android.settings/com.android.settings.Settings\$DeviceAdminSettingsActivity', hidden: true),
    SettingsShortcut('Services en cours d’exécution', '',
        component: 'com.android.settings/com.android.settings.Settings\$RunningServicesActivity', hidden: true),
    SettingsShortcut('Options pour les développeurs', 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS'),
  ]),
  SettingsGroup('Système', [
    SettingsShortcut('Tous les paramètres', 'android.settings.SETTINGS'),
    SettingsShortcut('À propos du téléphone', 'android.settings.DEVICE_INFO_SETTINGS'),
    SettingsShortcut('Date et heure', 'android.settings.DATE_SETTINGS'),
    SettingsShortcut('Langues', 'android.settings.LOCALE_SETTINGS'),
    SettingsShortcut('Claviers', 'android.settings.INPUT_METHOD_SETTINGS'),
    SettingsShortcut('Comptes et synchronisation', 'android.settings.SYNC_SETTINGS'),
    SettingsShortcut('Ajouter un compte', 'android.settings.ADD_ACCOUNT_SETTINGS'),
    SettingsShortcut('Accessibilité', 'android.settings.ACCESSIBILITY_SETTINGS'),
  ]),
  SettingsGroup('Affichage & son', [
    SettingsShortcut('Affichage', 'android.settings.DISPLAY_SETTINGS'),
    SettingsShortcut('Éclairage nocturne', 'android.settings.NIGHT_DISPLAY_SETTINGS'),
    SettingsShortcut('Économiseur d’écran', 'android.settings.DREAM_SETTINGS'),
    SettingsShortcut('Caster l’écran', 'android.settings.CAST_SETTINGS'),
    SettingsShortcut('Son', 'android.settings.SOUND_SETTINGS'),
    SettingsShortcut('Ne pas déranger', 'android.settings.ZEN_MODE_PRIORITY_SETTINGS'),
  ]),
  SettingsGroup('Applications & lanceur', [
    SettingsShortcut('Lanceur (écran d’accueil) par défaut', 'android.settings.HOME_SETTINGS'),
    SettingsShortcut('Applications par défaut', 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS'),
    SettingsShortcut('Toutes les applications', 'android.settings.MANAGE_ALL_APPLICATIONS_SETTINGS'),
    SettingsShortcut('Sources inconnues', 'android.settings.MANAGE_UNKNOWN_APP_SOURCES'),
    SettingsShortcut('Superposition à l’écran', 'android.settings.action.MANAGE_OVERLAY_PERMISSION'),
    SettingsShortcut('Modification des paramètres système', 'android.settings.action.MANAGE_WRITE_SETTINGS'),
    SettingsShortcut('Accès aux données d’utilisation', 'android.settings.USAGE_ACCESS_SETTINGS'),
    SettingsShortcut('Accès aux notifications', 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS'),
    SettingsShortcut('Accès à tous les fichiers', 'android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION'),
    SettingsShortcut('Notifications', 'android.settings.ALL_APPS_NOTIFICATION_SETTINGS'),
  ]),
  SettingsGroup('Batterie & stockage', [
    SettingsShortcut('Utilisation de la batterie', 'android.intent.action.POWER_USAGE_SUMMARY'),
    SettingsShortcut('Économiseur de batterie', 'android.settings.BATTERY_SAVER_SETTINGS'),
    SettingsShortcut('Optimisation de la batterie', 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS'),
    SettingsShortcut('Stockage interne', 'android.settings.INTERNAL_STORAGE_SETTINGS'),
    SettingsShortcut('Carte mémoire', 'android.settings.MEMORY_CARD_SETTINGS'),
  ]),
  SettingsGroup('Réseau & connexions', [
    SettingsShortcut('Wi-Fi', 'android.settings.WIFI_SETTINGS'),
    SettingsShortcut('Panneau Internet', 'android.settings.panel.action.INTERNET_CONNECTIVITY'),
    SettingsShortcut('Réseau mobile', 'android.settings.NETWORK_OPERATOR_SETTINGS'),
    SettingsShortcut('Itinérance des données', 'android.settings.DATA_ROAMING_SETTINGS'),
    SettingsShortcut('Consommation des données', 'android.settings.DATA_USAGE_SETTINGS'),
    SettingsShortcut('Sans fil & réseaux', 'android.settings.WIRELESS_SETTINGS'),
    SettingsShortcut('Mode avion', 'android.settings.AIRPLANE_MODE_SETTINGS'),
    SettingsShortcut('Bluetooth', 'android.settings.BLUETOOTH_SETTINGS'),
    SettingsShortcut('NFC', 'android.settings.NFC_SETTINGS'),
    SettingsShortcut('VPN', 'android.settings.VPN_SETTINGS'),
  ]),
  SettingsGroup('Sécurité & confidentialité', [
    SettingsShortcut('Sécurité', 'android.settings.SECURITY_SETTINGS'),
    SettingsShortcut('Confidentialité', 'android.settings.PRIVACY_SETTINGS'),
    SettingsShortcut('Verrouillage de l’écran', 'android.app.action.SET_NEW_PASSWORD'),
    SettingsShortcut('Biométrie', 'android.settings.BIOMETRIC_ENROLL'),
    SettingsShortcut('Localisation', 'android.settings.LOCATION_SOURCE_SETTINGS'),
  ]),
];

const iosSettings = <SettingsGroup>[
  SettingsGroup('Réglages', [
    SettingsShortcut('Réglages de NiTroiD', 'app'),
    SettingsShortcut('Notifications de NiTroiD', 'notifications'),
    SettingsShortcut('App Réglages (accueil)', 'App-prefs:', note: 'Les liens profonds vers les sous-menus sont bloqués par Apple'),
  ]),
];
