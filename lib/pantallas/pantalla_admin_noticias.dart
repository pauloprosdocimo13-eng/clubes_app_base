import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import 'pantalla_admin_formulario_noticia.dart';

class PantallaAdminNoticias extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaAdminNoticias({
    super.key,
    required this.config,
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

  Future<void> _borrarNoticia(
    BuildContext context,
    String id,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar noticia?'),
        content: const Text('No se podrá recuperar.'),
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
      await ServicioDatosClub.noticias.doc(id).delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Noticia eliminada de '
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
        title: const Text('Gestionar Noticias'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: config.colorPrimario,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaAdminFormularioNoticia(
                config: config,
              ),
            ),
          );
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // No usamos orderBy para no exigir índices adicionales durante
        // la migración. Ordenamos localmente por fecha.
        stream: ServicioDatosClub.noticias.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar las noticias:\n'
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

          final docs = snapshot.data!.docs.toList()
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
                'No hay noticias cargadas en '
                '${ServicioDatosClub.origenDescripcion}.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final id = docs[index].id;
              final visible = data['visible'] ?? true;
              final imagenUrl =
                  (data['imagen_url'] ?? '').toString();

              return Card(
                color: visible ? Colors.white : Colors.grey[200],
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                      image: imagenUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imagenUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imagenUrl.isEmpty
                        ? const Icon(Icons.newspaper)
                        : null,
                  ),
                  title: Text(
                    (data['titulo'] ?? 'Sin título').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: visible
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    (data['bajada'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                                  PantallaAdminFormularioNoticia(
                                config: config,
                                noticiaId: id,
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
                        onPressed: () => _borrarNoticia(
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
