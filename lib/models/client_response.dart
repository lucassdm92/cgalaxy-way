class ClientUser {
  final String username;
  final bool active;
  final String? role;

  const ClientUser({
    required this.username,
    required this.active,
    required this.role,
  });

  factory ClientUser.fromJson(Map<String, dynamic> json) => ClientUser(
        username: json['username'] as String,
        active:   json['active'] as bool,
        role:     json['role'] as String?,
      );
}

class ClientResponse {
  final int? id;
  final String name;
  final String? email;
  final String phone;
  final String address;
  final String vat;
  final String createdBy;
  final bool active;
  final ClientUser user;
  final String? countryCode;

  const ClientResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.vat,
    required this.createdBy,
    required this.active,
    required this.user,
    this.countryCode,
  });

  factory ClientResponse.fromJson(Map<String, dynamic> json) => ClientResponse(
        id:          json['id'] as int?,
        name:        json['name'] as String,
        email:       json['email'] as String?,
        phone:       json['phone'] as String,
        address:     json['address'] as String,
        vat:         json['vat'] as String,
        createdBy:   json['created_by'] as String,
        active:      json['active'] as bool,
        user:        ClientUser.fromJson(json['user'] as Map<String, dynamic>),
        countryCode: json['country_code'] as String?,
      );
}
