import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      final userData = await _storageService.getUserData();

      if (token != null && userData != null) {
        _apiService.setToken(token);
        _currentUser = User.fromJson(json.decode(userData));
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _authService.login(request);

      if (response.token != null) {
        await _storageService.saveToken(response.token!);
        _apiService.setToken(response.token!);

        // Crear el usuario desde la respuesta directa
        final userData = response.toUserJson();
        if (userData != null) {
          _currentUser = User.fromJson(userData);
          await _storageService.saveUserData(json.encode(userData));
        }

        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Error al iniciar sesión';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );

      final response = await _authService.register(request);

      if (response.token != null || response.message != null) {
        // Algunos APIs devuelven el token inmediatamente, otros requieren login
        if (response.token != null) {
          await _storageService.saveToken(response.token!);
          _apiService.setToken(response.token!);

          // Crear el usuario desde la respuesta directa
          final userData = response.toUserJson();
          if (userData != null) {
            _currentUser = User.fromJson(userData);
            await _storageService.saveUserData(json.encode(userData));
          }

          _isAuthenticated = true;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Error al registrar usuario';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _storageService.clearAll();
    _apiService.clearToken();
    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
