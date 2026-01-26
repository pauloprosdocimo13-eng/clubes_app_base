import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_aviso.dart';

class PantallaAdminAvisos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId; // Fijo por ahora

  const PantallaAdminAvisos({super.key, required this.config, required this.deporteId});

  void _borrarAviso(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar aviso?"),
        content: const Text("Desaparecerá de la app de los socios."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('avisos').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Borrar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Avisos"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: config.colorPrimario,
        child: const Icon(Icons.add_alert, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioAviso(
                config: config,
                deporteId: deporteId,
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('avisos')
            .where('deporte_id', isEqualTo: deporteId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay avisos publicados"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final bool importante = data['importante'] ?? false;

              // Formato de fecha simple
              String fechaStr = "";
              if (data['fecha'] != null) {
                DateTime dt = (data['fecha'] as Timestamp).toDate();
                fechaStr = "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}";
              }

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: importante ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    importante ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: importante ? Colors.red : Colors.blue,
                    size: 30,
                  ),
                  title: Text(data['titulo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$fechaStr\n${data['mensaje']}", maxLines: 2, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaAdminFormularioAviso(
                                config: config,
                                deporteId: deporteId,
                                avisoId: id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarAviso(context, id),
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