<div align="center">

# Wabot Dashboard

**Application Flutter multiplateforme pour piloter votre bot WhatsApp**

[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/ferelking242/wabot_app/releases)
[![iOS](https://img.shields.io/badge/iOS-ready-000000?logo=apple&logoColor=white)](https://github.com/ferelking242/wabot_app)
[![Web](https://img.shields.io/badge/Web-live-25D366?logo=googlechrome&logoColor=white)](https://ferelking242.github.io/wabot)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Build Android](https://github.com/ferelking242/wabot_app/actions/workflows/build-android.yml/badge.svg)](https://github.com/ferelking242/wabot_app/actions/workflows/build-android.yml)
[![Deploy Web](https://github.com/ferelking242/wabot_app/actions/workflows/build-web-deploy.yml/badge.svg)](https://github.com/ferelking242/wabot_app/actions/workflows/build-web-deploy.yml)

---

### 🌐 [ferelking242.github.io/wabot](https://ferelking242.github.io/wabot) — Essayez la version web maintenant

</div>

---

## Vue d'ensemble

Wabot Dashboard est l'interface officielle du bot WhatsApp [Wabot](https://github.com/ferelking242/WABOT). Développée en Flutter, elle tourne nativement sur **Android**, **iOS**, **Windows**, **Linux**, **macOS** et **navigateur web** — avec un seul codebase.

Le client n'a rien à configurer. Il ouvre l'app, il se connecte, il pilote son bot.

---

## Fonctionnalités

| Module | Ce qu'il fait |
|--------|---------------|
| **Dashboard** | Statut du bot en temps réel, CPU / RAM, uptime, latence, messages/min |
| **Chats** | Liste complète des conversations gérées par le bot |
| **Devices** | Gestion des sessions WhatsApp actives |
| **Pairing** | Liaison d'un compte WhatsApp par code de jumelage |
| **Analytics** | Graphiques messages, commandes, groupes, utilisateurs sur 7/30/90 j |
| **Logs** | Terminal live des logs du bot avec filtres par niveau (INFO, WARN, ERROR) |
| **Automation** | Création de workflows automatisés (déclencheur → action) |
| **Paramètres** | Thème, sécurité, configuration de la connexion au bot |

---

## Plateformes

| Plateforme | Statut | Livraison |
|------------|--------|-----------|
| Android (arm64) | ✅ Production | APK via GitHub Releases |
| iOS | ✅ Prêt | Build Xcode / TestFlight |
| Web | ✅ Live | [ferelking242.github.io/wabot](https://ferelking242.github.io/wabot) |
| Windows | ✅ Prêt | Build local |
| Linux | ✅ Prêt | Build local |
| macOS | ✅ Prêt | Build Xcode |

---

## CI/CD

Chaque push sur `main` déclenche automatiquement deux pipelines :

| Workflow | Déclencheur | Sortie |
|----------|-------------|--------|
| `build-android.yml` | Push `main` (lib / android) | APK arm64-v8a → GitHub Releases |
| `build-web-deploy.yml` | Push `main` (lib / web) | Build web → [ferelking242.github.io/wabot](https://ferelking242.github.io/wabot) |

Aucune intervention manuelle requise. Le site web est toujours synchronisé avec `main`.

---

## Architecture

```
wabot_app/
├── .github/
│   └── workflows/
│       ├── build-android.yml          # CI Android → APK release
│       └── build-web-deploy.yml       # CI Web → GitHub Pages
│
├── lib/
│   ├── main.dart                      # Point d'entrée
│   ├── router/                        # Navigation (go_router)
│   │   └── app_router.dart
│   ├── theme/                         # Système de design
│   │   ├── app_colors.dart            # Palette de couleurs
│   │   └── app_theme.dart             # ThemeData light / dark
│   ├── core/
│   │   └── constants/                 # Constantes globales
│   ├── services/                      # Couche réseau
│   │   ├── api_service.dart           # Client REST (Dio)
│   │   ├── websocket_service.dart     # Connexion temps réel
│   │   └── storage_service.dart       # Persistance locale
│   ├── shared/
│   │   ├── models/                    # Modèles de données
│   │   └── widgets/                   # Widgets réutilisables
│   └── features/                      # Modules par fonctionnalité
│       ├── auth/                      # Authentification
│       ├── onboarding/                # Premier lancement
│       ├── dashboard/                 # Tableau de bord
│       ├── chats/                     # Conversations
│       ├── devices/                   # Sessions WhatsApp
│       ├── analytics/                 # Statistiques
│       ├── logs/                      # Logs temps réel
│       ├── automation/                # Workflows automatisés
│       └── settings/                  # Paramètres
│
├── android/                           # Plateforme Android
├── ios/                               # Plateforme iOS
├── web/                               # Plateforme Web
└── pubspec.yaml
```

---

## Stack technique

| Domaine | Package | Rôle |
|---------|---------|------|
| State management | `flutter_riverpod` + `riverpod_annotation` | État global réactif |
| Navigation | `go_router` | Routing déclaratif deep-link |
| HTTP | `dio` | Client REST avec intercepteurs |
| WebSocket | `web_socket_channel` | Logs et statut temps réel |
| Persistance | `flutter_secure_storage` + `shared_preferences` | Credentials et préférences |
| Design | `flex_color_scheme` + `google_fonts` + `flutter_animate` | Thème et animations |
| Charts | `fl_chart` | Graphiques analytics |
| Responsive | `responsive_framework` | Adaptation PC / tablette / mobile |

---

## Installation développeur

### Prérequis

- Flutter SDK ≥ 3.16
- Dart SDK ≥ 3.2
- Android SDK (pour build Android)
- Xcode (pour build iOS / macOS)

### Lancer en local

```bash
git clone https://github.com/ferelking242/wabot_app
cd wabot_app
flutter pub get

flutter run -d chrome          # Web
flutter run -d linux           # Linux desktop
flutter run                    # Android connecté
```

### Builder manuellement

```bash
# Android ARM64
flutter build apk --target-platform android-arm64 --release --split-per-abi

# Web (base-href pour GitHub Pages)
flutter build web --release --web-renderer canvaskit --base-href /wabot/

# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

---

## Connexion au bot

L'app se connecte automatiquement à votre instance [Wabot](https://github.com/ferelking242/WABOT) via son API REST et WebSocket. L'utilisateur saisit l'URL de son bot une seule fois lors de la configuration initiale — aucune manipulation technique requise ensuite.

En l'absence de bot, l'app fonctionne en **mode démo** avec des données simulées.

---

## Licence

MIT © [ferelking242](https://github.com/ferelking242)
