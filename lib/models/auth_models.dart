class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    };
  }
}

class AuthResponse {
  final String? token;
  final String? message;
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role;

  AuthResponse({
    this.token,
    this.message,
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      message: json['message'],
      id: json['id']?.toString(),
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      role: json['role'],
    );
  }

  // Convierte la respuesta de autenticación a un Map para User
  Map<String, dynamic>? toUserJson() {
    if (id == null && email == null && firstName == null) {
      return null;
    }
    return {
      'id': id,
      'email': email ?? '',
      'firstName': firstName ?? '',
      'lastName': lastName ?? '',
      'role': role ?? '',
    };
  }
}
