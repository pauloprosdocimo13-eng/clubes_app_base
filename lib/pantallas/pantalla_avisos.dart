import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaAvisos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAvisos({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  Widget build(BuildContext context) {
    if (ServicioDatosClub.usaTuSedeCentral) {
      return _AvisosTuSede(
        config: config,
        deporteId: deporteId,
      );
    }

    return _AvisosLegacy(
      config: config,
      deporteId: deporteId,
    );
  }
}

class _AvisosTuSede extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const _AvisosTuSede({
    required this.config,
    required this.deporteId,
  });

  @override
  State<_AvisosTuSede> createState() =>
      _AvisosTuSedeState();
}

class _AvisosTuSedeState extends State<_AvisosTuSede> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ServicioContenidoPublico.cargarAvisos(
      widget.deporteId,
    );
  }

  void _recargar() {
    setState(() {
      _future = ServicioContenidoPublico.cargarAvisos(
        widget.deporteId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pudimos cargar los avisos.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('REINTENTAR'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _ListaAvisos(
            config: widget.config,
            avisos:
                snapshot.data ?? <Map<String, dynamic>>[],
          );
        },
      ),
    );
  }
}

class _AvisosLegacy extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const _AvisosLegacy({
    required this.config,
    required this.deporteId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('avisos')
            .where('deporte_id', isEqualTo: deporteId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final avisos = snapshot.data?.docs
                  .map(
                    (doc) =>
                        doc.data() as Map<String, dynamic>,
                  )
                  .toList() ??
              <Map<String, dynamic>>[];

          return _ListaAvisos(
            config: config,
            avisos: avisos,
          );
        },
      ),
    );
  }
}

class _ListaAvisos extends StatelessWidget {
  final ConfiguracionApp config;
  final List<Map<String, dynamic>> avisos;

  const _ListaAvisos({
    required this.config,
    required this.avisos,
  });

  String _fechaTexto(dynamic valor) {
    if (valor is Timestamp) {
      final dt = valor.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }

    if (valor is DateTime) {
      return '${valor.day}/${valor.month}/${valor.year}';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (avisos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'No hay avisos recientes',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: avisos.length,
      itemBuilder: (context, index) {
        final data = avisos[index];
        final importante =
            data['importante'] ?? false;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: importante
                      ? Colors.red
                      : config.colorPrimario,
                  width: 5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (data['titulo'] ?? 'Aviso')
                              .toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: importante
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (importante)
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _fechaTexto(data['fecha']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Divider(),
                  Text(
                    (data['mensaje'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
