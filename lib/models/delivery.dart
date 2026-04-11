class Delivery {
  final String origin;
  final String destination;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? customerNote;
  final int priceCalculationId;
  final DateTime dateCreated;
  final String? externalDeliveryCode;
  final String? status;
  final int? passwordToCollect;

  const Delivery({
    required this.origin,
    required this.destination,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.customerNote,
    required this.priceCalculationId,
    required this.dateCreated,
    this.externalDeliveryCode,
    this.status,
    this.passwordToCollect,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        origin:               json['origin'] as String,
        destination:          json['destination'] as String,
        customerName:         json['customer_name'] as String,
        customerPhone:        json['customer_phone'] as String,
        customerEmail:        json['customer_email'] as String?,
        customerNote:         json['customer_note'] as String?,
        priceCalculationId:   json['price_calculation_id'] as int,
        dateCreated:          DateTime.parse(json['date_created'] as String),
        externalDeliveryCode: json['external_delivery_code'] as String?,
        status:               json['status'] as String?,
        passwordToCollect:    json['password_to_collect'] as int?,
      );

  String get dataFormatada {
    final d = dateCreated;
    final hora = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  $hora';
  }
}
