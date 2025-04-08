import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/FormPage.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Importa esta librería para trabajar con JSON

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key});

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? scannedCode;

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
            // ... Tu diseño UI (es igual que antes)
            Expanded(
              flex: 4,
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
              ),
            ),
            SizedBox(
              height: 30,
              child: Center(
                child: scannedCode != null
                    ? Text('Código leído: $scannedCode')
                    : const Text(
                        'Escanea un código QR',
                        style: TextStyle(fontSize: 12),
                      ),
              ),
            ),
            // Barra inferior con los iconos
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
      setState(() {
        scannedCode = scanData.code;
      });

      // Intentamos hacer la solicitud a la URL obtenida del QR
      try {
        String fullUrl = scannedCode ?? '';

        if (!fullUrl.startsWith('http://') && !fullUrl.startsWith('https://')) {
          fullUrl = 'https://$fullUrl'; // Añadimos https:// si no está presente
        }

        // Ahora realizamos la solicitud a la URL
        final formData = await fetchFormData(fullUrl); // Cambié el tipo de retorno de String a Map<String, String>

        // Navegamos a la página del formulario, pasándole los datos obtenidos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FormPage(formData: formData), // Aquí pasamos el formData
          ),
        );
      } catch (e) {
        print('Error al obtener datos: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar los datos')));
      }
    });
  }

  // Modificamos esta función para devolver Map<String, String>
  Future<Map<String, String>> fetchFormData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Aquí asumimos que la respuesta es un JSON con los datos
        final Map<String, dynamic> jsonData = json.decode(response.body);

        String numeroPrecinto = jsonData['numero_precinto'] ?? '';
        String tipo = jsonData['tipo'] ?? '';
        String estado = jsonData['estado'] ?? '';
        String fecha = jsonData['fecha'] ?? '';

        // Devolvemos los datos como un Map
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
