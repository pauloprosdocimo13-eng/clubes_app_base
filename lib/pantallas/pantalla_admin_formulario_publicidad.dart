import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import '../widgets/input_imagen.dart';

class PantallaAdminFormularioPublicidad extends StatefulWidget {
  final ConfiguracionApp config;
  final String? publicidadId; // null = Nuevo

  const PantallaAdminFormularioPublicidad({
    super.key,
    required this.config,
    this.publicidadId,
  });

  @override
  State<PantallaAdminFormularioPublicidad> createState() => _PantallaAdminFormularioPublicidadState();
}

class _PantallaAdminFormularioPublicidadState extends State<PantallaAdminFormularioPublicidad> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _imagenController = TextEditingController();
  final TextEditingController _ordenController = TextEditingController(text: "1");

  bool _activo = true; // Por defecto el sponsor nace activo

  @override
  void initState() {
    super.initState();
    if (widget.publicidadId != null) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('publicidad').doc(widget.publicidadId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = data['nombre'] ?? '';
        _linkController.text = data['link'] ?? '';
        _imagenController.text = data['imagen_url'] ?? '';
        _ordenController.text = (data['orden'] ?? 1).toString();
        setState(() {
          _activo = data['activo'] ?? true;
        });
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPublicidad() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = {
      'nombre': _nombreController.text.trim(),
      'link': _linkController.text.trim(),
      'imagen_url': _imagenController.text.trim(),
      'orden': int.tryParse(_ordenController.text) ?? 1,
      'activo': _activo,
    };

    try {
      if (widget.publicidadId == null) {
        await FirebaseFirestore.instance.collection('publicidad').add(datos);
      } else {
        await FirebaseFirestore.instance.collection('publicidad').doc(widget.publicidadId).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.publicidadId == null ? "Nuevo Sponsor" : "Editar Sponsor"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarPublicidad)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // NOMBRE
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: "Nombre del Comercio", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Requerido" : null,
            ),
            const SizedBox(height: 15),

            // LINK DESTINO
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                  labelText: "Link al tocar (Instagram/Web)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  helperText: "Ej: https://instagram.com/pizzerialosamigos"
              ),
            ),
            const SizedBox(height: 15),

            // IMAGEN URL
            // ...
            const SizedBox(height: 15),

            // WIDGET DE IMAGEN
            InputImagen(
              urlInicial: _imagenController.text,
              carpeta: 'publicidad',
              alSubirImagen: (url) {
                _imagenController.text = url;
              },
            ),

            Visibility(
              visible: false,
              child: TextFormField(controller: _imagenController),
            ),
            // ...
            const SizedBox(height: 15),

            // ORDEN Y ACTIVO
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ordenController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Orden", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: SwitchListTile(
                    title: const Text("Activo"),
                    subtitle: Text(_activo ? "Se muestra" : "Oculto"),
                    value: _activo,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => _activo = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // VISTA PREVIA (Si hay link de imagen)
            if (_imagenController.text.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vista Previa:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.network(
                      _imagenController.text,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _guardarPublicidad,
              child: const Text("GUARDAR SPONSOR"),
            ),
          ],
        ),
      ),
    );
  }
}