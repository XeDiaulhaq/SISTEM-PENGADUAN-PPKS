import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Pengaduan PPKS',
      home: const StreamViewer(),
    );
  }
}

class StreamViewer extends StatefulWidget {
  const StreamViewer({super.key});

  @override
  State<StreamViewer> createState() => _StreamViewerState();
}

class _StreamViewerState extends State<StreamViewer> {
  IO.Socket? socket;
  Uint8List? latestImage;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
  // Development: explicitly connect to backend service on port 5000.
  // Using the origin port (e.g. Flutter dev server) caused the client to try
  // connecting to the wrong port (no SocketIO server there). Set this to
  // your backend if different (e.g. on a remote host).
  final host = 'http://localhost:5000';

    socket = IO.io(host, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    socket!.onConnect((_) {
      debugPrint('Socket connected to $host');
      // Also print to browser console when running web
      print('Socket connected to $host');
    });

    socket!.on('frame', (data) {
      try {
        final b64 = data['image'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          final bytes = base64Decode(b64);
          setState(() {
            latestImage = bytes;
          });
        }
      } catch (e) {
        debugPrint('Failed to decode frame: $e');
        print('Failed to decode frame: $e');
      }
    });

    socket!.onDisconnect((_) => debugPrint('Socket disconnected'));
    socket!.connect();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Camera Stream')),
      body: Center(
        child: latestImage == null
            ? const Text('Waiting for frames...')
            : Image.memory(latestImage!),
      ),
    );
  }
}
