import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import 'pantalla_admin_formulario_aviso.dart';

class PantallaAdminAvisos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAdminAvisos({
    super.key,
    required this.config,
    required this.deporteId,
  });

  int _fechaMillis(Map<String, dynamic> data) {
    final valor = data['fecha'];

    if (valor is Timestamp) {
      return valor.millisecondsSinceEpoch;
    }

    if (valor is DateTime) {
      return valor.millisecondsSinceEpoch;
    }

    return 0;
  }

  Future<void> _borrarAviso(
    BuildContext context,
    String id,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar aviso?'),
        content: const Text(
          'Desaparecerá de la app de los socios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Borrar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ServicioDatosClub.avisos.doc(id).delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aviso eliminado de '
            '${ServicioDatosClub.origenDescripcion}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al borrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Avisos'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: config.colorPrimario,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaAdminFormularioAviso(
                config: config,
                deporteId: deporteId,
              ),
            ),
          );
        },
        child: const Icon(
          Icons.add_alert,
          color: Colors.white,
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Leemos la colección del club y filtramos localmente.
        // Así evitamos depender de índices compuestos en la etapa de prueba.
        stream: ServicioDatosClub.avisos.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar los avisos:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs
              .where(
                (doc) =>
                    (doc.data()['deporte_id'] ?? '').toString() ==
                    deporteId,
              )
              .toList()
            ..sort(
              (a, b) => _fechaMillis(
                b.data(),
              ).compareTo(
                _fechaMillis(a.data()),
              ),
            );

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No hay avisos publicados para "$deporteId".',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final id = docs[index].id;
              final importante =
                  data['importante'] ?? false;

              String fechaStr = '';
              final fecha = data['fecha'];

              if (fecha is Timestamp) {
                final dt = fecha.toDate();
                fechaStr =
                    '${dt.day}/${dt.month} '
                    '${dt.hour}:'
                    '${dt.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: importante
                      ? const BorderSide(
                          color: Colors.red,
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    importante
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: importante
                        ? Colors.red
                        : Colors.blue,
                    size: 30,
                  ),
                  title: Text(
                    (data['titulo'] ?? 'Sin título').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$fechaStr\n'
                    '${(data['mensaje'] ?? '').toString()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PantallaAdminFormularioAviso(
                                config: config,
                                deporteId: deporteId,
                                avisoId: id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () => _borrarAviso(
                          context,
                          id,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
