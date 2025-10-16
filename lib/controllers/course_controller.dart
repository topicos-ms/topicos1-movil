import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/job_polling_service.dart';
import '../services/storage_service.dart';

enum CourseLoadingState {
  idle,
  loadingCourses,
  loadingEnrollmentId,
  enrolling,
  completed,
  error,
}

class CourseController extends ChangeNotifier {
  final CourseService _courseService = CourseService();
  final JobPollingService _pollingService = JobPollingService();
  final StorageService _storageService = StorageService();

  // Estado
  CourseLoadingState _state = CourseLoadingState.idle;
  List<RecommendedCourse> _courses = [];
  String? _enrollmentId;
  String? _errorMessage;
  String? _successMessage;
  
  // Progreso de inscripción
  int _enrollmentProgress = 0;
  int _totalToEnroll = 0;
  String? _currentlyEnrollingCourse;

  // Getters
  CourseLoadingState get state => _state;
  List<RecommendedCourse> get courses => _courses;
  String? get enrollmentId => _enrollmentId;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isLoading => _state == CourseLoadingState.loadingCourses ||
                       _state == CourseLoadingState.loadingEnrollmentId ||
                       _state == CourseLoadingState.enrolling;
  int get enrollmentProgress => _enrollmentProgress;
  int get totalToEnroll => _totalToEnroll;
  String? get currentlyEnrollingCourse => _currentlyEnrollingCourse;
  
  List<RecommendedCourse> get selectedCourses => 
      _courses.where((course) => course.isSelected).toList();

  /// Carga las materias recomendadas para un estudiante
  Future<void> loadRecommendedCourses(String studentId) async {
    _state = CourseLoadingState.loadingCourses;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      print('📚 Cargando materias recomendadas para estudiante: $studentId');

      final response = await _courseService.getRecommendedCourses(
        studentId: studentId,
        token: token,
      );

      if (response.jobId != null) {
        print('✅ JobId recibido: "${response.jobId}"');
        final completer = Completer<void>();

        _pollingService.startPolling(
          jobId: response.jobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido para materias recomendadas');
            final status = data['status'] as String?;
            
            if (status == 'completed') {
              print('✅ Materias obtenidas exitosamente');
              final courses = _courseService.parseRecommendedCoursesFromPollingResult(data);
              _courses = courses;
              _successMessage = '${courses.length} materias recomendadas cargadas';
              _state = CourseLoadingState.idle;
              notifyListeners();
              completer.complete();
            } else if (status == 'failed') {
              print('❌ Error al obtener materias');
              _errorMessage = 'Error al cargar materias recomendadas';
              _state = CourseLoadingState.error;
              notifyListeners();
              completer.completeError(Exception(_errorMessage));
            } else if (status == 'timeout') {
              print('⏱️ Timeout al cargar materias');
              _errorMessage = 'Tiempo de espera agotado al cargar materias';
              _state = CourseLoadingState.error;
              notifyListeners();
              completer.completeError(TimeoutException('Timeout'));
            }
          },
        );

        await completer.future;
      } else {
        throw Exception('No se recibió jobId');
      }
    } catch (e) {
      print('❌ Error en loadRecommendedCourses: $e');
      _errorMessage = 'Error al cargar materias: $e';
      _state = CourseLoadingState.error;
      notifyListeners();
    }
  }

  /// Carga el enrollment_id del estudiante desde la lista de enrollments
  Future<void> loadEnrollmentId(String studentId) async {
    _state = CourseLoadingState.loadingEnrollmentId;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      print('🔍 Buscando enrollment_id para estudiante: $studentId');

      final response = await _courseService.getEnrollments(token: token);

      if (response.jobId != null) {
        print('✅ JobId recibido: "${response.jobId}"');
        final completer = Completer<void>();

        _pollingService.startPolling(
          jobId: response.jobId!,
          onUpdate: (data) {
            print('📨 Polling update recibido para enrollments');
            final status = data['status'] as String?;
            
            if (status == 'completed') {
              print('✅ Enrollments obtenidos exitosamente');
              final enrollmentId = _courseService.findStudentEnrollmentId(data, studentId);
              
              if (enrollmentId != null) {
                _enrollmentId = enrollmentId;
                _state = CourseLoadingState.idle;
                print('✅ Enrollment ID guardado: $_enrollmentId');
              } else {
                _errorMessage = 'No se encontró una matrícula activa para el estudiante';
                _state = CourseLoadingState.error;
              }
              
              notifyListeners();
              completer.complete();
            } else if (status == 'failed') {
              print('❌ Error al obtener enrollments');
              _errorMessage = 'Error al buscar matrícula del estudiante';
              _state = CourseLoadingState.error;
              notifyListeners();
              completer.completeError(Exception(_errorMessage));
            } else if (status == 'timeout') {
              print('⏱️ Timeout al buscar enrollment');
              _errorMessage = 'Tiempo de espera agotado al buscar matrícula';
              _state = CourseLoadingState.error;
              notifyListeners();
              completer.completeError(TimeoutException('Timeout'));
            }
          },
        );

        await completer.future;
      } else {
        throw Exception('No se recibió jobId');
      }
    } catch (e) {
      print('❌ Error en loadEnrollmentId: $e');
      _errorMessage = 'Error al buscar matrícula: $e';
      _state = CourseLoadingState.error;
      notifyListeners();
    }
  }

  /// Inscribe las materias seleccionadas una por una
  Future<void> enrollSelectedCourses() async {
    if (_enrollmentId == null) {
      _errorMessage = 'No se encontró el ID de matrícula';
      _state = CourseLoadingState.error;
      notifyListeners();
      return;
    }

    final selected = selectedCourses;
    if (selected.isEmpty) {
      _errorMessage = 'No hay materias seleccionadas';
      _state = CourseLoadingState.error;
      notifyListeners();
      return;
    }

    _state = CourseLoadingState.enrolling;
    _enrollmentProgress = 0;
    _totalToEnroll = selected.length;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final enrolledCourses = <String>[];
    final failedCourses = <String>[];

    try {
      final token = await _storageService.getToken();

      for (int i = 0; i < selected.length; i++) {
        final course = selected[i];
        _currentlyEnrollingCourse = '${course.code} - ${course.name}';
        _enrollmentProgress = i + 1;
        notifyListeners();

        print('📝 Inscribiendo materia ${i + 1} de ${selected.length}: ${course.code}');

        try {
          await _enrollSingleCourse(course, token);
          enrolledCourses.add(course.code);
          print('✅ Materia inscrita: ${course.code}');
        } catch (e) {
          print('❌ Error al inscribir materia ${course.code}: $e');
          failedCourses.add(course.code);
        }

        // Pequeña pausa entre inscripciones
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Resultado final
      if (failedCourses.isEmpty) {
        _successMessage = '✅ ${enrolledCourses.length} materias inscritas exitosamente';
        _state = CourseLoadingState.completed;
      } else if (enrolledCourses.isEmpty) {
        _errorMessage = '❌ No se pudo inscribir ninguna materia';
        _state = CourseLoadingState.error;
      } else {
        _successMessage = '⚠️ ${enrolledCourses.length} inscritas, ${failedCourses.length} fallaron';
        _state = CourseLoadingState.completed;
      }

      _currentlyEnrollingCourse = null;
      notifyListeners();

    } catch (e) {
      print('❌ Error general al inscribir materias: $e');
      _errorMessage = 'Error al inscribir materias: $e';
      _state = CourseLoadingState.error;
      _currentlyEnrollingCourse = null;
      notifyListeners();
    }
  }

  /// Inscribe una sola materia (privado)
  Future<void> _enrollSingleCourse(RecommendedCourse course, String? token) async {
    final request = CourseEnrollmentRequest(
      enrollmentId: _enrollmentId!,
      courseSectionId: course.courseId,
    );

    final response = await _courseService.enrollCourse(
      request: request,
      token: token,
    );

    if (response.jobId != null) {
      final completer = Completer<void>();

      _pollingService.startPolling(
        jobId: response.jobId!,
        onUpdate: (data) {
          final status = data['status'] as String?;
          
          if (status == 'completed') {
            print('✅ Inscripción completada para: ${course.code}');
            completer.complete();
          } else if (status == 'failed') {
            final errorMsg = data['error'] ?? 'Error desconocido';
            print('❌ Error en inscripción: $errorMsg');
            completer.completeError(Exception(errorMsg));
          } else if (status == 'timeout') {
            print('⏱️ Timeout al inscribir materia');
            completer.completeError(TimeoutException('Timeout'));
          }
        },
      );

      await completer.future;
    } else {
      throw Exception('No se recibió jobId para la inscripción');
    }
  }

  /// Alterna la selección de una materia
  void toggleCourseSelection(int index) {
    if (index >= 0 && index < _courses.length) {
      _courses[index].isSelected = !_courses[index].isSelected;
      notifyListeners();
    }
  }

  /// Limpia el estado del controlador
  void clearState() {
    _state = CourseLoadingState.idle;
    _courses = [];
    _enrollmentId = null;
    _errorMessage = null;
    _successMessage = null;
    _enrollmentProgress = 0;
    _totalToEnroll = 0;
    _currentlyEnrollingCourse = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingService.stopPolling();
    super.dispose();
  }
}
