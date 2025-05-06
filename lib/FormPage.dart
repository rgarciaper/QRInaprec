import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/qr_view_example.dart';
import 'package:http/http.dart' as http;

class FormPage extends StatefulWidget { // Form
  final String url;

  const FormPage({super.key, required this.url});

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
  bool camposBloqueados = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    final url = Uri.parse('https://preaplicaciones.aragon.es/inaprec/ws/movilPrecinto');
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    final body = {'hash': 'UFJFQ0lOVE9TU0VSVklDRQ==', 'codigo': codPrec};

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final precintoMovil = data['precintoMovil'];

      if (precintoMovil != null) {
        // Depuración: Imprimir el estado del precinto
        print('Estado del precinto: ${precintoMovil['estado']}');

        // Si el estado es 'CAZADO', cargar los datos pero bloquear los campos
        if (precintoMovil['estado']?.toString().trim().toUpperCase() == 'CAZADO') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ Este precinto ya ha sido comunicado(cazado). Los datos son solo de lectura.')),
          );
          setState(() {
            camposBloqueados = true; // Bloquear los campos
          });
        }

        final valores = Map<String, dynamic>.from(precintoMovil['valoresIngresados'] ?? {});
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


  String? _validateField(String id, String? value) { // Validación de campos
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


  bool _debeCodificarseEnBase64(String id) {
  // Personaliza esta lógica con los IDs reales que necesitan codificación
  const camposACodificar = ['observaciones', 'comentarios', 'descripcion']; // Ejemplo
  return camposACodificar.contains(id.toLowerCase());
}


  Future<void> enviarFormulario() async {
    if (precinto?['estado']?.toString().toUpperCase() == 'CAZADO') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Este precinto ya ha sido usado y no puede ser comunicado.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Corrige los errores antes de enviar')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://preaplicaciones.aragon.es/inaprec/ws/comunicacionPrecinto'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'hash': 'UFJFQ0lOVE9TU0VSVklDRQ==',
          'codigo': precinto?['codigo'],
          'fechaCaza': _parseFechaCazaToISO(fechaCazaController.text),
          'valoresIngresados': {
            for (var id in formValues.keys)
              id: _debeCodificarseEnBase64(id)
                  ? base64.encode(utf8.encode(controllers[id]?.text ?? ''))
                  : (controllers[id]?.text ?? ''),
          },
          'comunicarCazado': comunicarCazado,
        }),
      );


      if (response.statusCode == 200) {
        setState(() { // Actualiza el estado de la UI después de enviar el formulario
          enviadoCorrectamente = true; // Cambia el estado a enviado correctamente
          camposBloqueados = true; // Bloquea los campos después de enviar
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Comunicación enviada correctamente')),
        );
      } else {
        print('❌ Código: ${response.statusCode}');
        print('❌ Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al enviar la comunicación')),
        );
      }
    }
    catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❗ Error al enviar la comunicación')),
      );
    }
  }

  String _parseFechaCazaToISO(String fecha) { // Convierte la fecha de formato dd/MM/yyyy a ISO 8601
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
    final bool isReadOnly = config['readonly'] ?? false;

    

    switch (tipo) {
      case 'number':
        return TextFormField(
          controller: controllers[id],
          decoration: InputDecoration(labelText: etiqueta, filled: true, fillColor: isReadOnly ? Colors.grey[300] : Colors.white),
          keyboardType: TextInputType.number,
          validator: (value) => _validateField(id, value),
          readOnly: isReadOnly || camposBloqueados,
        );
      case 'select':
        final List<String> opciones = List<String>.from(config['valoresComoLista'] ?? []);
        return DropdownButtonFormField<String>(
          value: formValues[id] != '' ? formValues[id] : null,
          decoration: InputDecoration(labelText: etiqueta),
          items: opciones.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (isReadOnly || camposBloqueados ) ? null : (val) {
            setState(() {
              formValues[id] = val!;
              controllers[id]?.text = val;
            });
          },
          validator: (value) => _validateField(id, value),
        );
      case 'text':
      default:
        return TextFormField(
          controller: controllers[id],
          decoration: InputDecoration(labelText: etiqueta, filled: true, fillColor: isReadOnly ? Colors.grey[300] : Colors.white),
          maxLines: 3,
          validator: (value) => _validateField(id, value),
          readOnly: isReadOnly || camposBloqueados,
        );
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
            Container(
              width: double.infinity,
              height: 60,
              color: const Color(0xFF92949B),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Image.asset('images/GobiernoAragon.png', width: 120, height: 50, fit: BoxFit.contain),
            ),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: Image.asset('images/OtroLogo.png', fit: BoxFit.cover),
            ),

            if (enviadoCorrectamente)
              Container(
                width: double.infinity,
                color: Colors.lightBlue.shade100,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(8),
                child: Row(
                  children: const [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Se ha comunicado el precinto satisfactoriamente.', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),

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
                        decoration: InputDecoration(
                          labelText: 'Número de Precinto',
                          labelStyle: TextStyle(fontWeight: FontWeight.bold), // <---
                          filled: true,
                        ),
                        readOnly: true,
                      ),
                      TextFormField(
                        initialValue: precinto!['tipo'],
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: TextStyle(fontWeight: FontWeight.bold), // <---
                          filled: true,
                        ),
                        readOnly: true,
                      ),
                      TextFormField(
                        initialValue: precinto!['estado'],
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          labelStyle: TextStyle(fontWeight: FontWeight.bold),
                          filled: true,
                        ),
                        readOnly: true,
                        style: TextStyle(
                          color: precinto!['estado'].toString().toUpperCase() == 'CAZADO'
                              ? Colors.blue
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      TextFormField(
                        controller: fechaCazaController,
                        decoration: InputDecoration(
                          labelText: 'Fecha Caza',
                          labelStyle: TextStyle(fontWeight: FontWeight.bold), // <---
                          filled: true,
                        ),
                        readOnly: true,
                      ),

                      const SizedBox(height: 20),
                      ...precinto!['configuracion'].map<Widget>((conf) => _buildDynamicField(conf)).toList(),
                      if (!camposBloqueados)
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
                  if (!camposBloqueados)
                    ElevatedButton(
                      onPressed: comunicarCazado ? enviarFormulario : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: comunicarCazado ? null : Colors.grey,
                      ),
                      child: const Text('Comunicar'),
                    ),

                    ],
                  ),
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
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => QRViewExample(), // Cambia a la pantalla principal
                        ),
                      );
                    }
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

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
