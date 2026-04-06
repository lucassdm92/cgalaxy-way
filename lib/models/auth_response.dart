class AuthResponse {
  final String username;
  final String token;
  final String role;

  const AuthResponse({
    required this.username,
    required this.token,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        username: json['username'] as String,
        token:    json['token'] as String,
        role:     json['role'] as String,
      );
}
