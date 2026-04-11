import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/client_response.dart';
import 'session_service.dart';

class ClientException implements Exception {
  final String message;
  const ClientException(this.message);

  @override
  String toString() => message;
}

class ClientService {
  ClientService._();
  static final ClientService instance = ClientService._();

  Future<ClientResponse> fetchByUsername(String username) async {
    final url = AppConfig.clientByUsername(username);
    dev.log('ClientService: GET $url', name: 'ClientService');

    final http.Response response;

    try {
      response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${SessionService.instance.token}',
            },
          )
          .timeout(AppConfig.timeout);
    } on Exception catch (e) {
      dev.log('ClientService: erro de conexão — $e', name: 'ClientService');
      throw ClientException('Não foi possível conectar ao servidor. ($e)');
    }

    dev.log('ClientService: response ${response.statusCode} — ${response.body}', name: 'ClientService');

    if (response.statusCode != 200) {
      final message = 'Erro ao buscar dados da loja (${response.statusCode}).';
      dev.log('ClientService: erro — $message', name: 'ClientService');
      throw ClientException(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final client = ClientResponse.fromJson(body);
    dev.log('ClientService: cliente carregado — ${client.name}', name: 'ClientService');
    await SessionService.instance.saveClient(client);
    return client;
  }
}
