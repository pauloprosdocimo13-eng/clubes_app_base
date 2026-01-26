import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../configuracion/configuracion_app.dart';
import 'pantalla_admin_detalle_fecha.dart';

class PantallaAdminProde extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminProde({super.key, required this.config});

  @override
  State<PantallaAdminProde> createState() => _PantallaAdminProdeState();
}

class _PantallaAdminProdeState extends State<PantallaAdminProde> {
  // --- Lógica para Crear Nueva Fecha ---
  void _crearNuevaFecha() {
    final _tituloController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Fecha de Prode"),
        content: TextField(
          controller: _tituloController,
          decoration: const InputDecoration(labelText: "Nombre (ej: Fecha 5 - vs Morón)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              if (_tituloController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('prode_fechas').add({
                  'titulo': _tituloController.text,
                  'creada_el': FieldValue.serverTimestamp(),
                  'estado': 'ABIERTA', // ABIERTA, CERRADA, FINALIZADA
                  'partidos': [], // Aquí irán los partidos
                });
                Navigator.pop(context);
              }
            },
            child: const Text("CREAR"),
          ),
        ],
      ),
    );
  }

  // --- Lógica para Borrar Fecha ---
  void _borrarFecha(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Borrar Fecha?"),
        content: const Text("Se borrarán también los votos de la gente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('prode_fechas').doc(id).delete();
              // Idealmente borraríamos la colección 'prode_votos' asociada también
              Navigator.pop(context);
            },
            child: const Text("BORRAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión del Prode"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearNuevaFecha,
        label: const Text("Nueva Fecha"),
        icon: const Icon(Icons.add),
        backgroundColor: widget.config.colorPrimario,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prode_fechas')
            .orderBy('creada_el', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No hay fechas creadas."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final String estado = data['estado'] ?? 'ABIERTA';
              final int cantPartidos = (data['partidos'] as List? ?? []).length;

              Color colorEstado = Colors.green;
              if (estado == 'CERRADA') colorEstado = Colors.orange;
              if (estado == 'FINALIZADA') colorEstado = Colors.grey;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  title: Text(data['titulo'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$cantPartidos partidos cargados"),
                  leading: CircleAvatar(
                    backgroundColor: colorEstado,
                    child: const Icon(Icons.sports_soccer, color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5)
                        ),
                        child: Text(estado, style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // AQUÍ NAVEGAREMOS A LA EDICIÓN DE LA FECHA (Paso siguiente)
                          Navigator.push(context, MaterialPageRoute(builder: (context) =>
                              PantallaAdminDetalleFecha(config: widget.config, fechaId: id, titulo: data['titulo'])
                          ));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarFecha(id),
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