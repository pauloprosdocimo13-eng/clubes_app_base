import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_notificaciones_topics.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaAdminFormularioAviso extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? avisoId;

  const PantallaAdminFormularioAviso({
    super.key,
    required this.config,
    required this.deporteId,
    this.avisoId,
  });

  @override
  State<PantallaAdminFormularioAviso> createState() =>
      _PantallaAdminFormularioAvisoState();
}

class _PantallaAdminFormularioAvisoState
    extends State<PantallaAdminFormularioAviso> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();

  bool _cargando = false;
  bool _importante = false;
  bool _enviarNotificacion = true;

  @override
  void initState() {
    super.initState();

    if (widget.avisoId != null) {
      _enviarNotificacion = false;
      _cargarDatos();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    try {
      final doc = await ServicioDatosClub.avisos
          .doc(widget.avisoId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return;
      }

      final data = doc.data()!;

      _tituloController.text =
          (data['titulo'] ?? '').toString();
      _mensajeController.text =
          (data['mensaje'] ?? '').toString();

      if (mounted) {
        setState(() {
          _importante = data['importante'] ?? false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando aviso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarAviso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    final user = ServicioDatosClub.usuarioAuthActual;

    final datos = <String, dynamic>{
      'titulo': _tituloController.text.trim(),
      'mensaje': _mensajeController.text.trim(),
      'importante': _importante,
      'deporte_id': widget.deporteId,
      'fecha': FieldValue.serverTimestamp(),
      'enviar_push': _enviarNotificacion,
      'topic_destino':
          ServicioNotificacionesTopics.topicGeneral(widget.config),
      'club_id': widget.config.clubIdTuSede,
      'actualizado_por_email': user?.email ?? '',
      'actualizado_por_uid': user?.uid ?? '',
    };

    try {
      if (widget.avisoId == null) {
        datos['creado_el'] = FieldValue.serverTimestamp();

        await ServicioDatosClub.avisos.add(datos);
      } else {
        await ServicioDatosClub.avisos
            .doc(widget.avisoId)
            .update(datos);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aviso guardado en '
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
          content: Text('Error guardando aviso: $e'),
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
          widget.avisoId == null
              ? 'Nuevo Aviso'
              : 'Editar Aviso',
        ),
        backgroundColor:
            _importante ? Colors.red[900] : Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _cargando ? null : _guardarAviso,
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
                      labelText: 'Título Corto',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: SUSPENSIÓN DE FECHA',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Escribe un título'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: _importante
                          ? Colors.red[50]
                          : Colors.white,
                      border: Border.all(
                        color: _importante
                            ? Colors.red
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        '¿Es Urgente / Importante?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _importante
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                      value: _importante,
                      activeColor: Colors.red,
                      onChanged: (v) {
                        setState(() => _importante = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _mensajeController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje Completo',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Escribe el mensaje'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  if (widget.avisoId == null)
                    Container(
                      decoration: BoxDecoration(
                        color: _enviarNotificacion
                            ? Colors.blue[50]
                            : Colors.grey[100],
                        border: Border.all(
                          color: _enviarNotificacion
                              ? Colors.blue
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Enviar Notificación Push',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'El backend TuSede calcula el topic '
                          'del club y evita cruces entre clientes.',
                        ),
                        value: _enviarNotificacion,
                        activeColor: Colors.blue,
                        onChanged: (v) {
                          setState(
                            () => _enviarNotificacion = v,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _importante
                          ? Colors.red
                          : widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(double.infinity, 50),
                    ),
                    onPressed:
                        _cargando ? null : _guardarAviso,
                    icon: const Icon(Icons.campaign),
                    label: const Text('PUBLICAR AVISO'),
                  ),
                ],
              ),
            ),
    );
  }
}
