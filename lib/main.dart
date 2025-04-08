import 'package:flutter/material.dart';
import 'qr_view_example.dart'; // Asegúrate de que la ruta sea correcta

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escáner QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const QRViewExample(), // Aquí está el cambio importante
    );
  }
}
