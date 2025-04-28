import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FormPage extends StatefulWidget {
  final String url;

  const FormPage({required this.url});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  Map<String, dynamic>? precinto;
  Map<String, dynamic> formValues = {};
  Map<String, TextEditingController> controllers = {};
  Map<String, Map<String, dynamic>> configMap = {};
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController fechaCazaController;
  bool comunicarCazado = false;

  bool enviadoCorrectamente = false;
  bool campoBloqueados = false;


  @override
  void initState() {
    super.initState(
    );
    _loadData();
    print('📡 URL original: ${widget.url}');

        fechaCazaController = TextEditingController(
      text:
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
  }

  Future<void> _loadData() async {
    try {
      final codPrecEncoded = Uri.parse(widget.url).queryParameters['codPrec'];
      if (codPrecEncoded == null) {
        throw Exception('No se encontró el parámetro codPrec en la URL');
      }

      final codPrec = utf8.decode(base64.decode(codPrecEncoded));
      print('🔓 Código decodificado: $codPrec');

      final url = Uri.parse(
        'https://preaplicaciones.aragon.es/inaprec/ws/movilPrecinto',
      );
      final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
      final body = {'hash': 'UFJFQ0lOVE9TU0VSVklDRQ==', 'codigo': codPrec};

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final precintoMovil = data['precintoMovil'];

        if (precintoMovil != null) {
          final valores = Map<String, dynamic>.from(
            precintoMovil['valoresIngresados'] ?? {},
          );
          setState(() {
            precinto = precintoMovil;
            for (var conf in precintoMovil['configuracion']) {
              final id = conf['id'].toString();
              final value = valores[id] ?? '';
              formValues[id] = value;
              controllers[id] = TextEditingController(text: value);
              configMap[id] = conf;
            }
            isLoading = false;
          });
        } else {
          throw Exception('Precinto no encontrado en la respuesta');
        }
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❗ No se pudo cargar el formulario')),
      );
    }
  }

  String? _validateField(String id, String? value) {
    final config = configMap[id];
    final atributos = config?['atributosHTML'] ?? '';
    final reglas = atributos.split('/');

    for (var regla in reglas) {
      if (regla == 'required' && (value == null || value.trim().isEmpty)) {
        return 'Este campo es obligatorio';
      } else if (regla.startsWith('min')) {
        final min = int.tryParse(regla.replaceAll('min', '')) ?? 0;
        if (value != null && value.length < min) {
          return 'Mínimo $min caracteres';
        }
      } else if (regla.startsWith('max')) {
        final max = int.tryParse(regla.replaceAll('max', '')) ?? 9999;
        if (value != null && value.length > max) {
          return 'Máximo $max caracteres';
        }
      }
    }
    return null;
  }

  Future<void> enviarFormulario() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Corrige los errores antes de enviar')),
      );
      return;
    }

    const String postUrl =
        'https://preaplicaciones.aragon.es/inaprec/ws/movilPrecinto';
    final Map<String, String> valores = {
      for (var id in formValues.keys) id: controllers[id]?.text ?? '',
    };

    final body = {
      'hash': 'UFJFQ0lOVE9TU0VSVklDRQ==',
      'codigo': precinto?['codigo'],
      'fechaCaza': _parseFechaCazaToISO(fechaCazaController.text),
      'valoresIngresados': valores,
    };


    try {
      final response = await http.post(
        Uri.parse(postUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'hash': 'UFJFQ0lOVE9TU0VSVklDRQ==',
          'codigo': precinto?['codigo'],
          'fechaCaza': _parseFechaCazaToISO(fechaCazaController.text),
          'valoresIngresados': json.encode(valores),
        },
    );


      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Comunicación enviada correctamente')),
        );
      } else {
        print('Error: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al enviar la comunicación')),
        );
        print('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error de conexión: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❗ Error de conexión')));
    }
  }

    String _parseFechaCazaToISO(String fecha) {
    try {
      final parts = fecha.split('/');
      if (parts.length != 3) return '';
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day).toIso8601String();
    } catch (_) {
      return '';
    }
  }


  Widget _buildDynamicField(Map<String, dynamic> config) {
    final String id = config['id'].toString();
    final String tipo = config['tipo'];
    final String etiqueta = config['etiqueta'];

      // Verificar si el campo es de solo lectura
  final bool isReadOnly = config['readonly'] ?? false;

    // Cambiar solo el fondo de la caja de texto a gris si el campo es solo lectura
    InputDecoration inputDecoration = InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: isReadOnly ? Colors.grey[300] : Colors.white, // Fondo gris para solo lectura
    );

    switch (tipo) {
      case 'number':
        return TextFormField(
          controller: controllers[id],
          decoration: InputDecoration(labelText: etiqueta),
          keyboardType: TextInputType.number,
          validator: (value) => _validateField(id, value),
        );
      case 'select':
        final List<String> opciones = List<String>.from(
          config['valoresComoLista'] ?? [],
        );
        return DropdownButtonFormField<String>(
          value: formValues[id] != '' ? formValues[id] : null,
          decoration: InputDecoration(labelText: etiqueta),
          items:
              opciones
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
          onChanged: (val) {
            setState(() {
              formValues[id] = val!;
              controllers[id]?.text = val;
            });
          },
          validator: (value) => _validateField(id, value),
        );
      case 'text':
        return TextFormField(
          controller: controllers[id],
          decoration: InputDecoration(labelText: etiqueta),
          maxLines: 3,
          validator: (value) => _validateField(id, value),
        );
      default:
        return SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || precinto == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Formulario')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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

            // Contenido del formulario
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        initialValue: precinto!['codigo'],
                        decoration: InputDecoration(labelText: 'Número de Precinto',
                        filled: true
                        ),
                        readOnly: true,
                      ),
                      TextFormField(
                        initialValue: precinto!['tipo'],
                        decoration: InputDecoration(labelText: 'Tipo',
                        filled: true
                        ),
                        readOnly: true,
                      ),
                      TextFormField(
                        initialValue: precinto!['estado'],
                        decoration: InputDecoration(labelText: 'Estado',
                        filled: true,
                        ),
                        readOnly: true,
                      ),
                      TextFormField(
                        controller: fechaCazaController,
                        decoration: InputDecoration(
                          labelText: 'Fecha Caza',
                          filled: true,
                        ),
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),
                      ...precinto!['configuracion']
                          .map<Widget>((conf) => _buildDynamicField(conf))
                          .toList(),
                      CheckboxListTile(
                        title: const Text('Deseo comunicar el precinto como Cazado'),
                        value: comunicarCazado,
                        onChanged: (bool? value) {
                          setState(() {
                            comunicarCazado = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: enviarFormulario,
                        child: Text('Comunicar'),
                      ),
                      
                    ],
                  ),
                ),
              ),
            ),

            // Barra de navegación inferior
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

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose
  ();
  }
}

