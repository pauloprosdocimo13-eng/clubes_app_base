import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import '../widgets/input_imagen.dart';

class PantallaAdminFormularioNoticia extends StatefulWidget {
  final ConfiguracionApp config;
  final String? noticiaId; // null = Nueva

  const PantallaAdminFormularioNoticia({
    super.key,
    required this.config,
    this.noticiaId,
  });

  @override
  State<PantallaAdminFormularioNoticia> createState() => _PantallaAdminFormularioNoticiaState();
}

class _PantallaAdminFormularioNoticiaState extends State<PantallaAdminFormularioNoticia> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _bajadaController = TextEditingController();
  final TextEditingController _imagenController = TextEditingController();

  // Opción para ocultar una noticia sin borrarla (Borrador)
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    if (widget.noticiaId != null) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('noticias').doc(widget.noticiaId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _tituloController.text = data['titulo'] ?? '';
        _bajadaController.text = data['bajada'] ?? '';
        _imagenController.text = data['imagen_url'] ?? '';
        setState(() {
          _visible = data['visible'] ?? true;
        });
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarNoticia() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = {
      'titulo': _tituloController.text.trim(),
      'bajada': _bajadaController.text.trim(), // Texto principal
      'imagen_url': _imagenController.text.trim(),
      'visible': _visible,
      // Al editar, actualizamos la fecha para que suba?
      // Mejor dejemos la fecha original si es edición, o actualicémosla si quieres que vuelva arriba.
      // Por ahora, actualizamos siempre para "revivir" noticias viejas.
      'fecha': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.noticiaId == null) {
        await FirebaseFirestore.instance.collection('noticias').add(datos);
      } else {
        await FirebaseFirestore.instance.collection('noticias').doc(widget.noticiaId).update(datos);
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
        title: Text(widget.noticiaId == null ? "Nueva Noticia" : "Editar Noticia"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarNoticia)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // TÍTULO
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                  labelText: "Título",
                  border: OutlineInputBorder(),
                  hintText: "Ej: CAMPEONES 2015"
              ),
              validator: (v) => v!.isEmpty ? "Falta el título" : null,
            ),
            const SizedBox(height: 15),

            // IMAGEN URL
            // WIDGET DE IMAGEN
            InputImagen(
              urlInicial: _imagenController.text,
              carpeta: 'noticias',
              alSubirImagen: (url) {
                _imagenController.text = url;
              },
            ),
            // Campo oculto para guardar la URL
            Visibility(
              visible: false,
              child: TextFormField(controller: _imagenController),
            ),
            const SizedBox(height: 15),

            // CONTENIDO
            TextFormField(
              controller: _bajadaController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Contenido de la noticia",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.isEmpty ? "Escribe algo..." : null,
            ),
            const SizedBox(height: 10),

            // SWITCH VISIBLE
            SwitchListTile(
              title: const Text("Publicada"),
              subtitle: Text(_visible ? "Visible en la app" : "Oculta (Borrador)"),
              value: _visible,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => _visible = v),
            ),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _guardarNoticia,
              icon: const Icon(Icons.publish),
              label: const Text("PUBLICAR NOTICIA"),
            ),
          ],
        ),
      ),
    );
  }
}