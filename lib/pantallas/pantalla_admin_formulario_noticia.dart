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

  bool _visible = true;
  bool _enviarPush = true; // NUEVO: Control de notificaciones

  @override
  void initState() {
    super.initState();
    if (widget.noticiaId != null) {
      _cargarDatos();
      // Si estamos editando, apagamos el push por defecto para no spamear por un error de tipeo
      _enviarPush = false; 
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
          // Si el documento viejo tenía la variable, la leemos, sino falso.
          _enviarPush = data['enviar_push'] ?? false; 
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
      'bajada': _bajadaController.text.trim(), 
      'imagen_url': _imagenController.text.trim(),
      'visible': _visible,
      'enviar_push': _enviarPush, // NUEVO: Le pasamos la orden al servidor
      'topic_destino': 'general', // NUEVO: Enrutamiento para tu index.js
      'fecha': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.noticiaId == null) {
        // Al usar .add(), disparamos el evento onDocumentCreated en tu servidor
        await FirebaseFirestore.instance.collection('noticias').add(datos);
      } else {
        // Al usar .update(), solo actualizamos datos silenciosamente
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
            const SizedBox(height: 15),

            // --- PANELES DE CONTROL ---
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // SWITCH VISIBLE
                  SwitchListTile(
                    title: const Text("Publicada", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_visible ? "Visible en la app" : "Oculta (Borrador)"),
                    value: _visible,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => _visible = v),
                  ),
                  const Divider(height: 1),
                  
                  // SWITCH NOTIFICACIÓN PUSH
                  SwitchListTile(
                    title: const Text("Alerta a Socios", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _enviarPush 
                        ? "Hará sonar el celular de todos los socios" 
                        : "Se guardará silenciosamente",
                      style: TextStyle(color: _enviarPush ? Colors.blue[700] : Colors.grey),
                    ),
                    value: _enviarPush,
                    activeColor: Colors.blue,
                    // Si están editando y quieren enviar push igual, el servidor no lo va a agarrar 
                    // a menos que cambies el backend, pero dejamos la opción por si el día de mañana
                    // actualizás el backend a onDocumentWritten.
                    onChanged: (v) => setState(() => _enviarPush = v),
                  ),
                ],
              ),
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
              label: const Text("GUARDAR NOTICIA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}