# Wabot — WhatsApp Bot Dashboard

> **by Aivos** · Dashboard mobile & web pour gérer vos bots WhatsApp

[![Deploy Web](https://github.com/ferelking242/wabot_app/actions/workflows/build-web-deploy.yml/badge.svg)](https://github.com/ferelking242/wabot_app/actions/workflows/build-web-deploy.yml)
[![Build Android APK](https://github.com/ferelking242/wabot_app/actions/workflows/build-android-arm64.yml/badge.svg)](https://github.com/ferelking242/wabot_app/actions/workflows/build-android-arm64.yml)

🌐 **Web** : https://ferelking242.github.io/wabot_app/

---

## Fonctionnalités

- 📱 **Sessions WhatsApp** — Gérez plusieurs numéros, scan QR Code intégré
- 💬 **Conversations** — Historique de toutes les interactions bot
- 📋 **Logs temps réel** — Suivi des événements, webhooks, erreurs
- ⚡ **Automations** — Règles de réponse automatique configurables
- 🌙 **Thème sombre/clair** — Personnalisable depuis les paramètres
- 📐 **Responsive** — Adapté mobile, tablette et desktop

---

## Stack technique

| Technologie | Rôle |
|---|---|
| Flutter 3.29.3 | Framework UI cross-platform |
| Riverpod | State management |
| GoRouter | Routing déclaratif |
| FlexColorScheme | Système de thème |
| SharedPreferences | Authentification locale (clé API) |
| QR Flutter | Génération de QR codes |

---

## Démarrage local

```bash
# Prérequis : Flutter 3.29.3+
flutter pub get
flutter run                   # mobile/desktop
flutter run -d chrome         # web
```

---

## CI/CD — GitHub Actions

| Workflow | Déclencheur | Artefact |
|---|---|---|
| `🌐 Deploy Web` | Push sur `main` | GitHub Pages |
| `🤖 Build Android APK` | Push sur `main` | `wabot-android-arm64-v8a` |

### Secrets requis pour le signing Android

| Secret GitHub | Valeur |
|---|---|
| `WABOT_KEYSTORE_B64` | Keystore PKCS12 encodé base64 |
| `WABOT_STORE_PASSWORD` | Mot de passe du keystore |
| `WABOT_KEY_ALIAS` | `wabot-key` |
| `WABOT_KEY_PASSWORD` | Mot de passe de la clé |

---

## Architecture

```
lib/
├── core/
│   ├── config/         # AppConfig (nom, version, tagline)
│   ├── routing/        # GoRouter + redirect auth
│   └── theme/          # FlexColorScheme, ThemeController
├── features/
│   ├── auth/           # SplashScreen, LoginScreen
│   ├── dashboard/      # Dashboard stats & sections
│   ├── sessions/       # Sessions WhatsApp + QR
│   ├── chats/          # Conversations
│   ├── logs/           # Logs d'activité
│   └── automation/     # Règles d'automation
└── shared/
    ├── desktop_shell/  # Sidebar + header desktop
    ├── mobile_shell/   # Shell mobile avec drawer animé
    ├── pages/          # Settings, Notifications, Search
    └── widgets/        # Composants partagés
```

---

## Package ID

`com.aivos.wabot.app`

---

© 2025 Aivos — Tous droits réservés
