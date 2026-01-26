import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart'; // <--- IMPORTANTE: Reutilizamos tu widget

class PantallaAdminAvisoEntrada extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminAvisoEntrada({super.key, required this.config});

  @override
  State<PantallaAdminAvisoEntrada> createState() => _PantallaAdminAvisoEntradaState();
}

class _PantallaAdminAvisoEntradaState extends State<PantallaAdminAvisoEntrada> {
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  final _imagenController = TextEditingController(); 

  bool _activo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('aviso_entrada').get();
      if (doc.exists) {
        final data = doc.data()!;
        _tituloController.text = data['titulo'] ?? '';
        _mensajeController.text = data['mensaje'] ?? '';
        _imagenController.text = data['imagen_url'] ?? '';
        _activo = data['activo'] ?? false;
      }
    } catch (e) {
      print("Error cargando aviso: $e");
    }

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance.collection('configuracion').doc('aviso_entrada').set({
        'titulo': _tituloController.text.trim(),
        'mensaje': _mensajeController.text.trim(),
        'imagen_url': _imagenController.text.trim(), // Si está vacío, se guarda vacío
        'activo': _activo,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuración guardada exitosamente")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Pop-up Inicial"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SWITCH ON/OFF
                  SwitchListTile(
                    title: const Text("Activar Aviso al Entrar"),
                    subtitle: const Text("Si está activo, los usuarios verán esto al abrir la app."),
                    value: _activo,
                    activeColor: widget.config.colorPrimario,
                    onChanged: (val) => setState(() => _activo = val),
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  const Text("Imagen del Aviso (Opcional)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // --- ZONA DE IMAGEN CON OPCIÓN DE BORRAR ---
                  InputImagen(
                    // TRUCO: Usamos ValueKey para forzar que el widget se "reinicie" si el texto cambia (ej: al borrar)
                    key: ValueKey(_imagenController.text),
                    urlInicial: _imagenController.text,
                    carpeta: 'avisos_popup',
                    alSubirImagen: (url) {
                      setState(() {
                        _imagenController.text = url;
                      });
                    },
                  ),
                  
                  // BOTÓN PARA QUITAR IMAGEN (Solo si hay una cargada)
                  if (_imagenController.text.isNotEmpty)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _imagenController.clear(); // Limpiamos el texto
                          });
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text("Quitar Imagen y dejar vacío", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  // -------------------------------------------

                  const SizedBox(height: 20),

                  TextField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: "Título Corto",
                      hintText: "Ej: ¡GRAN RIFA ESTE SÁBADO!",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _mensajeController,
                    decoration: const InputDecoration(
                      labelText: "Mensaje Detallado",
                      hintText: "Ej: No te pierdas la oportunidad de ganar...",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _guardar,
                    icon: const Icon(Icons.save),
                    label: const Text("GUARDAR CONFIGURACIÓN", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}