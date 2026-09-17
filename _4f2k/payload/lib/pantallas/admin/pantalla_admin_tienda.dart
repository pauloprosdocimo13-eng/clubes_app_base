import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import 'pantalla_admin_formulario_producto.dart';

class PantallaAdminTienda extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaAdminTienda({
    super.key,
    required this.config,
  });

  Future<void> _borrarProducto(
    BuildContext context,
    String id,
  ) async {
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Eliminar producto?'),
            content: Text(
              ServicioDatosClub.usaTuSedeCentral
                  ? 'Se eliminará de la Tienda de este club en TuSede.'
                  : 'Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    try {
      await ServicioDatosClub.productos.doc(id).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión Tienda Oficial'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: config.colorPrimario,
        icon: const Icon(
          Icons.add_shopping_cart,
          color: Colors.white,
        ),
        label: const Text(
          'Nuevo Producto',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PantallaAdminFormularioProducto(
                config: config,
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ServicioDatosClub.productos.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la tienda.\n${snapshot.error}',
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

          final docs = [...snapshot.data!.docs];

          docs.sort((a, b) {
            final dataA = a.data();
            final dataB = b.data();

            final activoA = dataA['activo'] != false;
            final activoB = dataB['activo'] != false;

            if (activoA != activoB) {
              return activoA ? -1 : 1;
            }

            final tituloA =
                (dataA['titulo'] ?? '').toString().toLowerCase();
            final tituloB =
                (dataB['titulo'] ?? '').toString().toLowerCase();

            return tituloA.compareTo(tituloB);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.storefront,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  const Text('La tienda está vacía.'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminFormularioProducto(
                            config: config,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Agregar primer producto',
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final id = docs[index].id;

              final titulo =
                  (data['titulo'] ?? 'Sin nombre').toString();
              final precio = data['precio'] ?? 0;
              final imagen =
                  (data['imagen_url'] ?? '').toString();
              final activo = data['activo'] != false;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                color: activo
                    ? Colors.white
                    : Colors.grey[200],
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      image: imagen.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imagen),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imagen.isEmpty
                        ? const Icon(
                            Icons.image_not_supported,
                          )
                        : null,
                  ),
                  title: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: activo
                          ? null
                          : TextDecoration.lineThrough,
                      color: activo
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    '\$${precio.toString()}',
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
                        const Chip(
                          label: Text(
                            'Sin Stock',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PantallaAdminFormularioProducto(
                                config: config,
                                productoId: id,
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
                        onPressed: () =>
                            _borrarProducto(context, id),
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
