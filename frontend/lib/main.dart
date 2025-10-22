import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Pengaduan PPKS',
      home: Scaffold(
        appBar: AppBar(title: const Text('Sistem Pengaduan PPKS')),
        body: const Center(child: Text('Frontend placeholder')),
      ),
    );
  }
}
