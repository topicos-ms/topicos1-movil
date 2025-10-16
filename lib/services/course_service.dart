import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import '../models/course.dart';
import '../models/enrollment.dart';

class CourseService {
  final _uuid = const Uuid();

  /// Obtiene las materias recomendadas para un estudiante
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

  /// Obtiene todos los enrollments (matrículas) del sistema
  Future<EnrollmentResponse> getEnrollments({String? token}) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/enrollments');
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

  /// Inscribe una materia (curso) usando atomic enrollment
  Future<EnrollmentResponse> enrollCourse({
    required CourseEnrollmentRequest request,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/atomic-enrollment/enroll');
      final idempotencyKey = _uuid.v4();
      
      print('🌐 POST $url');
      print('🔑 Idempotency-Key: $idempotencyKey');
      print('📤 Body: ${json.encode(request.toJson())}');

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

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return EnrollmentResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al inscribir materia');
      }
    } catch (e) {
      print('❌ Error en enrollCourse: $e');
      throw Exception('Error al inscribir materia: $e');
    }
  }

  /// Parsea las materias recomendadas del resultado del polling
  List<RecommendedCourse> parseRecommendedCoursesFromPollingResult(Map<String, dynamic> data) {
    try {
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      List<dynamic>? coursesData;
      
      if (result != null && result['courses'] != null) {
        coursesData = result['courses'] as List<dynamic>;
      } else if (returnValue != null && returnValue['courses'] != null) {
        coursesData = returnValue['courses'] as List<dynamic>;
      }

      if (coursesData == null) {
        print('⚠️ No se encontraron materias en la respuesta');
        return [];
      }

      return coursesData.map((json) => RecommendedCourse.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al parsear materias: $e');
      return [];
    }
  }

  /// Extrae el enrollment_id del estudiante desde el resultado del polling de enrollments
  String? findStudentEnrollmentId(Map<String, dynamic> data, String studentId) {
    try {
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      List<dynamic>? enrollmentsData;
      
      if (result != null && result['data'] != null) {
        enrollmentsData = result['data'] as List<dynamic>;
      } else if (returnValue != null && returnValue['data'] != null) {
        enrollmentsData = returnValue['data'] as List<dynamic>;
      }

      if (enrollmentsData == null) {
        print('⚠️ No se encontraron enrollments en la respuesta');
        return null;
      }

      // Buscar el enrollment del estudiante con estado Active
      for (var enrollment in enrollmentsData) {
        if (enrollment['student_id'] == studentId && 
            enrollment['state'] == 'Active') {
          final enrollmentId = enrollment['id'] as String;
          print('✅ Enrollment encontrado: $enrollmentId');
          return enrollmentId;
        }
      }

      print('⚠️ No se encontró enrollment activo para estudiante: $studentId');
      return null;
    } catch (e) {
      print('❌ Error al buscar enrollment: $e');
      return null;
    }
  }
}
