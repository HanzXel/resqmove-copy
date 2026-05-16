// Central API flags, base URL, and app-wide constants.
// Override at build/run time with --dart-define.
//
// ── HOW TO USE ──────────────────────────────────────────────────────────────
//
// Development (emulator):
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
//
// Development (physical device on same Wi-Fi as PC):
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.XX:8000/api/v1
//
// Production APK (deployed backend):
//   flutter build apk --release \
//     --dart-define=API_BASE_URL=https://api.resqmove.com/api/v1 \
//     --dart-define=HOTLINE_NUMBER=+639XXXXXXXXX
//
// Mock mode (no backend running):
//   flutter run --dart-define=USE_MOCK_API=true

class AppConfig {
  AppConfig._();

  // ── API ──────────────────────────────────────────────────────────────────

  // ── IMPORTANT ────────────────────────────────────────────────────────────
  // The default below ONLY works inside an Android emulator (10.0.2.2 routes
  // to your PC's localhost). On a real device it will time out immediately.
  //
  // For a physical device on the same Wi-Fi:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.X.X:8000/api/v1
  //
  // For a release APK (backend must be publicly reachable):
  //   flutter build apk --release \
  //     --dart-define=API_BASE_URL=https://your-backend.com/api/v1 \
  //     --dart-define=HOTLINE_NUMBER=+639XXXXXXXXX
  //
  // For testing without any backend:
  //   flutter run --dart-define=USE_MOCK_API=true
  // ─────────────────────────────────────────────────────────────────────────
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// When true, HTTP is skipped and services use local simulation (no backend).
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  static String get safeApiBaseUrl {
    assert(
      apiBaseUrl.isNotEmpty,
      '\n\n⚠️  API_BASE_URL is not set!\n'
      'Run with: flutter run --dart-define=API_BASE_URL=http://YOUR_SERVER/api/v1\n',
    );
    return apiBaseUrl;
  }

  // ── Hotline ───────────────────────────────────────────────────────────────
  // Override with --dart-define=HOTLINE_NUMBER=+639XXXXXXXXX
  // Change the defaultValue below to your actual dispatch number.

  static const String hotlineNumber = String.fromEnvironment(
    'HOTLINE_NUMBER',
    defaultValue: '+63322661355', // Cebu City EMS dispatch
  );

  /// Display-friendly version of the hotline (shown in UI labels).
  static const String hotlineDisplay = String.fromEnvironment(
    'HOTLINE_DISPLAY',
    defaultValue: '(032) 266-1355', // Cebu City EMS dispatch
  );
}
