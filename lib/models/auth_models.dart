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
  final String? jobId;
  final String? status;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? error;

  AuthResponse({
    this.token,
    this.message,
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.jobId,
    this.status,
    this.result,
    this.error,
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
      jobId: json['jobId'],
      status: json['status'],
      result: json['result'],
      error: json['error'],
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
