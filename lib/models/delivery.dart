class Delivery {
  final int id;
  final int clientId;
  final String origin;
  final String destination;
  final String customerName;
  final String customerPhone;
  final String? customerNote;
  final int priceCalculationId;
  final DateTime dateCreated;

  const Delivery({
    required this.id,
    required this.clientId,
    required this.origin,
    required this.destination,
    required this.customerName,
    required this.customerPhone,
    required this.customerNote,
    required this.priceCalculationId,
    required this.dateCreated,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        id:                 json['id'] as int,
        clientId:           json['clientId'] as int,
        origin:             json['origin'] as String,
        destination:        json['destination'] as String,
        customerName:       json['customerName'] as String,
        customerPhone:      json['customerPhone'] as String,
        customerNote:       json['customerNote'] as String?,
        priceCalculationId: json['priceCalculationId'] as int,
        dateCreated:        DateTime.parse(json['dateCreated'] as String),
      );

  String get dataFormatada {
    final d = dateCreated;
    final hora = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  $hora';
  }
}
