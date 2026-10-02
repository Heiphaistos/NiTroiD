import 'native.dart';

/// Catégorie de données personnelles et permissions Android qui y donnent accès.
class PrivacyCategory {
  const PrivacyCategory(this.id, this.title, this.permissions, {this.special = const []});

  final String id;
  final String title;
  final List<String> permissions;

  /// Accès spéciaux (voir `AppEntry.specialAccess`) rattachés à la catégorie.
  final List<String> special;
}

const privacyCategories = <PrivacyCategory>[
  PrivacyCategory('location', 'Localisation', [
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
  ]),
  PrivacyCategory('camera', 'Caméra', ['android.permission.CAMERA']),
  PrivacyCategory('mic', 'Micro', ['android.permission.RECORD_AUDIO']),
  PrivacyCategory('contacts', 'Contacts', [
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.GET_ACCOUNTS',
  ]),
  PrivacyCategory('sms', 'SMS', [
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.SEND_SMS',
    'android.permission.RECEIVE_MMS',
  ], special: ['defaultSms']),
  PrivacyCategory('calls', 'Appels', [
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.CALL_PHONE',
    'android.permission.READ_PHONE_STATE',
    'android.permission.READ_PHONE_NUMBERS',
    'android.permission.ANSWER_PHONE_CALLS',
  ]),
  PrivacyCategory('media', 'Photos, vidéos & fichiers', [
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
  ]),
  PrivacyCategory('calendar', 'Agenda', ['android.permission.READ_CALENDAR', 'android.permission.WRITE_CALENDAR']),
  PrivacyCategory('body', 'Santé & activité physique', [
    'android.permission.BODY_SENSORS',
    'android.permission.BODY_SENSORS_BACKGROUND',
    'android.permission.ACTIVITY_RECOGNITION',
  ]),
  PrivacyCategory('nearby', 'Appareils à proximité', [
    'android.permission.BLUETOOTH_SCAN',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.BLUETOOTH_ADVERTISE',
    'android.permission.NEARBY_WIFI_DEVICES',
    'android.permission.UWB_RANGING',
  ]),
  PrivacyCategory('screen', 'Lecture de l’écran & notifications', [], special: ['accessibility', 'notificationListener']),
  PrivacyCategory('control', 'Contrôle de l’appareil', [], special: ['deviceAdmin', 'installPackages', 'overlay', 'vpn']),
];

/// Regroupe les applications par type de donnée accessible, en ignorant
/// optionnellement les applications système.
Map<PrivacyCategory, List<AppEntry>> groupByPrivacy(List<AppEntry> apps, {bool includeSystem = false}) {
  final out = <PrivacyCategory, List<AppEntry>>{};
  for (final cat in privacyCategories) {
    final matches = apps.where((a) {
      if (a.system && !includeSystem) return false;
      return a.grantedPermissions.any(cat.permissions.contains) || a.specialAccess.any(cat.special.contains);
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    out[cat] = matches;
  }
  return out;
}
