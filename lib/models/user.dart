class User {
  final String? id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? code;

  User({
    this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.code,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['last_name'] ?? '',
      role: json['role'] ?? '',
      code: json['code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'code': code,
    };
  }

  String get fullName => '$firstName $lastName';
}
