import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../models/client_response.dart';

/// Persiste e recupera os dados de sessão do utilizador autenticado.
/// Acesse via [SessionService.instance] (singleton).
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kToken    = 'auth_token';
  static const _kUsername = 'username';
  static const _kRole     = 'role';

  static const _kClientId        = 'client_id';
  static const _kClientName      = 'client_name';
  static const _kClientEmail     = 'client_email';
  static const _kClientPhone     = 'client_phone';
  static const _kClientAddr      = 'client_address';
  static const _kClientVat       = 'client_vat';
  static const _kClientCreatedBy = 'client_created_by';
  static const _kClientActive    = 'client_active';

  // ── Cache em memória ────────────────────────────────────────────────────────

  AuthResponse?   _auth;
  ClientResponse? _client;

  AuthResponse?   get auth   => _auth;
  ClientResponse? get client => _client;

  String? get token    => _auth?.token;
  String? get username => _auth?.username;
  String? get role     => _auth?.role;

  // ── Persistência ───────────────────────────────────────────────────────────

  Future<void> save(AuthResponse auth) async {
    _auth = auth;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken,    auth.token);
    await prefs.setString(_kUsername, auth.username);
    await prefs.setString(_kRole,     auth.role);
  }

  Future<void> saveClient(ClientResponse client) async {
    _client = client;
    final prefs = await SharedPreferences.getInstance();
    if (client.id != null) await prefs.setInt(_kClientId, client.id!);
    await prefs.setString(_kClientName,      client.name);
    await prefs.setString(_kClientEmail,     client.email ?? '');
    await prefs.setString(_kClientPhone,     client.phone);
    await prefs.setString(_kClientAddr,      client.address);
    await prefs.setString(_kClientVat,       client.vat);
    await prefs.setString(_kClientCreatedBy, client.createdBy);
    await prefs.setBool  (_kClientActive,    client.active);
  }

  /// Carrega os dados salvos. Retorna [true] se havia sessão válida (token não expirado).
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);

    if (token == null) return false;

    if (_isTokenExpired(token)) {
      await clear();
      return false;
    }

    if (!prefs.containsKey(_kClientId)) {
      await clear();
      return false;
    }

    _auth = AuthResponse(
      username: prefs.getString(_kUsername) ?? '',
      token:    token,
      role:     prefs.getString(_kRole) ?? '',
    );

    final savedUsername = prefs.getString(_kUsername) ?? '';
    _client = ClientResponse(
      id:        prefs.getInt(_kClientId),
      name:      prefs.getString(_kClientName)      ?? '',
      email:     prefs.getString(_kClientEmail),
      phone:     prefs.getString(_kClientPhone)     ?? '',
      address:   prefs.getString(_kClientAddr)      ?? '',
      vat:       prefs.getString(_kClientVat)       ?? '',
      createdBy: prefs.getString(_kClientCreatedBy) ?? '',
      active:    prefs.getBool(_kClientActive)      ?? true,
      user: ClientUser(
        username: savedUsername,
        active:   true,
        role:     prefs.getString(_kRole),
      ),
    );

    return true;
  }

  Future<void> clear() async {
    _auth   = null;
    _client = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── JWT ────────────────────────────────────────────────────────────────────

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      var payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final claims  = jsonDecode(decoded) as Map<String, dynamic>;
      final exp     = claims['exp'] as int?;

      if (exp == null) return true;

      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } catch (_) {
      return true;
    }
  }
}
