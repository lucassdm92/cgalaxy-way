// ─── App Config ──────────────────────────────────────────────────────────────
// Altere as URLs aqui conforme o ambiente (dev, staging, prod).

enum Ambiente { dev, prod }

const Ambiente ambienteAtual = Ambiente.dev;

class AppConfig {
  static final Map<Ambiente, String> _baseUrls = {
    Ambiente.dev:  'http://localhost:8080',
    Ambiente.prod: 'https://api.galaxyway.com.br', // trocar quando disponível
  };

  static String get baseUrl => _baseUrls[ambienteAtual]!;

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static String get login              => '$baseUrl/api/auth/login';
  static String get precos             => '$baseUrl/api/prices/current';
  static String get delivery           => '$baseUrl/api/delivery/request';
  static String deliveriesByClient(int clientId) => '$baseUrl/api/delivery/client/$clientId';

  // ── Timeout ───────────────────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 20);
}
