import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'backend_config.dart';

class StreamingService {
  StreamingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _frameController = StreamController<Uint8List>.broadcast();
  io.Socket? _socket;

  Stream<Uint8List> get frames => _frameController.stream;

  Future<void> connect() async {
    if (_socket != null) {
      return;
    }

    final socket = io.io(
      flaskStreamingBaseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    socket
      ..onConnect((_) => _log('Socket connected'))
      ..onDisconnect((_) => _log('Socket disconnected'))
      ..onError((err) => _log('Socket error: $err'))
      ..on('frame', (data) {
        if (data is Map && data['image'] is String) {
          try {
            final bytes = base64Decode(data['image'] as String);
            _frameController.add(bytes);
          } catch (err) {
            _log('Failed to decode frame: $err');
          }
        }
      });

    socket.connect();
    _socket = socket;
  }

  Future<void> disconnect() async {
    if (_socket == null) {
      return;
    }
    _socket!
      ..off('frame')
      ..disconnect()
      ..destroy();
    _socket = null;
  }

  Future<void> sendFrame(Uint8List jpegBytes) async {
    final payload = jsonEncode({'image': base64Encode(jpegBytes)});

    try {
      final response = await _client.post(
        Uri.parse('$flaskStreamingBaseUrl/upload_frame'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode >= 400) {
        _log('upload_frame failed (${response.statusCode}): ${response.body}');
      }
    } catch (err) {
      _log('upload_frame request error: $err');
    }
  }

  void dispose() {
    disconnect();
    _frameController.close();
    _client.close();
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[StreamingService] $message');
  }
}
