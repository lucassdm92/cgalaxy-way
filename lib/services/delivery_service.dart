import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/delivery.dart';
import 'session_service.dart';

class DeliveryService {
  DeliveryService._();
  static final DeliveryService instance = DeliveryService._();

  Future<List<Delivery>> fetchByClient(String userName) async {
    final url = AppConfig.deliveriesByClient(userName);
    debugPrint('[DeliveryService] fetchByClient: GET $url');
    debugPrint('[DeliveryService] fetchByClient: userName=$userName');
    debugPrint('[DeliveryService] fetchByClient: token=${SessionService.instance.token}');

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
      debugPrint('[DeliveryService] fetchByClient: erro de conexão -> $e');
      throw Exception('Não foi possível conectar ao servidor. ($e)');
    }

    debugPrint('[DeliveryService] fetchByClient: status=${response.statusCode}');
    debugPrint('[DeliveryService] fetchByClient: body=${response.body}');

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      debugPrint('[DeliveryService] fetchByClient: ${list.length} entrega(s) parseada(s).');
      return list
          .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Erro ao buscar entregas (${response.statusCode}).');
  }

  Future<void> requestDelivery({
    required int priceCalculationId,
    required String origin,
    required String destination,
    required String customerName,
    required String customerPhone,
    required String customerNote,
  }) async {
    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(AppConfig.delivery),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${SessionService.instance.token}',
            },
            body: jsonEncode({
              'price_calculation_id': priceCalculationId,
              'origin':               origin,
              'destination':          destination,
              'customer_name':        customerName,
              'customer_phone':       customerPhone,
              'customer_note':        customerNote,
              'user_name':            SessionService.instance.username,
            }),
          )
          .timeout(AppConfig.timeout);
    } on Exception catch (e) {
      throw Exception('Não foi possível conectar ao servidor. ($e)');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar pedido (${response.statusCode}).');
    }
  }
}
