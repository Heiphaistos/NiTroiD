## NiTroiD 0.8.0 — test d’autonomie batterie

### Nouveau test matériel : Autonomie batterie
- Mesure de **5, 15 ou 30 minutes**, chargeur débranché, écran maintenu allumé : NiTroiD lit le compteur de charge toutes les 5 s.
- **Consommation moyenne** (mA), **% perdu par heure**, **autonomie restante** et **autonomie sur une charge pleine**.
- **Capacité réelle** comparée à la capacité d’origine → **santé de la batterie** et verdict (bon état / fatiguée / à remplacer).
- Si le téléphone a un compteur de charge figé ou absent, l’autonomie est extrapolée du % perdu et aucun faux verdict n’est affiché.
- Mesure interrompue automatiquement si le chargeur est rebranché.

## NiTroiD 0.7.0 — températures détaillées, bas d’écran corrigé

### Températures
- Avec les droits ADB (sans PC) ou le root : **tous les capteurs du système thermique** — CPU, GPU, coque, port USB, modem, NPU, caméra… — regroupés par catégorie, avec leur **seuil de bridage** et l’état de bridage en cours.
- Minimum et maximum de la session pour chaque capteur, courbe en direct, point le plus chaud.
- **Prévision à 10 s** de la marge avant bridage.
- Noms lisibles pour les zones thermiques brutes (gpuss, skin-therm, xo-therm…).

### Affichage
- Le bas des pages n’est plus rogné et ne passe plus sous les boutons retour / accueil / applications : une bande de la couleur de l’app les sépare du contenu.

## NiTroiD 0.6.0 — suite de tests matériel

Une vraie batterie de tests, dans Outils › Tests matériel :
- **Haut-parleurs** (Android) : canaux gauche / droite / stéréo, tonalités 200 Hz–10 kHz et balayage de fréquence.
- **Microphone** (Android) : niveau d’entrée en direct (barre + courbe), crête et maximum vus.
- **Caméras** : aperçu en direct, bascule avant / arrière, flash (via module caméra, Android et iOS).
- **Boutons physiques** (Android) : volume +/− et bouton caméra, détectés en direct.
- **Vibreur** : intensités et motifs (triple, crescendo).
- **Lampe (flash)**, **écran tactile** (multipoint), **pixels morts**, **proximité & luminosité** interactifs.

## NiTroiD 0.5.0 — ADB sans PC

### Droits ADB directement dans l'app (Android 11+)
- **ADB sans fil** (Outils › Centre développeur) : NiTroiD s'associe au « Débogage sans fil » du téléphone lui-même. Le code à 6 chiffres se tape **dans la notification**, sans quitter les Paramètres. Plus besoin de PC ni de câble.
- Avec ces droits : permissions avancées accordées en un geste, réglages cachés et options développeur, arrêt forcé / désactivation / désinstallation des applis système — tout ce qui exigeait le root.
- **Terminal** : commandes shell avec le root s'il est présent, sinon avec l'ADB.
- Le débogage sans fil se rallume tout seul après un changement de Wi-Fi (une fois la permission « réglages système » accordée).

### Signature
- Tous les APK sont signés avec la même clé depuis la 0.3.0 : la mise à jour s'installe par-dessus.

## NiTroiD 0.4.0 — édition développeur

### Centre développeur (Outils › Développeur, Android)
- **Root** : détection de l’accès superutilisateur fonctionnel.
- **Débloquer les permissions en un geste** (si root) : NiTroiD s’accorde WRITE_SECURE_SETTINGS, READ_LOGS, DUMP et l’accès aux données d’utilisation via root, sans passer par un PC.
- **Options pour les développeurs** appliquées en direct : débogage USB/sans fil, rester allumé en charge, afficher les appuis, position du pointeur, limites de mise en page, dépassement GPU, échelles d’animation, ne pas conserver les activités, données mobiles toujours actives, recherche Wi-Fi permanente… (via WRITE_SECURE_SETTINGS ou root).
- **Journal système en direct** (logcat) : flux temps réel, filtre, erreurs seules, pause, copie.

### Actions root sur les applications
Dans le détail d’une application, si le root est disponible : arrêt forcé, vider le cache, effacer les données, activer/désactiver.

### Analyse root approfondie
L’écran Root indique désormais si l’accès superutilisateur répond réellement (su).

## NiTroiD 0.3.0

### Nouveautés
- **Thèmes** : une douzaine de thèmes (Cyan nuit, Minuit, Émeraude, Ambre, Rose néon, Violet, Sarcelle, Terminal, AMOLED noir, Clair…), avec aperçu et choix dans Réglages › Thème. Le choix est mémorisé.
- **Root / Jailbreak — analyse détaillée** (Sécurité) : méthode de root (Magisk, KernelSU, APatch), applications qui demandent le superutilisateur, modules installés, état du bootloader et des partitions ; sur iOS, indices de jailbreak et intégrité.
- **Affichage** : la barre de navigation d’Android (retour/accueil/récents) ne « fusionne » plus avec l’application — barres système transparentes et contrastées, cohérentes sur tous les écrans.

### Signature (important)
- Pour que les mises à jour s’installent **par-dessus** sans désinstaller, tous les APK doivent être signés avec la **même** clé. Voir le README (section Signature) : soit commiter la clé partagée, soit ajouter les secrets de signature au dépôt.

## NiTroiD 0.2.0

### Téléchargement
- APK universel allégé (ARM uniquement) : environ 20 Mo de moins. Préférez l’APK **arm64** (19 Mo) sur un téléphone récent.
- Si le téléchargement semble bloqué sur le dernier Mo : ouvrez les téléchargements du navigateur, Chrome attend souvent une confirmation (« Télécharger quand même ») après son contrôle de sécurité.

### Nouveautés
- **Mise à jour intégrée** : NiTroiD vérifie les nouvelles versions, télécharge l’APK adapté au téléphone et lance l’installation, sans passer par le navigateur.
- **Confidentialité** : qui a accès à la localisation, la caméra, le micro, les SMS, les contacts, l’écran…
- **Appareils du réseau** : liste les appareils connectés au Wi-Fi (box, PC, iPhone, caméras, imprimantes) pour repérer un intrus.
- **Test du chargeur et du câble** : mesure le courant de charge pendant 30 s et donne un verdict.
- Écran **À propos** avec version, liens et signalement de bug.
- NiTroiD ne se signale plus lui-même dans l’analyse de sécurité.

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
