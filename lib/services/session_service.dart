import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';

/// Persiste e recupera os dados de sessão do utilizador autenticado.
/// Acesse via [SessionService.instance] (singleton).
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kToken       = 'auth_token';
  static const _kUserId      = 'user_id';
  static const _kUsername    = 'username';
  static const _kClientId    = 'client_id';
  static const _kClientName  = 'client_name';
  static const _kClientPhone = 'client_phone';
  static const _kClientAddr  = 'client_address';
  static const _kClientVat   = 'client_vat';

  // ── Cache em memória (disponível durante a sessão) ─────────────────────────

  AuthResponse? _current;
  AuthResponse? get current => _current;

  String? get token       => _current?.token;
  String? get username    => _current?.username;
  int?    get clientId    => _current?.client.id;
  String? get clientName  => _current?.client.name;
  String? get clientPhone => _current?.client.phone;
  String? get clientAddr  => _current?.client.address;

  // ── Persistência ───────────────────────────────────────────────────────────

  Future<void> save(AuthResponse auth) async {
    _current = auth;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken,       auth.token);
    await prefs.setInt   (_kUserId,      auth.userId);
    await prefs.setString(_kUsername,    auth.username);
    await prefs.setInt   (_kClientId,    auth.client.id);
    await prefs.setString(_kClientName,  auth.client.name);
    await prefs.setString(_kClientPhone, auth.client.phone);
    await prefs.setString(_kClientAddr,  auth.client.address);
    await prefs.setString(_kClientVat,   auth.client.vat);
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

    // Sessão salva antes de incluir client_id → força novo login
    if (!prefs.containsKey(_kClientId)) {
      await clear();
      return false;
    }

    _current = AuthResponse(
      userId:   prefs.getInt(_kUserId) ?? 0,
      username: prefs.getString(_kUsername) ?? '',
      token:    token,
      client: Client(
        id:        prefs.getInt(_kClientId) ?? 0,
        name:      prefs.getString(_kClientName)  ?? '',
        email:     null,
        phone:     prefs.getString(_kClientPhone) ?? '',
        address:   prefs.getString(_kClientAddr)  ?? '',
        vat:       prefs.getString(_kClientVat)   ?? '',
        active:    true,
        createdBy: '',
      ),
    );
    return true;
  }

  Future<void> clear() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── JWT ────────────────────────────────────────────────────────────────────

  /// Decodifica o payload do JWT e verifica se já expirou.
  /// Não valida a assinatura — isso é responsabilidade do servidor.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Base64Url pode não ter padding — completar para múltiplo de 4
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

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true; // qualquer erro → considera expirado
    }
  }
}
