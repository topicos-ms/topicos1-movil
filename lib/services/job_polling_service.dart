import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class JobPollingService {
  static final JobPollingService _instance = JobPollingService._internal();
  factory JobPollingService() => _instance;
  JobPollingService._internal();

  Timer? _pollingTimer;
  
  /// Consulta el estado de un job mediante HTTP polling
  /// 
  /// Parámetros:
  /// - jobId: ID del job a consultar
  /// - onUpdate: Callback que se ejecuta en cada actualización
  /// - interval: Intervalo entre consultas (default: 2 segundos)
  /// - timeout: Tiempo máximo de polling (default: 60 segundos)
  Future<void> startPolling({
    required String jobId,
    required Function(Map<String, dynamic>) onUpdate,
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 60),
  }) async {
    print('🔄 Iniciando polling HTTP para job: $jobId');
    
    final startTime = DateTime.now();
    int attempts = 0;
    
    _pollingTimer?.cancel(); // Cancelar cualquier polling anterior
    
    _pollingTimer = Timer.periodic(interval, (timer) async {
      attempts++;
      final elapsed = DateTime.now().difference(startTime);
      
      print('📊 Polling intento #$attempts (${elapsed.inSeconds}s transcurridos)');
      
      // Verificar timeout
      if (elapsed >= timeout) {
        print('⏰ Timeout de polling alcanzado');
        timer.cancel();
        onUpdate({
          'jobId': jobId,
          'status': 'timeout',
          'error': 'Tiempo de espera agotado'
        });
        return;
      }
      
      try {
        // Hacer petición GET al endpoint de estado del job
        final url = Uri.parse('${Constants.baseUrl}/queues/job/$jobId/status');
        print('🌐 GET $url');
        
        final response = await http.get(
          url,
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        print('📥 Respuesta recibida: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Job status: ${data['status']}');
          
          // Notificar actualización
          onUpdate(data);
          
          // Si el job terminó (completed o failed), detener polling
          final status = data['status'];
          if (status == 'completed' || status == 'failed') {
            print('✅ Job finalizado con status: $status - deteniendo polling');
            timer.cancel();
          }
        } else if (response.statusCode == 404) {
          print('❌ Job no encontrado (404)');
          timer.cancel();
          onUpdate({
            'jobId': jobId,
            'status': 'failed',
            'error': 'Job no encontrado'
          });
        } else {
          print('⚠️ Error en polling: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error en petición de polling: $e');
        // No cancelamos el timer aquí, seguimos intentando
      }
    });
  }
  
  /// Detiene el polling actual
  void stopPolling() {
    print('🛑 Deteniendo polling HTTP');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  /// Verifica si hay un polling activo
  bool get isPolling => _pollingTimer?.isActive ?? false;
}
