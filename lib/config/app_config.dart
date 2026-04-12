// ─── App Config ──────────────────────────────────────────────────────────────

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.91:8080',
  );

  static const String googleMapsKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '',
  );

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static String get login             => '$baseUrl/api/auth/login';
  static String get precos            => '$baseUrl/api/prices/current';
  static String get delivery          => '$baseUrl/api/delivery/request';
  static String deliveriesByClient(String userName) => '$baseUrl/api/delivery/client/$userName';
  static String clientByUsername(String username)   => '$baseUrl/api/client/$username';

  // ── Timeout ───────────────────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 20);
}
