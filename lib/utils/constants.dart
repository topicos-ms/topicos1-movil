import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://10.0.2.1:3000/api';
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  
  // App Info
  static const String appName = 'Universidad Autónoma Gabriel René Moreno';
  static const String appVersion = '1.0.0';
}
