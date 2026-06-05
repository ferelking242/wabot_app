abstract final class AppConstants {
  // App info
  static const String appName = 'Wabot Dashboard';
  static const String appVersion = '1.0.0';

  // Storage keys
  static const String keyApiUrl = 'api_url';
  static const String keySupabaseUrl = 'supabase_url';
  static const String keySupabaseAnonKey = 'supabase_anon_key';
  static const String keyAuthPin = 'auth_pin';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyOnboardingDone = 'onboarding_done';

  // Default API
  static const String defaultApiUrl = 'http://localhost:3001';

  // Websocket
  static const String defaultWsUrl = 'ws://localhost:3001';
  static const int wsReconnectDelay = 3000;
  static const int wsHeartbeatInterval = 30000;
  static const int wsMaxRetries = 10;

  // Timeouts
  static const int apiTimeout = 15000;
  static const int connectTimeout = 10000;

  // UI
  static const double sidebarWidth = 220;
  static const double sidebarCollapsedWidth = 64;
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Refresh intervals (ms)
  static const int dashboardRefreshInterval = 5000;
  static const int logsRefreshInterval = 1000;

  // Log limits
  static const int maxLogLines = 500;

  // Pagination
  static const int pageSize = 20;

  // Routes
  static const String routeOnboarding = '/onboarding';
  static const String routeAuth = '/auth';
  static const String routePair = '/pair';
  static const String routeDashboard = '/';
  static const String routeChats = '/chats';
  static const String routeDevices = '/devices';
  static const String routePairing = '/devices/pairing';
  static const String routeLogs = '/logs';
  static const String routeAnalytics = '/analytics';
  static const String routeAutomation = '/automation';
  static const String routeSettings = '/settings';

  // API key storage key
  static const String keyApiKey = 'wabot_api_key';

  // wabot REST API paths (base = keyApiUrl)
  static const String apiStatus   = '/api/v1/instance/status';
  static const String apiQr       = '/api/v1/instance/qr';
  static const String apiPair     = '/api/v1/instance/pair';
  static const String apiInfo     = '/api/v1/instance/info';
  static const String apiMessages = '/api/v1/messages';
  static const String apiLogs     = '/api/v1/logs';
  static const String apiGroups   = '/api/v1/groups';
}
