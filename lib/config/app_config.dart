// Central API flags and base URL. Override at build/run time with --dart-define.
//
// Examples:
//   flutter run --dart-define=USE_MOCK_API=true
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
//
// Host selection (same machine running `node backend/server.js`):
//   • Android emulator (default below) → http://10.0.2.2:8000/api/v1
//   • Android physical device on Wi‑Fi → http://<PC_LAN_IP>:8000/api/v1
//   • iOS Simulator → http://127.0.0.1:8000/api/v1
//   • iOS device → http://<PC_LAN_IP>:8000/api/v1
//
// The default is the Android emulator loopback alias. On a real phone that
// address does not exist — pass API_BASE_URL as above.

class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// When true, HTTP is skipped and services use local simulation (no backend).
  /// Default is **false** so release-style builds talk to your API. Use
  /// `--dart-define=USE_MOCK_API=true` when no server is running.
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );
}
