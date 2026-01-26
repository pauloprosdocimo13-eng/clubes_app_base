import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_sorteo.dart';
import 'pantalla_admin_gestion_numeros.dart';
import 'pantalla_admin_realizar_sorteo.dart'; // <--- IMPORT DEL BOLILLERO

class PantallaAdminSorteos extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaAdminSorteos({super.key, required this.config});

  void _borrarSorteo(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar rifa?"),
        content: const Text("Se borrará todo el historial de ventas y ganadores de este sorteo."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('sorteos').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Rifas"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: config.colorPrimario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nueva Rifa", style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioSorteo(config: config),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sorteos')
            .orderBy('fecha_sorteo', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("No hay rifas activas."),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminFormularioSorteo(config: config),
                        ),
                      );
                    },
                    child: const Text("Crear primera rifa"),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              final titulo = data['titulo'] ?? 'Sorteo';
              final precio = (data['precio'] ?? 0).toDouble();
              final activo = data['activo'] ?? true;
              final vendidos = (data['numeros_vendidos'] as List?)?.length ?? 0;
              final total = data['cantidad_numeros'] ?? 100;

              // Calcular recaudación estimada
              final recaudacion = vendidos * precio;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                child: Column(
                  children: [
                    // CABECERA
                    ListTile(
                      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        activo ? "ACTIVA" : "PAUSADA/FINALIZADA",
                        style: TextStyle(color: activo ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: activo ? Colors.green : Colors.grey,
                        child: const Icon(Icons.confirmation_number, color: Colors.white),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: "Editar info",
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => PantallaAdminFormularioSorteo(config: config, sorteoId: id)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: "Eliminar",
                            onPressed: () => _borrarSorteo(context, id),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0),

                    // PIE DE TARJETA CON ESTADÍSTICAS Y BOTONES
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ESTADÍSTICAS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Vendidos: $vendidos / $total", style: const TextStyle(fontSize: 14)),
                              Text("Recaudado: \$${recaudacion.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // BOTONES DE ACCIÓN (NUEVA FILA)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 1. GESTIONAR NÚMEROS (VENTAS)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.grid_on, size: 16),
                                  label: const Text("VENDER NÚMEROS", style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (c) => PantallaAdminGestionNumeros(
                                              config: config,
                                              sorteoId: id,
                                              tituloSorteo: titulo,
                                              cantidadNumeros: total,
                                            )
                                        )
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // 2. REALIZAR SORTEO (BOLILLERO)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[800],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.casino, size: 16),
                                  label: const Text("SALA DE SORTEO", style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (c) => PantallaAdminRealizarSorteo(
                                              config: config,
                                              sorteoId: id,
                                              tituloSorteo: titulo,
                                              cantidadNumeros: total,
                                            )
                                        )
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}