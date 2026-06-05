abstract final class AppConstants {
  // App info
  static const String appName    = 'Wabot';
  static const String appVersion = '1.0.0';

  // ── Storage keys ────────────────────────────────────────────────────────────
  static const String keySetupDone = 'wabot_setup_done'; // bool
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage  = 'language';

  // Legacy (kept for migration, no longer used for auth flow)
  static const String keyApiUrl = 'api_url';
  static const String keyApiKey = 'wabot_api_key';

  // ── API paths ────────────────────────────────────────────────────────────────
  static const String apiStatus   = '/api/v1/instance/status';
  static const String apiQr       = '/api/v1/instance/qr';
  static const String apiPair     = '/api/v1/instance/pair';
  static const String apiInfo     = '/api/v1/instance/info';
  static const String apiMessages = '/api/v1/messages';
  static const String apiLogs     = '/api/v1/logs';
  static const String apiGroups   = '/api/v1/groups';

  // ── WebSocket ─────────────────────────────────────────────────────────────
  static const int wsReconnectDelay    = 3000;
  static const int wsHeartbeatInterval = 30000;
  static const int wsMaxRetries        = 10;

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const int apiTimeout     = 15000;
  static const int connectTimeout = 10000;

  // ── UI ────────────────────────────────────────────────────────────────────
  static const double sidebarWidth          = 220;
  static const double sidebarCollapsedWidth = 64;
  static const double mobileBreakpoint      = 600;
  static const double tabletBreakpoint      = 900;
  static const double desktopBreakpoint     = 1200;

  // ── Refresh intervals (ms) ───────────────────────────────────────────────
  static const int dashboardRefreshInterval = 5000;
  static const int logsRefreshInterval      = 1000;
  static const int maxLogLines              = 500;
  static const int pageSize                 = 20;
}
