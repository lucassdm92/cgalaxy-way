class Client {
  final int id;
  final String name;
  final String? email;
  final String phone;
  final String address;
  final String vat;
  final bool active;
  final String createdBy;

  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.vat,
    required this.active,
    required this.createdBy,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id:        json['id'] as int,
        name:      json['name'] as String,
        email:     json['email'] as String?,
        phone:     json['phone'] as String,
        address:   json['address'] as String,
        vat:       json['vat'] as String,
        active:    json['active'] as bool,
        createdBy: json['created_by'] as String,
      );
}

class AuthResponse {
  final int userId;
  final String username;
  final String token;
  final Client client;

  const AuthResponse({
    required this.userId,
    required this.username,
    required this.token,
    required this.client,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        userId:   json['user_id'] as int,
        username: json['username'] as String,
        token:    json['token'] as String,
        client:   Client.fromJson(json['client'] as Map<String, dynamic>),
      );
}
