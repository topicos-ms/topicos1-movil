import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/job_polling_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final JobPollingService _pollingService = JobPollingService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentJobId;
  Timer? _timeoutTimer;

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

    final completer = Completer<bool>();

    try {
      print('🔄 Iniciando login con HTTP Polling...');
      
      // PASO 1: Hacer POST para obtener jobId
      print('🌐 Enviando petición de login...');
      final request = LoginRequest(email: email, password: password);
      final response = await _authService.login(request);

      if (response.jobId != null) {
        _currentJobId = response.jobId!.trim();
        
        print('✅ JobId recibido: "$_currentJobId"');
        
        // PASO 2: Iniciar polling HTTP para consultar el estado del job
        print('📡 Iniciando polling HTTP...');
        
        _pollingService.startPolling(
          jobId: _currentJobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido: $data');
            
            final status = data['status'];
            
            if (status == 'completed') {
              print('✅ Login completado exitosamente');
              _pollingService.stopPolling();
              _handleLoginSuccess(data, completer);
            } else if (status == 'failed') {
              print('❌ Login falló');
              _pollingService.stopPolling();
              _handleLoginFailure(data, completer);
            } else if (status == 'timeout') {
              print('⏰ Timeout de polling');
              _pollingService.stopPolling();
              
              if (!completer.isCompleted) {
                _errorMessage = 'Tiempo de espera agotado. Intenta nuevamente.';
                _isLoading = false;
                _cleanup();
                notifyListeners();
                completer.complete(false);
              }
            }
          },
          interval: const Duration(seconds: 2),
          timeout: const Duration(seconds: 60),
        );
        
        return await completer.future;
      } else {
        _errorMessage = response.message ?? 'Error al iniciar sesión';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Error en login: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      _cleanup();
      notifyListeners();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
  }

  void _handleLoginSuccess(Map<String, dynamic> data, Completer<bool> completer) async {
    try {
      print('🔍 Procesando respuesta de login...');
      print('   Data completo: $data');
      
      final result = data['result'];
      print('   Result: $result');
      
      if (result != null) {
        // Caso 1: El token y datos de usuario están directamente en result
        if (result['token'] != null) {
          final token = result['token'] as String;
          print('   ✅ Token encontrado');
          
          // Guardar token
          await _storageService.saveToken(token);
          _apiService.setToken(token);
          print('   ✅ Token guardado');
          
          // Crear objeto de usuario desde result (los datos están en el mismo nivel que token)
          _currentUser = User.fromJson(result);
          await _storageService.saveUserData(json.encode(result));
          print('   ✅ Usuario guardado: ${_currentUser?.firstName}');
          
          _isAuthenticated = true;
          _isLoading = false;
          print('   ✅ Estado actualizado - autenticado');
          notifyListeners();
          _cleanup();
          
          if (!completer.isCompleted) {
            print('   ✅ Completando login exitoso');
            completer.complete(true);
          }
          return;
        }
      }
      
      // Si llegamos aquí, la respuesta no tiene el formato esperado
      print('   ❌ Respuesta inválida - no se encontró token en result');
      _errorMessage = 'Respuesta inválida del servidor';
      _isLoading = false;
      notifyListeners();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    } catch (e) {
      print('   ❌ Error al procesar respuesta: $e');
      _errorMessage = 'Error al procesar la respuesta: $e';
      _isLoading = false;
      notifyListeners();
      _cleanup();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
  }

  void _handleLoginFailure(Map<String, dynamic> data, Completer<bool> completer) {
    final error = data['error'];
    _errorMessage = error?['message'] ?? 'Error al iniciar sesión';
    _isLoading = false;
    _cleanup();
    notifyListeners();
    
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _pollingService.stopPolling();
    _currentJobId = null;
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

    final completer = Completer<bool>();

    try {
      print('🔄 Iniciando registro con HTTP Polling...');
      
      // PASO 1: Hacer POST para obtener jobId
      print('🌐 Enviando petición de registro...');
      final request = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );

      final response = await _authService.register(request);

      if (response.jobId != null) {
        _currentJobId = response.jobId!.trim();
        
        print('✅ JobId recibido: "$_currentJobId"');
        
        // PASO 2: Iniciar polling HTTP para consultar el estado del job
        print('� Iniciando polling HTTP...');
        
        _pollingService.startPolling(
          jobId: _currentJobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido: $data');
            
            final status = data['status'];
            
            if (status == 'completed') {
              print('✅ Registro completado exitosamente');
              _pollingService.stopPolling();
              _handleRegisterSuccess(data, completer);
            } else if (status == 'failed') {
              print('❌ Registro falló');
              _pollingService.stopPolling();
              _handleRegisterFailure(data, completer);
            } else if (status == 'timeout') {
              print('⏰ Timeout de polling');
              _pollingService.stopPolling();
              
              if (!completer.isCompleted) {
                _errorMessage = 'Tiempo de espera agotado. Intenta nuevamente.';
                _isLoading = false;
                _cleanup();
                notifyListeners();
                completer.complete(false);
              }
            }
          },
          interval: const Duration(seconds: 2),
          timeout: const Duration(seconds: 60),
        );
        
        return await completer.future;
      } else {
        _errorMessage = response.message ?? 'Error al registrar';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Error en registro: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      _cleanup();
      notifyListeners();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
  }

  void _handleRegisterSuccess(Map<String, dynamic> data, Completer<bool> completer) async {
    try {
      final result = data['result'];
      if (result != null) {
        // El registro puede o no devolver token inmediatamente
        if (result['token'] != null && result['user'] != null) {
          await _storageService.saveToken(result['token']);
          _apiService.setToken(result['token']);
          
          _currentUser = User.fromJson(result['user']);
          await _storageService.saveUserData(json.encode(result['user']));
          
          _isAuthenticated = true;
        }
        
        _isLoading = false;
        _cleanup();
        notifyListeners();
        
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    } catch (e) {
      _errorMessage = 'Error al procesar la respuesta';
      _isLoading = false;
      _cleanup();
      notifyListeners();
      
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
  }

  void _handleRegisterFailure(Map<String, dynamic> data, Completer<bool> completer) {
    final error = data['error'];
    _errorMessage = error?['message'] ?? 'Error al registrar';
    _isLoading = false;
    _cleanup();
    notifyListeners();
    
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    _cleanup();
    await _storageService.clearAll();
    _apiService.clearToken();
    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;

    _isLoading = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _cleanup();
    _pollingService.stopPolling();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
