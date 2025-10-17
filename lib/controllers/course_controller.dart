import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/job_polling_service.dart';
import '../services/storage_service.dart';

enum CourseLoadingState {
  idle,
  loadingCourses,
  loadingSections,
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
  Map<String, List<CourseSection>> _sectionsByCourse = {}; // courseId -> secciones
  String? _enrollmentId;
  String? _errorMessage;
  String? _successMessage;
  BatchEnrollmentResponse? _enrollmentResult;
  
  // Progreso de carga de secciones
  int _sectionsLoadProgress = 0;
  int _totalCoursesToLoadSections = 0;
  String? _currentlyLoadingCourse;

  // Getters
  CourseLoadingState get state => _state;
  List<RecommendedCourse> get courses => _courses;
  Map<String, List<CourseSection>> get sectionsByCourse => _sectionsByCourse;
  String? get enrollmentId => _enrollmentId;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  BatchEnrollmentResponse? get enrollmentResult => _enrollmentResult;
  bool get isLoading => _state == CourseLoadingState.loadingCourses ||
                       _state == CourseLoadingState.loadingSections ||
                       _state == CourseLoadingState.loadingEnrollmentId ||
                       _state == CourseLoadingState.enrolling;
  int get sectionsLoadProgress => _sectionsLoadProgress;
  int get totalCoursesToLoadSections => _totalCoursesToLoadSections;
  String? get currentlyLoadingCourse => _currentlyLoadingCourse;
  
  List<RecommendedCourse> get selectedCourses => 
      _courses.where((course) => course.isSelected).toList();
  
  bool get canProceedToSectionSelection => 
      selectedCourses.isNotEmpty && selectedCourses.every((c) => c.isPrerequisitesMet);
  
  bool get canProceedToEnrollment =>
      selectedCourses.any((c) => c.selectedSectionId != null);

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

  /// PASO 3 y 4: Carga las secciones para las materias seleccionadas
  Future<void> loadSectionsForSelectedCourses() async {
    final selected = selectedCourses;
    if (selected.isEmpty) {
      _errorMessage = 'No hay materias seleccionadas';
      _state = CourseLoadingState.error;
      notifyListeners();
      return;
    }

    _state = CourseLoadingState.loadingSections;
    _sectionsLoadProgress = 0;
    _totalCoursesToLoadSections = selected.length;
    _errorMessage = null;
    _sectionsByCourse.clear();
    notifyListeners();

    try {
      final token = await _storageService.getToken();

      for (int i = 0; i < selected.length; i++) {
        final course = selected[i];
        _currentlyLoadingCourse = '${course.code} - ${course.name}';
        _sectionsLoadProgress = i;
        notifyListeners();

        print('📚 Cargando secciones para materia ${i + 1} de ${selected.length}: ${course.code}');

        try {
          final sections = await _loadSectionsForCourse(course.courseId, token);
          _sectionsByCourse[course.courseId] = sections;
          print('✅ ${sections.length} secciones cargadas para ${course.code}');
        } catch (e) {
          print('❌ Error al cargar secciones para ${course.code}: $e');
          _sectionsByCourse[course.courseId] = [];
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      _sectionsLoadProgress = selected.length;
      _currentlyLoadingCourse = null;
      _successMessage = 'Secciones cargadas para ${selected.length} materias';
      _state = CourseLoadingState.idle;
      notifyListeners();

    } catch (e) {
      print('❌ Error general al cargar secciones: $e');
      _errorMessage = 'Error al cargar secciones: $e';
      _state = CourseLoadingState.error;
      _currentlyLoadingCourse = null;
      notifyListeners();
    }
  }

  /// Carga las secciones de una materia específica (privado)
  Future<List<CourseSection>> _loadSectionsForCourse(String courseId, String? token) async {
    final response = await _courseService.getCourseSections(
      courseId: courseId,
      token: token,
    );

    if (response.jobId != null) {
      final completer = Completer<List<CourseSection>>();

      _pollingService.startPolling(
        jobId: response.jobId!,
        onUpdate: (data) {
          final status = data['status'] as String?;
          
          if (status == 'completed') {
            final sections = _courseService.parseCourseSectionsFromPollingResult(data);
            completer.complete(sections);
          } else if (status == 'failed') {
            completer.completeError(Exception('Error al obtener secciones'));
          } else if (status == 'timeout') {
            completer.completeError(TimeoutException('Timeout'));
          }
        },
      );

      return await completer.future;
    } else {
      throw Exception('No se recibió jobId');
    }
  }

  /// PASO 5: Carga el enrollment_id del estudiante desde la lista de enrollments
  Future<void> loadEnrollmentId(String studentId) async {
    // Intentar reutilizar el enrollment_id almacenado previamente
    if (_enrollmentId != null) {
      return;
    }

    final cachedEnrollmentId =
        await _storageService.getEnrollmentId(studentId);
    if (cachedEnrollmentId != null && cachedEnrollmentId.isNotEmpty) {
      _enrollmentId = cachedEnrollmentId;
      _state = CourseLoadingState.idle;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _state = CourseLoadingState.loadingEnrollmentId;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      print('🔍 Buscando enrollment_id para estudiante: $studentId');

      final response = await _courseService.getEnrollments(
        studentId: studentId,
        token: token,
      );

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
                _storageService.saveEnrollmentId(
                  studentId: studentId,
                  enrollmentId: enrollmentId,
                );
                _state = CourseLoadingState.idle;
                print('✅ Enrollment ID guardado: $_enrollmentId');
              } else {
                _storageService.deleteEnrollmentId(studentId);
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

  // JobId de la inscripción batch para consultar después
  String? _batchEnrollmentJobId;
  String? get batchEnrollmentJobId => _batchEnrollmentJobId;

  /// PASO 6: Inscribe las materias seleccionadas en lote
  /// Retorna el jobId para consultar manualmente
  Future<String?> enrollSelectedCourses() async {
    if (_enrollmentId == null) {
      _errorMessage = 'No se encontró el ID de matrícula';
      _state = CourseLoadingState.error;
      notifyListeners();
      return null;
    }

    final selected = selectedCourses;
    if (selected.isEmpty) {
      _errorMessage = 'No hay materias seleccionadas';
      _state = CourseLoadingState.error;
      notifyListeners();
      return null;
    }

    // Tomar solo las materias con grupo seleccionado
    final coursesWithSection =
        selected.where((c) => c.selectedSectionId != null).toList();
    if (coursesWithSection.isEmpty) {
      _errorMessage = 'Debes seleccionar al menos un grupo';
      _state = CourseLoadingState.error;
      notifyListeners();
      return null;
    }

    _state = CourseLoadingState.enrolling;
    _errorMessage = null;
    _successMessage = null;
    _enrollmentResult = null;
    notifyListeners();

    try {
      final token = await _storageService.getToken();

      // Construir la solicitud de inscripción en lote
      final items = coursesWithSection
          .map((course) => EnrollmentItem(
                enrollmentId: _enrollmentId!,
                courseSectionId: course.selectedSectionId!,
              ))
          .toList();

      final request = BatchEnrollmentRequest(items: items);

      print('📝 Inscribiendo ${items.length} materias en lote...');

      // Llamar al endpoint de batch enrollment (retorna jobId)
      final response = await _courseService.enrollBatch(
        request: request,
        token: token,
      );

      if (response.jobId != null) {
        _batchEnrollmentJobId = response.jobId;
        _state = CourseLoadingState.idle;
        print('✅ JobId de inscripción recibido: ${response.jobId}');
        notifyListeners();
        return response.jobId;
      } else {
        throw Exception('No se recibió jobId para la inscripción');
      }

    } catch (e) {
      print('❌ Error general al inscribir materias: $e');
      _errorMessage = 'Error al inscribir materias: $e';
      _state = CourseLoadingState.error;
      notifyListeners();
      return null;
    }
  }

  /// Consulta el resultado de la inscripción batch usando el jobId
  /// Retorna el estado del job según lo provea la cola.
  Future<String?> checkEnrollmentResult(String jobId) async {
    _state = CourseLoadingState.enrolling;
    _errorMessage = null;
    _successMessage = null;
    _enrollmentResult = null;
    notifyListeners();

    try {
      print('[Enrollment] Consultando resultado para job $jobId');
      final data = await _pollingService.fetchJobStatus(jobId);
      final rawStatus = data['status'] as String?;
      final status = rawStatus?.toLowerCase();

      print('[Enrollment] Estado recibido: $status');

      if (status == null) {
        _errorMessage = (data['error'] as String?) ??
            'No se pudo determinar el estado de la inscripción';
        _state = CourseLoadingState.error;
      } else if (status == 'completed') {
        final result = _courseService.parseBatchEnrollmentFromPollingResult(data);
        _enrollmentResult = result;

        if (result.success) {
          final count = result.enrolledSections?.length ??
              selectedCourses.where((c) => c.selectedSectionId != null).length;
          _successMessage = '✅ $count materias inscritas exitosamente';
          _state = CourseLoadingState.completed;
        } else {
          _errorMessage = result.message;
          _state = CourseLoadingState.error;
        }
      } else if (status == 'failed' || status == 'error' || status == 'stalled') {
        final result = _courseService.parseBatchEnrollmentFromPollingResult(data);
        _enrollmentResult = result;
        _errorMessage = result.message.isNotEmpty
            ? result.message
            : (data['error'] as String?) ?? 'Error al procesar la inscripción';
        _state = CourseLoadingState.error;
      } else if (status == 'timeout') {
        _errorMessage = 'Tiempo de espera agotado';
        _state = CourseLoadingState.error;
      } else {
        // Estados intermedios (delayed, waiting, active, prioritized, etc.)
        _state = CourseLoadingState.idle;
      }

      notifyListeners();
      return status;
    } catch (e) {
      print('[Enrollment] Error al consultar resultado: $e');
      _errorMessage = 'Error al consultar resultado: $e';
      _state = CourseLoadingState.error;
      notifyListeners();
      return null;
    }
  }

  /// PASO 2: Alterna la selección de una materia
  void toggleCourseSelection(int index) {
    if (index >= 0 && index < _courses.length) {
      _courses[index].isSelected = !_courses[index].isSelected;
      notifyListeners();
    }
  }

  /// PASO 4: Selecciona una sección para una materia
  void selectSectionForCourse(String courseId, String sectionId) {
    final courseIndex = _courses.indexWhere((c) => c.courseId == courseId);
    if (courseIndex != -1) {
      _courses[courseIndex].selectedSectionId = sectionId;
      print('✅ Sección $sectionId seleccionada para curso $courseId');
      notifyListeners();
    }
  }

  /// Obtiene las secciones disponibles para una materia
  List<CourseSection> getSectionsForCourse(String courseId) {
    return _sectionsByCourse[courseId] ?? [];
  }

  /// Limpia el estado del controlador
  void clearState() {
    _state = CourseLoadingState.idle;
    _courses = [];
    _sectionsByCourse.clear();
    _enrollmentId = null;
    _errorMessage = null;
    _successMessage = null;
    _enrollmentResult = null;
    _batchEnrollmentJobId = null;
    _sectionsLoadProgress = 0;
    _totalCoursesToLoadSections = 0;
    _currentlyLoadingCourse = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingService.stopPolling();
    super.dispose();
  }
}
