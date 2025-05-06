import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_application_1/FormPage.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
      backgroundColor: Colors.white,
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
            /*SizedBox(
              height: 30,
              child: Center(
                child: scannedCode != null
                    ? Text('Código leído: $scannedCode')
                    : const Text(
                        'Escanea un código QR',
                        style: TextStyle(fontSize: 12),
                      ),
              ),
            ),*/
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
                    onPressed: () {
                      // Acción adicional si se necesita
                    },
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
      if (hashNavigatedToForm) return; // Prevenir múltiples escaneos
      hashNavigatedToForm = true;

      controller.pauseCamera();

      String? scanned = scanData.code;

      if (scanned == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código QR no válido')),
        );
        hashNavigatedToForm = false;
        controller.resumeCamera();
        return;
      }

      String url = scanned.startsWith('http') ? scanned : 'https://$scanned';
      print("URL escaneada: $url");

      if (!url.startsWith("http")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La URL escaneada no es válida')),
        );
        hashNavigatedToForm = false;
        controller.resumeCamera();
        return;
      }

      // Guardar el código escaneado
      setState(() {
        scannedCode = scanned;
      });

      // Navegar a la página del formulario
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormPage(url: url)),
      );

      // Al volver del formulario
      hashNavigatedToForm = false;
      controller.resumeCamera();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
