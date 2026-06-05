# Wabot App — Architecture

> **Wabot** = WhatsApp Bot Dashboard by Aivos  
> Stack: Flutter (frontend) + Node.js/Baileys (backend)

---

## Overview

```
┌─────────────────────────────────────────────────────────┐
│                   wabot_app (Flutter)                   │
│   Android · iOS · Windows · macOS · Linux · Web (PWA)  │
└───────────────────┬─────────────────────────────────────┘
                    │  REST  +  WebSocket
                    │  X-API-Key header
┌───────────────────▼─────────────────────────────────────┐
│                    wabot (Node.js)                       │
│       Express REST API  ·  Baileys WA Client            │
│       Bull queues  ·  SQLite / JSON persistence         │
└─────────────────────────────────────────────────────────┘
```

---

## Authentication Flow

```
App launch
    │
    ▼
SharedPreferences.get('wabot_api_key')
    │
    ├─ null ──────────────────► LoginScreen
    │                               │
    │                         Enter API key (wbk_xxxx)
    │                               │
    └─ has key ◄────────────────────┘
         │
         ▼
    PairingScreen
         │
         ├─ GET /api/v1/instance/status
         │       connected: true  ──────────────────► Home (Dashboard)
         │       connected: false
         │           │
         │     ┌─────┴──────────┐
         │  QR Code tab     Code tab
         │     │                │
         │  GET /qr         POST /pair {phone}
         │  (poll 25s)      (get XXXX-XXXX)
         │     │                │
         │     └────────────────┘
         │           │
         │     User connects WA
         │           │
         │  GET /status (poll 3s)
         │       connected: true
         │           │
         └───────────►  Home (Dashboard)
```

---

## Flutter App Structure

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart         AppConfig constants (name, version, colors)
│   ├── constants/
│   │   └── app_constants.dart      Storage keys, timeouts, route names, API paths
│   ├── routing/
│   │   └── app_router.dart         GoRouter — splash → login → /pair → /home
│   └── theme/
│       └── app_theme.dart          FlexColorScheme dark theme
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       ├── login_screen.dart   API key entry (fallback auth)
│   │       └── splash_screen.dart  Init + WabotLogoWidget
│   ├── pairing/                    ← NEW
│   │   ├── presentation/
│   │   │   └── pairing_screen.dart QR / Pairing Code flow
│   │   └── providers/
│   │       └── pairing_provider.dart State management for pairing
│   ├── dashboard/                  Main metrics screen
│   ├── sessions/                   Connected WhatsApp sessions
│   ├── chats/                      Recent conversations
│   ├── logs/                       Live bot logs
│   ├── analytics/                  Charts and stats
│   ├── automation/                 Auto-reply rules
│   └── settings/                   App + bot configuration
├── presentation/
│   └── providers/
│       └── auth_providers.dart     AuthNotifier (StateNotifier<String?>)
├── services/
│   ├── api_service.dart            Dio HTTP client (X-API-Key auth)
│   ├── storage_service.dart        SharedPreferences wrapper
│   └── websocket_service.dart      Real-time bot events
└── shared/
    └── widgets/
        └── wabot_shell.dart        Adaptive nav shell (rail / bottom bar)
```

---

## REST API (wabot backend)

Base URL: `http(s)://<your-server>:3001`  
Auth: `X-API-Key: wbk_<hex>` header on all requests

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/api/v1/instance/status` | Connection status + memory |
| `GET`  | `/api/v1/instance/qr` | QR code (raw + base64 PNG) |
| `POST` | `/api/v1/instance/pair` | Request 8-digit pairing code `{phone}` |
| `POST` | `/api/v1/instance/reconnect` | Force WhatsApp reconnect |
| `GET`  | `/api/v1/instance/info` | Bot profile (phone, name) |
| `POST` | `/api/v1/messages/text` | Send text message |
| `POST` | `/api/v1/messages/image` | Send image |
| `POST` | `/api/v1/broadcast` | Bulk send (up to 500 numbers) |
| `POST` | `/api/v1/verify/send` | Send OTP via WhatsApp |
| `POST` | `/api/v1/verify/check` | Verify OTP code |
| `GET`  | `/api/v1/groups` | List groups |
| `GET`  | `/api/v1/webhooks` | List webhooks |
| `POST` | `/api/v1/webhooks` | Register webhook |
| `GET`  | `/api/v1/logs` | Query message history |
| `GET`  | `/api/v1/admin/keys` | List API keys |
| `POST` | `/api/v1/admin/keys` | Create API key |

---

## State Management

Uses **Riverpod** throughout:

| Provider | Type | Responsibility |
|----------|------|----------------|
| `authProvider` | `StateNotifierProvider<AuthNotifier, String?>` | API key auth state |
| `apiServiceProvider` | `Provider<ApiService>` | Dio HTTP client |
| `pairingProvider` | `NotifierProvider<PairingNotifier, PairingState>` | QR/Code pairing flow |
| `botStatusProvider` | `AsyncNotifierProvider<BotStatusNotifier, BotStatus>` | Dashboard status polling |
| `webSocketProvider` | `NotifierProvider<WebSocketService, WsState>` | Live bot events |

---

## Routing (GoRouter)

```
/           SplashScreen     — init, then redirect based on auth
/login      LoginScreen      — enter API key + URL
/pair       PairingScreen    — WhatsApp QR or pairing code login ← NEW
/home       WabotShell       — adaptive shell with sub-routes
```

Redirect logic:
1. Loading → `/`
2. No API key → `/login`
3. Has API key → `/pair` (pair screen detects connection, auto-goes to `/home`)

---

## Android Integration

The app connects to a **remote** wabot server over HTTP.  
For running wabot **locally on Android**, a foreground service is planned using `nodejs_mobile_flutter`.

Permissions declared in `AndroidManifest.xml`:
- `INTERNET`, `ACCESS_NETWORK_STATE`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`
- `WAKE_LOCK`

### Build Android APK

```bash
# Prerequisites: Flutter 3.22+, Android SDK 34, JDK 17
flutter pub get
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/
```

---

## Desktop Build

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

---

## Web / GitHub Pages

The app is deployed to GitHub Pages from the `docs/` folder.

```bash
flutter build web --base-href /wabot_app/ --release
cp -r build/web/* docs/
git push origin main
```

---

## wabot Backend — Quick Start

```bash
cd wabot
cp .env.example .env           # set API_PORT, WHATSAPP_PHONE_NUMBER (optional)
npm install
npm start                       # Starts on port 3001

# View the default API key in logs:
# [API] Default key created: wbk_xxxxxxxxxxxxxxxxxxxx
# Copy this key → paste in the Flutter app onboarding
```

---

## Security Notes

- API keys are hashed (SHA-256) before storage in `api/data/keys.json`
- Keys have per-key permissions and rate limits
- The `pair` endpoint requires auth — it's not a public bootstrap endpoint
- All sensitive data stored in SharedPreferences (encrypted on Android via EncryptedSharedPreferences in release builds)

---

*Last updated: June 2026 — Aivos*
