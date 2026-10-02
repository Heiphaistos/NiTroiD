## NiTroiD 0.1.1

- Correctif : la section « Réseau mobile » ne s’interrompt plus sur les téléphones qui protègent l’état des données mobiles.
- Correctif : flux des capteurs en direct plus robuste si le service capteurs est absent.

## NiTroiD 0.1.0 — première version

L’édition mobile de NiTriTe : diagnostic, sécurité et maintenance pour Android et iOS.

### Fichiers
- `NiTroiD-*-android.apk` — APK universel (tous les téléphones Android 8.0+)
- `NiTroiD-*-android-arm64.apk` — plus léger, pour les téléphones récents (64 bits)
- `NiTroiD-*-android-armv7.apk` — anciens téléphones 32 bits
- `NiTroiD-*-ios-unsigned.ipa` — iOS 16+, à installer avec AltStore, SideStore, Sideloadly ou TrollStore

### Contenu
- Tableau de bord temps réel : score de santé, batterie, températures, RAM, stockage, fréquences CPU
- Diagnostic : système, SoC, batterie (usure, cycles, courant), zones thermiques, mémoire, stockage, écran, capteurs en direct, caméras, réseau, GPU/Vulkan, codecs & Widevine, getprop
- Sécurité : base anti-stalkerware Échap, analyse heuristique des applications, root/jailbreak, bootloader, correctifs, chiffrement, certificats, VPN/proxy
- Outils : gestionnaire d’applications, temps d’écran, tests matériel, benchmark, outils réseau, analyseur Wi-Fi, logcat, dumpsys, explorateur /proc
- Paramétrage : lanceurs, menus cachés, réglages avancés (animations, DNS privé…), guide ADB
- Rapport exportable en TXT, Markdown ou JSON
