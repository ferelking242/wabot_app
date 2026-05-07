# Wabot Dashboard

A premium Flutter multiplatform dashboard for managing your [Wabot](https://github.com/ferelking242/wabot) WhatsApp bot instance.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.22-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.2-blue?logo=dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web%20|%20Windows%20|%20Linux%20|%20macOS-green" />
  <img src="https://img.shields.io/github/workflow/status/ferelking242/wabot_app/Build%20Web%20%26%20Deploy%20to%20GitHub%20Pages" />
</p>

## Live Web Dashboard

🌐 **[https://ferelking242.github.io/wabot](https://ferelking242.github.io/wabot)**

## Features

| Feature | Description |
|---------|-------------|
| 📊 **Dashboard** | Real-time bot stats, CPU/RAM charts, uptime, latency |
| 💬 **Chats** | Browse all conversations managed by the bot |
| 📱 **Devices** | Manage WhatsApp sessions and link new devices |
| 🔗 **Pairing** | Link your WhatsApp account with pairing code |
| 📈 **Analytics** | Messages, commands, groups, users over time |
| 📟 **Live Logs** | Terminal-style real-time bot logs with filters |
| 🤖 **Automation** | Create automated workflows (triggers + actions) |
| ⚙️ **Settings** | Theme, API URL, security PIN |

## Architecture

```
lib/
├── core/              # Constants, errors, utilities
├── shared/            # Reusable models and widgets
├── services/          # API, WebSocket, Storage services
├── router/            # go_router navigation
├── theme/             # Design system (colors, typography)
├── features/
│   ├── auth/          # PIN authentication
│   ├── dashboard/     # Bot status and metrics
│   ├── chats/         # Conversation list
│   ├── devices/       # Session management
│   ├── analytics/     # Charts and stats
│   ├── logs/          # Live log terminal
│   ├── automation/    # Workflow builder
│   ├── settings/      # App configuration
│   └── onboarding/    # First-time setup
└── main.dart
```

**Stack:** Flutter 3.22 · Riverpod · go_router · Dio · fl_chart · flutter_animate · responsive_framework

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.16
- Dart SDK ≥ 3.2

### Run locally
```bash
git clone https://github.com/ferelking242/wabot_app
cd wabot_app
flutter pub get
flutter run -d chrome          # Web
flutter run -d linux           # Linux desktop
flutter run                    # Connected Android device
```

### Build

```bash
# Android ARM64
flutter build apk --target-platform android-arm64 --release

# Web
flutter build web --release --web-renderer canvaskit --base-href /wabot/

# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

## CI/CD Workflows

| Workflow | Trigger | Output |
|----------|---------|--------|
| `build-android-arm64.yml` | Push to `main` | ARM64 APK artifact |
| `build-web-deploy.yml` | Push to `main` | Deployed to `ferelking242.github.io/wabot` |
| `build-all-platforms.yml` | Tag `v*` or manual | All platform artifacts + GitHub Release |

## Connecting to your Wabot

On first launch, enter your bot's API URL. The dashboard works in **demo mode** with mock data when the bot is unreachable.

For full functionality, the wabot backend needs to expose a simple REST API (see [wabot/services](https://github.com/ferelking242/wabot)).

## Inspired by

Designed with inspiration from Discord, Linear, Vercel Dashboard, and Raycast.

## License

MIT © [ferelking242](https://github.com/ferelking242)
