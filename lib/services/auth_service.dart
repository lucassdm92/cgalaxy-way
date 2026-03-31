import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/auth_response.dart';
import 'session_service.dart';

/// Exceção lançada quando o login falha com motivo conhecido (ex: 401).
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Serviço responsável por autenticação.
/// Acesse via [AuthService.instance] (singleton).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<AuthResponse> login(String username, String password) async {
    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(AppConfig.login),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(AppConfig.timeout);
    } on Exception catch (e) {
      throw AuthException('Não foi possível conectar ao servidor. ($e)');
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        final envelope = jsonDecode(response.body) as Map<String, dynamic>;
        final data = envelope['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw AuthException(envelope['message'] as String? ?? 'Resposta inválida do servidor.');
        }
        final auth = AuthResponse.fromJson(data);
        await SessionService.instance.save(auth);
        return auth;
      case 401:
        throw const AuthException('Usuário ou senha inválidos.');
      case 403:
        throw const AuthException('Acesso negado.');
      default:
        throw AuthException('Erro do servidor (${response.statusCode}).');
    }
  }
}
