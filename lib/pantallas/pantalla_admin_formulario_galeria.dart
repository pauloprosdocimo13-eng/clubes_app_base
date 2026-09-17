import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminFormularioGaleria extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? fotoId; // null = Nueva foto

  const PantallaAdminFormularioGaleria({
    super.key,
    required this.config,
    required this.deporteId,
    this.fotoId,
  });

  @override
  State<PantallaAdminFormularioGaleria> createState() =>
      _PantallaAdminFormularioGaleriaState();
}

class _PantallaAdminFormularioGaleriaState
    extends State<PantallaAdminFormularioGaleria> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;

  final TextEditingController _tituloController =
      TextEditingController();
  final TextEditingController _imagenController =
      TextEditingController();

  String _categoria = 'General';
  List<String> _categoriasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _imagenController.dispose();
    super.dispose();
  }

  Future<void> _inicializarPantalla() async {
    await _cargarCategoriasDelDeporte();

    if (widget.fotoId != null) {
      await _cargarDatos();
    } else if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];

    try {
      final doc =
          await ServicioDatosClub.configuracionDoc('general').get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final menuDeportes = List.from(data['menu_deportes'] ?? []);

        final deporteData = menuDeportes.firstWhere(
          (e) => e['id'] == widget.deporteId,
          orElse: () => null,
        );

        if (deporteData != null && deporteData['categorias'] != null) {
          categoriasEncontradas =
              List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      debugPrint('Error buscando configuración de galería: $e');
    }

    if (categoriasEncontradas.isEmpty) {
      _generarCategoriasLegacy();
    } else {
      _categoriasDisponibles = categoriasEncontradas;
    }

    if (!_categoriasDisponibles.contains('General')) {
      _categoriasDisponibles.add('General');
    }

    if (_categoriasDisponibles.isNotEmpty) {
      _categoria = _categoriasDisponibles.last;
    }
  }

  void _generarCategoriasLegacy() {
    _categoriasDisponibles = [];

    if (!widget.deporteId.contains('baby')) {
      _categoriasDisponibles = [
        'Primera',
        'Reserva',
        'Senior',
      ];
    } else {
      final int anioActual = DateTime.now().year;

      for (int i = anioActual - 13; i <= anioActual - 7; i++) {
        _categoriasDisponibles.add(i.toString());
      }
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final doc =
          await ServicioDatosClub.galeria.doc(widget.fotoId).get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};

        _tituloController.text =
            (data['titulo'] ?? '').toString();
        _imagenController.text =
            (data['imagen_url'] ?? '').toString();

        final catGuardada =
            (data['categoria'] ?? 'General').toString();

        if (_categoriasDisponibles.contains(catGuardada)) {
          _categoria = catGuardada;
        } else {
          _categoria = 'General';
        }
      }
    } catch (e) {
      debugPrint('Error cargando foto: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarFoto() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imagenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes subir una foto'),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'titulo': _tituloController.text.trim(),
      'imagen_url': _imagenController.text.trim(),
      'categoria': _categoria,
      'deporte_id': widget.deporteId,
      'fecha': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.fotoId == null) {
        await ServicioDatosClub.galeria.add(datos);
      } else {
        await ServicioDatosClub.galeria
            .doc(widget.fotoId)
            .update(datos);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fotoId == null ? 'Subir Foto' : 'Editar Foto',
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardarFoto,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título / Descripción',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Gol de penal',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Ponle un título'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: const InputDecoration(
                      labelText: 'Álbum / Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _categoriasDisponibles
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _categoria = v);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Imagen:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  InputImagen(
                    urlInicial: _imagenController.text,
                    carpeta: 'galeria',
                    aislarPorClub:
                        ServicioDatosClub.usaTuSedeCentral,
                    alSubirImagen: (url) {
                      setState(() {
                        _imagenController.text = url;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(double.infinity, 50),
                    ),
                    onPressed: _guardarFoto,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text(
                      'GUARDAR EN ÁLBUM',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
