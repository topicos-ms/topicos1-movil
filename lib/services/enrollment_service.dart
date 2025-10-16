import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/period.dart';
import '../models/enrollment.dart';

class EnrollmentService {
  /// Obtiene la lista de períodos académicos disponibles
  /// Retorna un jobId para consultar el resultado mediante polling
  Future<EnrollmentResponse> getPeriods({String? token}) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/calendar/periods');
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
        throw Exception('Error al obtener períodos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getPeriods: $e');
      throw Exception('Error al obtener períodos: $e');
    }
  }

  /// Crea una nueva matrícula
  /// Retorna un jobId para consultar el resultado mediante polling
  Future<EnrollmentResponse> createEnrollment({
    required Enrollment enrollment,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${Constants.baseUrl}/enrollments');
      print('🌐 POST $url');
      print('📤 Body: ${json.encode(enrollment.toJson())}');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(enrollment.toJson()),
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return EnrollmentResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear matrícula');
      }
    } catch (e) {
      print('❌ Error en createEnrollment: $e');
      throw Exception('Error al crear matrícula: $e');
    }
  }

  /// Parsea la respuesta del polling para obtener los períodos
  List<Period> parsePeriodsFromPollingResult(Map<String, dynamic> data) {
    try {
      // Los datos pueden estar en result.data o en returnvalue.data
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      List<dynamic>? periodsData;
      
      if (result != null && result['data'] != null) {
        periodsData = result['data'] as List<dynamic>;
      } else if (returnValue != null && returnValue['data'] != null) {
        periodsData = returnValue['data'] as List<dynamic>;
      }

      if (periodsData == null) {
        print('⚠️ No se encontraron períodos en la respuesta');
        return [];
      }

      return periodsData.map((json) => Period.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al parsear períodos: $e');
      return [];
    }
  }

  /// Parsea la información de paginación
  PaginationInfo? parsePaginationFromPollingResult(Map<String, dynamic> data) {
    try {
      final result = data['result'];
      final returnValue = data['returnvalue'];
      
      Map<String, dynamic>? paginationData;
      
      if (result != null && result['pagination'] != null) {
        paginationData = result['pagination'] as Map<String, dynamic>;
      } else if (returnValue != null && returnValue['pagination'] != null) {
        paginationData = returnValue['pagination'] as Map<String, dynamic>;
      }

      if (paginationData == null) {
        return null;
      }

      return PaginationInfo.fromJson(paginationData);
    } catch (e) {
      print('❌ Error al parsear paginación: $e');
      return null;
    }
  }
}
