import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_notificaciones_topics.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../widgets/input_imagen.dart';

class PantallaAdminFormularioNoticia extends StatefulWidget {
  final ConfiguracionApp config;
  final String? noticiaId;

  const PantallaAdminFormularioNoticia({
    super.key,
    required this.config,
    this.noticiaId,
  });

  @override
  State<PantallaAdminFormularioNoticia> createState() =>
      _PantallaAdminFormularioNoticiaState();
}

class _PantallaAdminFormularioNoticiaState
    extends State<PantallaAdminFormularioNoticia> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _bajadaController = TextEditingController();
  final _imagenController = TextEditingController();

  bool _cargando = false;
  bool _visible = true;
  bool _enviarPush = true;

  @override
  void initState() {
    super.initState();

    if (widget.noticiaId != null) {
      _enviarPush = false;
      _cargarDatos();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _bajadaController.dispose();
    _imagenController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    try {
      final doc = await ServicioDatosClub.noticias
          .doc(widget.noticiaId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return;
      }

      final data = doc.data()!;

      _tituloController.text =
          (data['titulo'] ?? '').toString();
      _bajadaController.text =
          (data['bajada'] ?? '').toString();
      _imagenController.text =
          (data['imagen_url'] ?? '').toString();

      if (mounted) {
        setState(() {
          _visible = data['visible'] ?? true;
          _enviarPush = data['enviar_push'] ?? false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando noticia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarNoticia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    final user = ServicioDatosClub.usuarioAuthActual;

    final datos = <String, dynamic>{
      'titulo': _tituloController.text.trim(),
      'bajada': _bajadaController.text.trim(),
      'imagen_url': _imagenController.text.trim(),
      'visible': _visible,
      'enviar_push': _enviarPush,
      'topic_destino':
          ServicioNotificacionesTopics.topicGeneral(widget.config),
      'fecha': FieldValue.serverTimestamp(),
      'club_id': widget.config.clubIdTuSede,
      'actualizado_por_email': user?.email ?? '',
      'actualizado_por_uid': user?.uid ?? '',
    };

    try {
      if (widget.noticiaId == null) {
        datos['creado_el'] = FieldValue.serverTimestamp();

        await ServicioDatosClub.noticias.add(datos);
      } else {
        await ServicioDatosClub.noticias
            .doc(widget.noticiaId)
            .update(datos);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Noticia guardada en '
            '${ServicioDatosClub.origenDescripcion}.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando noticia: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          widget.noticiaId == null
              ? 'Nueva Noticia'
              : 'Editar Noticia',
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _cargando ? null : _guardarNoticia,
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
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: CAMPEONES 2015',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Falta el título'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  InputImagen(
                    urlInicial: _imagenController.text,
                    carpeta: 'noticias',
                    aislarPorClub:
                        ServicioDatosClub.usaTuSedeCentral,
                    alSubirImagen: (url) {
                      setState(() {
                        _imagenController.text = url;
                      });
                    },
                  ),
                  Visibility(
                    visible: false,
                    child: TextFormField(
                      controller: _imagenController,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _bajadaController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Contenido de la noticia',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Escribe algo...'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Publicada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _visible
                                ? 'Visible en la app'
                                : 'Oculta (Borrador)',
                          ),
                          value: _visible,
                          activeColor: Colors.green,
                          onChanged: (v) {
                            setState(() => _visible = v);
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text(
                            'Alerta a Socios',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _enviarPush
                                ? 'En una noticia nueva enviará push '
                                    'al club actual'
                                : 'Se guardará silenciosamente',
                            style: TextStyle(
                              color: _enviarPush
                                  ? Colors.blue[700]
                                  : Colors.grey,
                            ),
                          ),
                          value: _enviarPush,
                          activeColor: Colors.blue,
                          onChanged: (v) {
                            setState(() => _enviarPush = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(double.infinity, 50),
                    ),
                    onPressed:
                        _cargando ? null : _guardarNoticia,
                    icon: const Icon(Icons.publish),
                    label: const Text(
                      'GUARDAR NOTICIA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
