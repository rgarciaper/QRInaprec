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

  @override
  void initState() {
    super.initState();
    _loadData();
    print('📡 URL original: ${widget.url}');
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
      //final response = await http.get(url).timeout(Duration(seconds: 30));

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
      'fechaCaza': DateTime.now().toIso8601String(),
      'valoresIngresados': valores,
    };

    try {
      final response = await http.post(
        Uri.parse(postUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
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
      }
    } catch (e) {
      print('Error de conexión: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❗ Error de conexión')));
    }
  }

  Widget _buildDynamicField(Map<String, dynamic> config) {
    final String id = config['id'].toString();
    final String tipo = config['tipo'];
    final String etiqueta = config['etiqueta'];

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
      appBar: AppBar(title: Text('Precinto ${precinto!['codigo']}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: precinto!['codigo'],
                decoration: InputDecoration(labelText: 'Número de Precinto'),
                readOnly: true,
              ),
              TextFormField(
                initialValue: precinto!['tipo'],
                decoration: InputDecoration(labelText: 'Tipo'),
                readOnly: true,
              ),
              TextFormField(
                initialValue: precinto!['estado'],
                decoration: InputDecoration(labelText: 'Estado'),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              ...precinto!['configuracion']
                  .map<Widget>((conf) => _buildDynamicField(conf))
                  .toList(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: enviarFormulario,
                child: Text('Enviar'),
              ),
            ],
          ),
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
