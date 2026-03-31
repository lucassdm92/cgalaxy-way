import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/delivery.dart';

class DeliveryService {
  DeliveryService._();
  static final DeliveryService instance = DeliveryService._();

  Future<List<Delivery>> fetchByClient(int clientId) async {
    final http.Response response;

    try {
      response = await http
          .get(Uri.parse(AppConfig.deliveriesByClient(clientId)))
          .timeout(AppConfig.timeout);
    } on Exception catch (e) {
      throw Exception('Não foi possível conectar ao servidor. ($e)');
    }

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Erro ao buscar entregas (${response.statusCode}).');
  }
}
