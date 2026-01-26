import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

class PantallaAdminFormularioAviso extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? avisoId; // null = Nuevo

  const PantallaAdminFormularioAviso({
    super.key,
    required this.config,
    required this.deporteId,
    this.avisoId,
  });

  @override
  State<PantallaAdminFormularioAviso> createState() => _PantallaAdminFormularioAvisoState();
}

class _PantallaAdminFormularioAvisoState extends State<PantallaAdminFormularioAviso> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _mensajeController = TextEditingController();
  bool _importante = false;

  @override
  void initState() {
    super.initState();
    if (widget.avisoId != null) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('avisos').doc(widget.avisoId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _tituloController.text = data['titulo'] ?? '';
        _mensajeController.text = data['mensaje'] ?? '';
        setState(() {
          _importante = data['importante'] ?? false;
        });
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarAviso() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = {
      'titulo': _tituloController.text.trim(),
      'mensaje': _mensajeController.text.trim(),
      'importante': _importante,
      'deporte_id': widget.deporteId,
      // Si es nuevo, usamos la fecha de hoy. Si editamos, podríamos mantener la original o actualizarla.
      // Aquí actualizamos la fecha para que suba arriba de todo al editarlo.
      'fecha': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.avisoId == null) {
        await FirebaseFirestore.instance.collection('avisos').add(datos);
      } else {
        await FirebaseFirestore.instance.collection('avisos').doc(widget.avisoId).update(datos);
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
        title: Text(widget.avisoId == null ? "Nuevo Aviso" : "Editar Aviso"),
        backgroundColor: _importante ? Colors.red[900] : Colors.grey[900], // Cambia color si es urgente
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.send), onPressed: _guardarAviso)
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
                  labelText: "Título Corto",
                  border: OutlineInputBorder(),
                  hintText: "Ej: SUSPENSIÓN DE FECHA"
              ),
              validator: (v) => v!.isEmpty ? "Escribe un título" : null,
            ),
            const SizedBox(height: 20),

            // IMPORTANTE (Switch)
            Container(
              decoration: BoxDecoration(
                color: _importante ? Colors.red[50] : Colors.white,
                border: _importante ? Border.all(color: Colors.red) : Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: Text(
                  "¿Es Urgente / Importante?",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _importante ? Colors.red : Colors.black,
                  ),
                ),
                subtitle: const Text("Si lo activas, saldrá destacado en rojo."),
                value: _importante,
                activeColor: Colors.red,
                secondary: Icon(Icons.warning_amber_rounded, color: _importante ? Colors.red : Colors.grey),
                onChanged: (v) => setState(() => _importante = v),
              ),
            ),
            const SizedBox(height: 20),

            // MENSAJE
            TextFormField(
              controller: _mensajeController,
              maxLines: 5, // Caja grande para escribir
              decoration: const InputDecoration(
                labelText: "Mensaje Completo",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.isEmpty ? "Escribe el mensaje" : null,
            ),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _importante ? Colors.red : widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _guardarAviso,
              icon: const Icon(Icons.campaign),
              label: const Text("PUBLICAR AVISO"),
            ),
          ],
        ),
      ),
    );
  }
}