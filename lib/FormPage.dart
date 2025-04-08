import 'package:flutter/material.dart';

class FormPage extends StatefulWidget {
  final Map<String, String> formData;

  FormPage({required this.formData});

  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final TextEditingController campoNumericoController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();
  String selectedOption = 'Sí';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Formulario de Precinto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            children: [
              // Campos que no se pueden modificar (de la web)
              TextFormField(
                initialValue: widget.formData['numeroPrecinto'],
                decoration: InputDecoration(labelText: 'Número de Precinto'),
                readOnly: true,
              ),
              TextFormField(
                initialValue: widget.formData['tipo'],
                decoration: InputDecoration(labelText: 'Tipo'),
                readOnly: true,
              ),
              TextFormField(
                initialValue: widget.formData['estado'],
                decoration: InputDecoration(labelText: 'Estado'),
                readOnly: true,
              ),
              TextFormField(
                initialValue: widget.formData['fecha'],
                decoration: InputDecoration(labelText: 'Fecha'),
                readOnly: true,
              ),

              // Campos que el usuario debe completar
              TextFormField(
                controller: campoNumericoController,
                decoration: InputDecoration(labelText: 'Edad del Animal'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese la edad del animal';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedOption,
                items: [
                  DropdownMenuItem(
                    value: 'Sí',
                    child: Text('Sí'),
                  ),
                  DropdownMenuItem(
                    value: 'No',
                    child: Text('No'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedOption = value!;
                  });
                },
                decoration: InputDecoration(labelText: '¿El animal tiene enfermedad?'),
              ),
              TextFormField(
                controller: observacionesController,
                decoration: InputDecoration(labelText: 'Observaciones'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese observaciones';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  if (campoNumericoController.text.isEmpty ||
                      observacionesController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Todos los campos son obligatorios')));
                    return;
                  }
                  // Aquí podrías hacer el envío de los datos a la API.
                },
                child: Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
