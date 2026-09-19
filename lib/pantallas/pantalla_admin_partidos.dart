import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_partido.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaAdminPartidos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId; // Ej: 'baby_rojo', 'futsal', etc.

  const PantallaAdminPartidos({
    super.key,
    required this.config,
    required this.deporteId,
  });

  // Función para borrar con confirmación (Más seguro)
  void _borrarPartido(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Partido"),
        content: const Text(
          "¿Estás seguro de borrar este partido y sus resultados? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ServicioDatosClub.partidos.doc(id).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo eliminar el partido: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Eliminar",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Query<Map<String, dynamic>> get _consultaPartidos {
    final consulta = ServicioDatosClub.partidos.where(
      'deporte_id',
      isEqualTo: deporteId,
    );
    // Central ordena la tira en memoria para no requerir un índice compuesto
    // nuevo. Legacy conserva su consulta y orden históricos.
    return ServicioDatosClub.usaTuSedeCentral
        ? consulta
        : consulta.orderBy('fecha', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Partidos (${deporteId.replaceAll('_', ' ').toUpperCase()})",
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: config.colorPrimario,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // Crear nuevo partido
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioPartido(
                config: config,
                deporteId: deporteId,
                partidoId: null, // null = Nuevo
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _consultaPartidos.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudieron cargar los partidos: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList();
          if (ServicioDatosClub.usaTuSedeCentral) {
            docs.sort((a, b) {
              final fechaA = (a.data() as Map<String, dynamic>)['fecha'];
              final fechaB = (b.data() as Map<String, dynamic>)['fecha'];
              final orden =
                  (fechaB is Timestamp ? fechaB.millisecondsSinceEpoch : 0)
                      .compareTo(
                        fechaA is Timestamp ? fechaA.millisecondsSinceEpoch : 0,
                      );
              return orden != 0 ? orden : a.id.compareTo(b.id);
            });
          }

          if (docs.isEmpty) {
            return const Center(
              child: Text("No hay partidos cargados para esta tira."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              final rival = data['rival'] ?? 'Sin nombre';
              final estado = data['estado'] ?? 'programado';
              final torneo = data['torneo'] ?? '-';
              final fechaRaw = data['fecha'];
              final fecha = fechaRaw is Timestamp ? fechaRaw.toDate() : null;

              // Formato fecha simple
              final fechaTexto = fecha == null
                  ? "Sin fecha"
                  : "${fecha.day}/${fecha.month}";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estado == 'finalizado'
                        ? Colors.green
                        : Colors.orange,
                    child: Icon(
                      estado == 'finalizado' ? Icons.check : Icons.access_time,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    rival,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "$fechaTexto - ${torneo.toUpperCase()} ($estado)",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // EDITAR
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PantallaAdminFormularioPartido(
                                    config: config,
                                    deporteId: deporteId,
                                    partidoId: id, // Pasamos ID para editar
                                  ),
                            ),
                          );
                        },
                      ),
                      // BORRAR (Ahora pide confirmación)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarPartido(context, id),
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
