// Central API flags, base URL, and app-wide constants.
// Backend is deployed on Render: https://resqmove-backend.onrender.com

class AppConfig {
  AppConfig._();

  // ── API Base URL ──────────────────────────────────────────────────────────
  // Deployed on Render. Override at build time with --dart-define if needed.
  //
  //   flutter run --dart-define=API_BASE_URL=https://resqmove-backend.onrender.com/api/v1
  //   flutter build apk --release --dart-define=API_BASE_URL=https://resqmove-backend.onrender.com/api/v1
  //
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://resqmove-backend.onrender.com/api/v1',
  );

  static String get safeApiBaseUrl {
    assert(
      apiBaseUrl.isNotEmpty,
      '\n\n⚠️  API_BASE_URL is not set!\n'
      'Run with: flutter run --dart-define=API_BASE_URL=https://resqmove-backend.onrender.com/api/v1\n',
    );
    return apiBaseUrl;
  }

  // ── Hotline ───────────────────────────────────────────────────────────────
  static const String hotlineNumber = String.fromEnvironment(
    'HOTLINE_NUMBER',
    defaultValue: '+63322661355', // Cebu City EMS dispatch
  );

  static const String hotlineDisplay = String.fromEnvironment(
    'HOTLINE_DISPLAY',
    defaultValue: '(032) 266-1355',
  );
}
