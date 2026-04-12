// ─── App Config ──────────────────────────────────────────────────────────────
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Ambiente { dev, prod }

const Ambiente ambienteAtual = Ambiente.dev;

class AppConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://192.168.0.91:8080';

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static String get login              => '$baseUrl/api/auth/login';
  static String get precos             => '$baseUrl/api/prices/current';
  static String get delivery           => '$baseUrl/api/delivery/request';
  static String deliveriesByClient(String userName)   => '$baseUrl/api/delivery/client/$userName';
  static String clientByUsername(String username)    => '$baseUrl/api/client/$username';

  // ── Google Maps ───────────────────────────────────────────────────────────
  static String get googleMapsKey => dotenv.env['MAPS_API_KEY'] ?? '';

  // ── Timeout ───────────────────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 20);
}
