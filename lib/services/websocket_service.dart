import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  void connect() {
    if (_socket != null && _isConnected) {
      print('⚠️ WebSocket ya está conectado');
      return;
    }

    // Usar la base URL directamente (ya no incluye /api)
    final baseUrl = Constants.baseUrl;
    print('🔌 Conectando a WebSocket: $baseUrl');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket?.onConnect((_) {
      _isConnected = true;
      print('✅ WebSocket conectado exitosamente');
    });

    _socket?.onDisconnect((_) {
      _isConnected = false;
      print('❌ WebSocket desconectado');
    });

    _socket?.onConnectError((error) {
      _isConnected = false;
      print('❌ Error de conexión WebSocket: $error');
    });

    _socket?.onError((error) {
      print('❌ Error WebSocket: $error');
    });

    // Escuchar TODOS los eventos para debugging
    _socket?.onAny((event, data) {
      print('🔔 Evento WebSocket recibido: $event');
      print('   Datos: $data');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void subscribeToJob(String jobId) {
    if (_socket != null && _isConnected) {
      print('📡 Enviando suscripción al job: $jobId');
      _socket!.emit('subscribe-job', jobId);
      print('✅ Emit subscribe-job enviado');
    } else {
      print('❌ No se puede suscribir - Socket: ${_socket != null}, Conectado: $_isConnected');
    }
  }

  void unsubscribeFromJob(String jobId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('unsubscribe-job', jobId);
      print('📡 Desuscrito del job: $jobId');
    }
  }

  void onJobUpdate(Function(Map<String, dynamic>) callback) {
    _socket?.on('job-update', (data) {
      print('📨 Job update recibido: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onSubscriptionConfirmed(Function(dynamic) callback) {
    _socket?.on('subscription-confirmed', callback);
  }

  void onError(Function(dynamic) callback) {
    _socket?.on('error', callback);
  }

  void removeAllListeners() {
    _socket?.off('job-update');
    _socket?.off('subscription-confirmed');
    _socket?.off('error');
  }
}
