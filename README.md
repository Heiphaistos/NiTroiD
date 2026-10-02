<div align="center">
  <img src="assets/icon.png" width="120" alt="NiTroiD" />
  <h1>NiTroiD</h1>
  <p><strong>Diagnostic, sécurité et maintenance pour Android et iOS — l’édition mobile de NiTriTe.</strong></p>
</div>

NiTroiD montre ce que le téléphone ne montre pas d’habitude : températures de chaque zone thermique, usure réelle
de la batterie, fréquences de chaque cœur, niveau Widevine, propriétés système, applications espionnes, accès
dangereux… et donne accès aux menus cachés et réglages avancés.

## Fonctionnalités

| | Android | iOS |
|---|---|---|
| **Tableau de bord** temps réel + score de santé | ✅ | ✅ |
| Système, noyau, bootloader, Treble, SELinux | ✅ | ✅ (noyau Darwin, puce) |
| Processeur : clusters, cœurs ARM, fréquences live, gouverneur | ✅ | ✅ (puce, GPU Metal) |
| Batterie : usure estimée, cycles, courant/puissance live | ✅ | niveau et état (iOS cache la santé) |
| Températures : toutes les zones thermiques lisibles + état thermique | ✅ | état thermique |
| Mémoire (meminfo, zRAM), stockage (UFS/eMMC, chiffrement, FS) | ✅ | ✅ |
| Écran (modes, HDR), caméras, capteurs en direct | ✅ | ✅ |
| Réseau : Wi-Fi (norme, canal, sécurité), mobile, DNS privé, interfaces | ✅ | ✅ |
| GPU / OpenGL / Vulkan, codecs matériels, Widevine L1/L3 | ✅ | GPU |
| **Anti-malware** : base anti-stalkerware Échap + heuristiques (app masquée, sideload, accessibilité, admin, SMS…) | ✅ | contrôle d’intégrité |
| Root / jailbreak, bootloader, correctifs, verrouillage, certificats, VPN/proxy | ✅ | ✅ |
| Gestionnaire d’applications, temps d’écran, désinstallation | ✅ | — (bac à sable iOS) |
| **Lanceurs** : liste, ouverture, changement du lanceur par défaut | ✅ | — |
| **Menus cachés** (*#*#4636#*#*, infos radio, journal des notifications, System UI Tuner…) et 50+ raccourcis de réglages | ✅ | réglages de l’app |
| Réglages avancés : animations, DNS privé, écran allumé en charge, luminosité, veille | ✅ | — |
| Tests matériel : pixels morts, tactile/multipoint, vibreur, flash, haut-parleur | ✅ | ✅ |
| Benchmark CPU mono/multi, mémoire, stockage | ✅ | ✅ |
| Outils réseau : ping, DNS, port, IP publique, débit ; analyseur Wi-Fi | ✅ | ✅ (sans scan Wi-Fi) |
| logcat, dumpsys, explorateur /proc & /sys, getprop | ✅ | — |
| Confidentialité : qui a accès à la caméra, au micro, aux SMS, à la localisation… | ✅ | — |
| Appareils connectés au réseau Wi-Fi (détection d’intrus) | ✅ | ✅ |
| Test du chargeur et du câble (courant de charge) | ✅ | — |
| Mise à jour intégrée depuis les releases GitHub | ✅ | lien vers la release |
| Thèmes (une douzaine, mémorisés) | ✅ | ✅ |
| Centre développeur : root, octroi de permissions, options développeur, logcat live | ✅ | — |
| Actions root sur les apps : arrêt forcé, vider cache/données, activer/désactiver | ✅ (root) | — |
| Root / Jailbreak : analyse détaillée (méthode, modules, apps avec accès) | ✅ | ✅ (jailbreak) |
| Rapport TXT / Markdown / JSON partageable | ✅ | ✅ |

### Ce qu’Android et iOS interdisent (et comment NiTroiD s’adapte)

- **Sans root**, une app Android ne peut ni lire tout le journal système, ni modifier les réglages « secure ».
  NiTroiD propose un écran *Débloquer les accès (ADB)* : trois commandes à lancer une fois depuis un PC accordent
  `WRITE_SECURE_SETTINGS`, `READ_LOGS` et `DUMP`, ce qui active les réglages avancés, le logcat complet et dumpsys.
- Le **lanceur par défaut** se choisit toujours dans l’écran système : NiTroiD liste les lanceurs et y emmène directement.
- Certains fabricants bloquent la lecture des **zones thermiques** ou retirent des **menus cachés** : NiTroiD l’indique.
- **iOS** isole chaque application : impossible de lister les autres apps, lire les températures ou la santé batterie.
  La version iOS se concentre sur le matériel, l’intégrité (jailbreak, code, proxy/VPN) et les tests.

## Installation

Télécharger la dernière version sur la [page des releases](https://github.com/Heiphaistos/NiTroiD/releases)
ou sur [nitrite.heiphaistos.org/telechargement](https://nitrite.heiphaistos.org/telechargement/).

- **Android 8.0+** : installer `NiTroiD-x.y.z-android-arm64.apk` (téléphones récents) ou `NiTroiD-x.y.z-android.apk`
  (universel). Si le téléchargement reste bloqué à la fin, ouvrir les téléchargements du navigateur et confirmer
  « Télécharger quand même ». Ensuite, les mises à jour se font depuis l’app (Réglages › À propos & mises à jour).
- **iOS 16+** : `NiTroiD-x.y.z-ios-unsigned.ipa` s’installe avec AltStore, SideStore, Sideloadly ou TrollStore
  (une publication App Store nécessite un compte Apple Developer).

## Développement

Stack : [Flutter](https://flutter.dev) (Dart) + ponts natifs Kotlin (`android/app/src/main/kotlin`) et Swift
(`ios/Runner/AppDelegate.swift`) sur le canal `nitroid/native`.

```bash
flutter pub get
flutter analyze
flutter test
flutter run                      # appareil branché
flutter build apk --release      # Android
flutter build ios --no-codesign  # iOS (macOS + Xcode)
```

### Publication

La CI GitHub Actions (`.github/workflows/build.yml`) analyse, teste, compile l’APK et l’IPA, puis crée
automatiquement une release quand la version de `pubspec.yaml` change.

Signature Android stable (recommandé, sinon chaque build est signé avec une clé de debug différente et une mise à
jour impose de désinstaller) :

```bash
keytool -genkey -v -keystore nitroid.jks -keyalg RSA -keysize 4096 -validity 10000 -alias nitroid
base64 -w0 nitroid.jks   # → secret NITROID_KEYSTORE_BASE64
```

puis ajouter dans *Settings › Secrets and variables › Actions* : `NITROID_KEYSTORE_BASE64`,
`NITROID_KEYSTORE_PASSWORD`, `NITROID_KEY_ALIAS` (`nitroid`), `NITROID_KEY_PASSWORD`.

## Signature Android (mises à jour installables par-dessus)

Tous les APK publiés par la CI sont signés avec la **même clé privée**, fournie par les secrets du dépôt : `NITROID_KEYSTORE_BASE64`, `NITROID_KEYSTORE_PASSWORD`, `NITROID_KEY_ALIAS`, `NITROID_KEY_PASSWORD`. Les mises à jour s'installent donc par-dessus sans désinstaller (à partir de la 0.3.0 ; la 0.2.0 et avant, signées avec une clé de debug, demandent une désinstallation une fois).

- La CI **refuse de compiler** hors pull request si la clé manque : jamais de release signée avec une clé de debug.
- Ne jamais commiter de keystore (`*.jks` est ignoré) : une clé publique permettrait à n'importe qui de fabriquer une fausse mise à jour.
- Build local signé : créer `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), non versionné.

## Crédits

- Indicateurs de logiciels espions : [Échap — stalkerware-indicators](https://github.com/AssoEchap/stalkerware-indicators), licence CC-BY 4.0.
- Mascotte et identité visuelle : NiTriTe.

Licence MIT — © 2026 Heiphaistos
