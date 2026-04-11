import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/auth_response.dart';
import 'client_service.dart';
import 'session_service.dart';

/// Exceção lançada quando o login falha com motivo conhecido.
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

  Future<void> login(String username, String password) async {
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

    debugPrint('[AuthService] login: status=${response.statusCode}');
    debugPrint('[AuthService] login: body=${response.body}');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responseCode = body['responseCode'] as String?;

    if (responseCode != '200') {
      final message = body['message'] as String? ?? 'Erro do servidor (${response.statusCode}).';
      throw AuthException(message);
    }

    final data = body['data'] as Map<String, dynamic>;
    final auth = AuthResponse.fromJson(data);
    debugPrint('[AuthService] login: token salvo=${auth.token}');
    await SessionService.instance.save(auth);

    try {
      await ClientService.instance.fetchByUsername(auth.username);
    } on ClientException catch (e) {
      throw AuthException('Login efetuado, mas falha ao carregar dados da loja: ${e.message}');
    }
  }
}
