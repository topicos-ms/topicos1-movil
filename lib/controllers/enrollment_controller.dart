import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/period.dart';
import '../models/enrollment.dart';
import '../services/enrollment_service.dart';
import '../services/job_polling_service.dart';
import '../services/storage_service.dart';

class EnrollmentController extends ChangeNotifier {
  final EnrollmentService _enrollmentService = EnrollmentService();
  final JobPollingService _pollingService = JobPollingService();
  final StorageService _storageService = StorageService();

  List<Period> _periods = [];
  Period? _selectedPeriod;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _currentJobId;

  List<Period> get periods => _periods;
  Period? get selectedPeriod => _selectedPeriod;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get hasPeriods => _periods.isNotEmpty;

  void setSelectedPeriod(Period? period) {
    _selectedPeriod = period;
    notifyListeners();
  }

  /// Carga los períodos académicos disponibles
  Future<void> loadPeriods() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final completer = Completer<void>();

    try {
      print('🔄 Cargando períodos académicos...');
      
      // Obtener token del storage
      final token = await _storageService.getToken();
      
      // Hacer petición para obtener jobId
      final response = await _enrollmentService.getPeriods(token: token);

      if (response.jobId != null) {
        _currentJobId = response.jobId!.trim();
        print('✅ JobId recibido: "$_currentJobId"');
        
        // Iniciar polling para obtener los períodos
        _pollingService.startPolling(
          jobId: _currentJobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido para períodos');
            
            final status = data['status'];
            
            if (status == 'completed') {
              print('✅ Períodos obtenidos exitosamente');
              _pollingService.stopPolling();
              
              // Parsear los períodos del resultado
              _periods = _enrollmentService.parsePeriodsFromPollingResult(data);
              
              print('📋 ${_periods.length} períodos encontrados');
              
              // Seleccionar automáticamente el primer período activo
              if (_periods.isNotEmpty) {
                _selectedPeriod = _periods.firstWhere(
                  (p) => p.isActive,
                  orElse: () => _periods.first,
                );
              }
              
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete();
              }
            } else if (status == 'failed') {
              print('❌ Error al obtener períodos');
              _pollingService.stopPolling();
              _errorMessage = 'Error al cargar períodos';
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete();
              }
            } else if (status == 'timeout') {
              print('⏰ Timeout al obtener períodos');
              _pollingService.stopPolling();
              _errorMessage = 'Tiempo de espera agotado';
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          },
          interval: const Duration(seconds: 2),
          timeout: const Duration(seconds: 60),
        );
        
        await completer.future;
      } else {
        _errorMessage = 'Error al iniciar carga de períodos';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error en loadPeriods: $e');
      _errorMessage = 'Error al cargar períodos';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza la matrícula del estudiante en el período seleccionado
  Future<bool> enrollStudent(String studentId) async {
    if (_selectedPeriod == null) {
      _errorMessage = 'Debe seleccionar un período';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final completer = Completer<bool>();

    try {
      print('🔄 Iniciando matrícula...');
      print('   Estudiante: $studentId');
      print('   Período: ${_selectedPeriod!.name}');
      
      // Obtener token del storage
      final token = await _storageService.getToken();
      
      // Crear objeto de matrícula
      final enrollment = Enrollment(
        studentId: studentId,
        termId: _selectedPeriod!.id,
        enrolledOn: DateTime.now().toIso8601String().split('T')[0], // Formato YYYY-MM-DD
        origin: 'Regular',
        note: 'Inscripción regular - ${_selectedPeriod!.name}',
      );

      // Hacer petición para obtener jobId
      final response = await _enrollmentService.createEnrollment(
        enrollment: enrollment,
        token: token,
      );

      if (response.jobId != null) {
        _currentJobId = response.jobId!.trim();
        print('✅ JobId de matrícula recibido: "$_currentJobId"');
        
        // Iniciar polling para confirmar la matrícula
        _pollingService.startPolling(
          jobId: _currentJobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido para matrícula');
            
            final status = data['status'];
            
            if (status == 'completed') {
              print('✅ Matrícula completada exitosamente');
              _pollingService.stopPolling();
              
              _successMessage = 'Matriculado exitosamente en ${_selectedPeriod!.name}';
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } else if (status == 'failed') {
              print('❌ Error en la matrícula');
              _pollingService.stopPolling();
              
              final error = data['error'];
              _errorMessage = error?['message'] ?? 'Error al matricularse';
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            } else if (status == 'timeout') {
              print('⏰ Timeout en la matrícula');
              _pollingService.stopPolling();
              _errorMessage = 'Tiempo de espera agotado';
              _isLoading = false;
              _currentJobId = null;
              notifyListeners();
              
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
          },
          interval: const Duration(seconds: 2),
          timeout: const Duration(seconds: 90),
        );
        
        return await completer.future;
      } else {
        _errorMessage = 'Error al iniciar matrícula';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Error en enrollStudent: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingService.stopPolling();
    super.dispose();
  }
}
