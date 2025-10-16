import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import '../models/course.dart';
import '../models/enrollment.dart';

class CourseService {
  final _uuid = const Uuid();
  /// PASO 1: Obtiene las materias recomendadas para un estudiante
  /// Retorna un jobId para consultar el resultado mediante polling
  Future<EnrollmentResponse> getRecommendedCourses({
    required String studentId,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/students/recommended-courses?studentId=$studentId');
      print('🌐 GET $url');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return EnrollmentResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener materias recomendadas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getRecommendedCourses: $e');
      throw Exception('Error al obtener materias recomendadas: $e');
    }
  }

  /// PASO 3: Obtiene las secciones de una materia específica
  /// Retorna un jobId para consultar el resultado mediante polling
  Future<EnrollmentResponse> getCourseSections({
    required String courseId,
    String? token,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final url = Uri.parse(
        '${Constants.baseUrl}/course-sections?course_id=$courseId&status=Active&limit=$limit&page=$page'
      );
      print('🌐 GET $url');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return EnrollmentResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al obtener secciones');
      }
    } catch (e) {
      print('❌ Error en getCourseSections: $e');
      throw Exception('Error al obtener secciones: $e');
    }
  }

  /// PASO 5: Obtiene los enrollments del estudiante para encontrar el enrollment_id activo
  /// Retorna un jobId para consultar el resultado mediante polling
  Future<EnrollmentResponse> getEnrollments({
    required String studentId,
    String? token,
  }) async {
    try {
      final url = Uri.parse(
        '${Constants.baseUrl}/enrollments?student_id=$studentId&state=Active'
      );
      print('🌐 GET $url');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return EnrollmentResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener enrollments: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getEnrollments: $e');
      throw Exception('Error al obtener enrollments: $e');
    }
  }

  /// PASO 6: Inscribe las secciones seleccionadas en lote
  /// Este endpoint SÍ retorna jobId para consultar después
  Future<EnrollmentResponse> enrollBatch({
    required BatchEnrollmentRequest request,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/atomic-enrollment/enroll/batch');
      print('🌐 POST $url');
      print('📤 Request: ${json.encode(request.toJson())}');

      final idempotencyKey = _uuid.v4();

      final headers = {
        'Content-Type': 'application/json',
        'X-Idempotency-Key': idempotencyKey,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(request.toJson()),
      );

      print('📥 Response status: ${response.statusCode}');
      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        return EnrollmentResponse.fromJson(data);
      } else {
        throw Exception('Error al inscribir materias: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en enrollBatch: $e');
      throw Exception('Error al inscribir materias: $e');
    }
  }

  /// Parsea el resultado de la inscripción batch desde el polling
  BatchEnrollmentResponse parseBatchEnrollmentFromPollingResult(Map<String, dynamic> data) {
    try {
      print('📊 Parseando resultado de inscripción batch...');
      
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      Map<String, dynamic>? enrollmentData;
      
      if (result != null) {
        enrollmentData = result;
        print('✅ Datos de inscripción encontrados en result');
      } else if (returnValue != null) {
        enrollmentData = returnValue;
        print('✅ Datos de inscripción encontrados en returnvalue');
      }

      if (enrollmentData == null) {
        print('⚠️ No se encontraron datos de inscripción');
        return BatchEnrollmentResponse(
          success: false,
          message: 'No se encontraron datos de inscripción en la respuesta',
        );
      }

      final success = enrollmentData['success'] as bool? ?? false;
      final message = enrollmentData['message'] as String? ?? 'Sin mensaje';
      
      print('✅ Inscripción: success=$success, message=$message');
      
      // Extraer las secciones inscritas
      List<EnrolledSection>? enrolledSections;
      if (success && enrollmentData['data'] != null) {
        final dataMap = enrollmentData['data'] as Map<String, dynamic>;
        if (dataMap['enrollments'] != null) {
          final enrollments = dataMap['enrollments'] as List<dynamic>;
          enrolledSections = enrollments.map((e) {
            final detail = e['enrollmentDetail'] as Map<String, dynamic>;
            return EnrolledSection(
              courseSectionId: detail['course_section_id'] as String,
              courseName: '', // El backend no devuelve el nombre, se completará en el controller
              status: detail['course_state'] as String,
            );
          }).toList();
          print('✅ ${enrolledSections.length} secciones inscritas');
        }
      }

      return BatchEnrollmentResponse(
        success: success,
        message: message,
        enrolledSections: enrolledSections,
        errorCode: enrollmentData['errorCode'] as String?,
        details: enrollmentData['details'] as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      print('❌ Error al parsear resultado de inscripción: $e');
      print('📍 StackTrace: $stackTrace');
      return BatchEnrollmentResponse(
        success: false,
        message: 'Error al procesar resultado de inscripción: $e',
      );
    }
  }

  /// Parsea las materias recomendadas del resultado del polling
  List<RecommendedCourse> parseRecommendedCoursesFromPollingResult(Map<String, dynamic> data) {
    try {
      print('📊 Parseando materias recomendadas...');
      print('📦 Data completo: ${json.encode(data)}');
      
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      print('📦 Result: ${result != null ? "existe" : "null"}');
      print('📦 ReturnValue: ${returnValue != null ? "existe" : "null"}');
      
      List<dynamic>? coursesData;
      
      if (result != null && result['courses'] != null) {
        coursesData = result['courses'] as List<dynamic>;
        print('✅ Encontradas ${coursesData.length} materias en result.courses');
      } else if (returnValue != null && returnValue['courses'] != null) {
        coursesData = returnValue['courses'] as List<dynamic>;
        print('✅ Encontradas ${coursesData.length} materias en returnvalue.courses');
      }

      if (coursesData == null) {
        print('⚠️ No se encontraron materias en la respuesta');
        print('📦 Estructura de result: ${result?.keys.toList()}');
        print('📦 Estructura de returnValue: ${returnValue?.keys.toList()}');
        return [];
      }

      final courses = coursesData.map((json) {
        print('📝 Parseando materia: ${json['code']} - ${json['name']}');
        return RecommendedCourse.fromJson(json);
      }).toList();
      
      print('✅ Total de ${courses.length} materias parseadas correctamente');
      return courses;
    } catch (e, stackTrace) {
      print('❌ Error al parsear materias: $e');
      print('📍 StackTrace: $stackTrace');
      return [];
    }
  }

  /// Parsea las secciones del resultado del polling
  List<CourseSection> parseCourseSectionsFromPollingResult(Map<String, dynamic> data) {
    try {
      print('📊 Parseando secciones de materia...');
      
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      List<dynamic>? sectionsData;
      
      // Buscar en result.data o result.items
      if (result != null) {
        if (result['data'] != null) {
          sectionsData = result['data'] as List<dynamic>;
          print('✅ Encontradas ${sectionsData.length} secciones en result.data');
        } else if (result['items'] != null) {
          sectionsData = result['items'] as List<dynamic>;
          print('✅ Encontradas ${sectionsData.length} secciones en result.items');
        }
      }
      
      // Buscar en returnvalue.data o returnvalue.items
      if (sectionsData == null && returnValue != null) {
        if (returnValue['data'] != null) {
          sectionsData = returnValue['data'] as List<dynamic>;
          print('✅ Encontradas ${sectionsData.length} secciones en returnvalue.data');
        } else if (returnValue['items'] != null) {
          sectionsData = returnValue['items'] as List<dynamic>;
          print('✅ Encontradas ${sectionsData.length} secciones en returnvalue.items');
        }
      }

      if (sectionsData == null) {
        print('⚠️ No se encontraron secciones en la respuesta');
        print('📦 Estructura de result: ${result?.keys.toList()}');
        print('📦 Estructura de returnValue: ${returnValue?.keys.toList()}');
        return [];
      }

      final sections = sectionsData.map((json) {
        print('📝 Parseando sección: Grupo ${json['group_label']} - ${json['quota_available']}/${json['quota_max']} disponibles');
        return CourseSection.fromJson(json);
      }).toList();
      
      print('✅ Total de ${sections.length} secciones parseadas correctamente');
      return sections;
    } catch (e, stackTrace) {
      print('❌ Error al parsear secciones: $e');
      print('📍 StackTrace: $stackTrace');
      return [];
    }
  }

  /// Extrae el enrollment_id del estudiante desde el resultado del polling
  String? findStudentEnrollmentId(Map<String, dynamic> data, String studentId) {
    try {
      print('📊 Buscando enrollment_id para estudiante: $studentId');
      
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      List<dynamic>? enrollmentsData;
      
      // Buscar en result.data o result.items
      if (result != null) {
        if (result['data'] != null) {
          enrollmentsData = result['data'] as List<dynamic>;
          print('✅ Encontrados ${enrollmentsData.length} enrollments en result.data');
        } else if (result['items'] != null) {
          enrollmentsData = result['items'] as List<dynamic>;
          print('✅ Encontrados ${enrollmentsData.length} enrollments en result.items');
        }
      }
      
      // Buscar en returnvalue.data o returnvalue.items
      if (enrollmentsData == null && returnValue != null) {
        if (returnValue['data'] != null) {
          enrollmentsData = returnValue['data'] as List<dynamic>;
          print('✅ Encontrados ${enrollmentsData.length} enrollments en returnvalue.data');
        } else if (returnValue['items'] != null) {
          enrollmentsData = returnValue['items'] as List<dynamic>;
          print('✅ Encontrados ${enrollmentsData.length} enrollments en returnvalue.items');
        }
      }

      if (enrollmentsData == null || enrollmentsData.isEmpty) {
        print('⚠️ No se encontraron enrollments en la respuesta');
        print('📦 Estructura de result: ${result?.keys.toList()}');
        print('📦 Estructura de returnValue: ${returnValue?.keys.toList()}');
        return null;
      }

      // Buscar el enrollment del estudiante con estado Active
      // El backend usa snake_case: student_id y state
      for (var enrollment in enrollmentsData) {
        final enrollmentStudentId = enrollment['student_id'] as String?;
        final enrollmentState = enrollment['state'] as String?;
        
        print('📝 Verificando enrollment: id=${enrollment['id']}, student_id=$enrollmentStudentId, state=$enrollmentState');
        
        if (enrollmentStudentId == studentId && enrollmentState == 'Active') {
          final enrollmentId = enrollment['id'] as String;
          print('✅ Enrollment activo encontrado: $enrollmentId');
          return enrollmentId;
        }
      }

      print('⚠️ No se encontró enrollment activo para estudiante: $studentId');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error al buscar enrollment: $e');
      print('📍 StackTrace: $stackTrace');
      return null;
    }
  }
}
