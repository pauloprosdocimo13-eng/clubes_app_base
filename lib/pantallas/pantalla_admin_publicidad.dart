import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_publicidad.dart';

class PantallaAdminPublicidad extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaAdminPublicidad({super.key, required this.config});

  void _borrarPublicidad(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar sponsor?"),
        content: const Text("Esto eliminará el banner permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('publicidad').doc(id).delete();
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
        title: const Text("Gestionar Sponsors"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: config.colorPrimario,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioPublicidad(config: config),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('publicidad')
            .orderBy('orden')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay publicidad cargada"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final bool activo = data['activo'] ?? true;
              final String imagenUrl = data['imagen_url'] ?? '';

              return Card(
                // Si está inactivo, se ve un poco transparente
                color: activo ? Colors.white : Colors.grey[200],
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Container(
                    width: 80,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                      image: imagenUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(imagenUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imagenUrl.isEmpty ? const Icon(Icons.image) : null,
                  ),
                  title: Text(data['nombre'] ?? 'Sin nombre', style: TextStyle(fontWeight: FontWeight.bold, color: activo ? Colors.black : Colors.grey)),
                  subtitle: Text(activo ? "ACTIVO - Orden: ${data['orden']}" : "INACTIVO - Orden: ${data['orden']}", style: TextStyle(color: activo ? Colors.green : Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaAdminFormularioPublicidad(
                                config: config,
                                publicidadId: id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarPublicidad(context, id),
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