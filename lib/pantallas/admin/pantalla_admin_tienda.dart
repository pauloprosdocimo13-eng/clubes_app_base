import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_producto.dart';

class PantallaAdminTienda extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaAdminTienda({super.key, required this.config});

  void _borrarProducto(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar producto?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('tienda').doc(id).delete();
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
        title: const Text("Gestión Tienda Oficial"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: config.colorPrimario,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("Nuevo Producto", style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioProducto(config: config),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tienda')
            .orderBy('activo', descending: true) // Activos primero
            .orderBy('titulo')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("La tienda está vacía."),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminFormularioProducto(config: config),
                        ),
                      );
                    },
                    child: const Text("Agregar primer producto"),
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

              final titulo = data['titulo'] ?? 'Sin nombre';
              final precio = data['precio'] ?? 0;
              final imagen = data['imagen_url'] ?? '';
              final activo = data['activo'] ?? true;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                // Si no está activo, lo ponemos medio transparente
                color: activo ? Colors.white : Colors.grey[200],
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      image: imagen.isNotEmpty
                          ? DecorationImage(image: NetworkImage(imagen), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imagen.isEmpty ? const Icon(Icons.image_not_supported) : null,
                  ),
                  title: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: activo ? null : TextDecoration.lineThrough,
                      color: activo ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    "\$${precio.toString()}",
                    style: TextStyle(
                      color: config.colorPrimario,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!activo)
                        const Chip(label: Text("Sin Stock", style: TextStyle(fontSize: 10))),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaAdminFormularioProducto(
                                config: config,
                                productoId: id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarProducto(context, id),
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