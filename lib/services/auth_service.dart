import '../models/auth_models.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _apiService.post(
        Constants.loginEndpoint,
        body: request.toJson(),
      );
      
      return AuthResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _apiService.post(
        Constants.registerEndpoint,
        body: request.toJson(),
      );
      
      return AuthResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
