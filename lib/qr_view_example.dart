import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/FormPage.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key});

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? scannedCode;
  bool hashNavigatedToForm = false;

  @override
  void reassemble() {
    super.reassemble();
    if (defaultTargetPlatform == TargetPlatform.android) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Rectángulo superior con imagen
            Container(
              width: double.infinity,
              height: 60,
              color: const Color(0xFF92949B),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Image.asset(
                'images/GobiernoAragon.png',
                width: 120,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),

            // Imagen debajo del rectángulo
            SizedBox(
              width: double.infinity,
              height: 60,
              child: Image.asset('images/OtroLogo.png', fit: BoxFit.cover),
            ),

            Expanded(
              flex: 4,
              child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
            ),
            SizedBox(
              height: 30,
              child: Center(
                child:
                    scannedCode != null
                        ? Text('Código leído: $scannedCode')
                        : const Text(
                          'Escanea un código QR',
                          style: TextStyle(fontSize: 12),
                        ),
              ),
            ),
            Container(
              height: 60,
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () {
                      // Acción para ir a la pantalla principal
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.description),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      controller.pauseCamera();

      String? scanned = scanData.code;

      if (scanned == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código QR no válido')),
        );
        controller.resumeCamera();
        return;
      }

      // Verificar si la URL escaneada es válida
      String url = scanned.startsWith('http') ? scanned : 'https://$scanned';
      print("URL escaneada: $url");

      // Verificar si la URL comienza con "http" o "https"
      if (!url.startsWith("http")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La URL escaneada no es válida')),
        );
        controller.resumeCamera();
        return;
      }

      // Verifica si ya estamos en la página del formulario antes de navegar
      if (ModalRoute.of(context)?.settings.name == "/formPage") {
        controller.resumeCamera();
        return; // No hacer nada si estamos ya en la página del formulario
      }

      // Navegar solo si la URL es válida
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormPage(url: url)),
      );
    });
  }

  Future<Map<String, String>> fetchFormData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        String numeroPrecinto = jsonData['numero_precinto'] ?? '';
        String tipo = jsonData['tipo'] ?? '';
        String estado = jsonData['estado'] ?? '';
        String fecha = jsonData['fecha'] ?? '';

        return {
          'numeroPrecinto': numeroPrecinto,
          'tipo': tipo,
          'estado': estado,
          'fecha': fecha,
        };
      } else {
        throw Exception('Error al cargar los datos de la web');
      }
    } catch (e) {
      throw Exception('Error al hacer la solicitud: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
