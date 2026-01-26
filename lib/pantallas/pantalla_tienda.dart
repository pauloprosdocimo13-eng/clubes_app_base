import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';

class PantallaTienda extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaTienda({super.key, required this.config});

  // Función para abrir WhatsApp con mensaje pre-armado
  Future<void> _pedirPorWhatsApp(BuildContext context, String producto, double precio) async {
    // 1. Buscamos el teléfono de ventas en la configuración
    // Si no está configurado, usamos un fallback (tu número actual)
    String telefono = "5491126440284";

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        // Buscamos si hay un teléfono específico para ventas, sino usamos el general
        if (data.containsKey('telefono_ventas')) {
          telefono = data['telefono_ventas'];
        } else if (data.containsKey('telefono_contacto')) {
          telefono = data['telefono_contacto'];
        }
      }
    } catch (e) {
      print("Error buscando teléfono: $e");
    }

    // 2. Armamos el mensaje
    final mensaje = "Hola! 👋 Me interesa comprar: *$producto* (Precio: \$${precio.toStringAsFixed(0)}). ¿Tienen stock?";
    final urlString = "https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}";

    // 3. Lanzamos
    final Uri uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir WhatsApp")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tienda Oficial"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tienda')
            .where('activo', isEqualTo: true) // Solo mostramos lo que tiene stock
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
                  Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("Muy pronto novedades...", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 columnas
              childAspectRatio: 0.65, // Formato vertical (tipo Instagram)
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final titulo = data['titulo'] ?? 'Producto';
              final precio = (data['precio'] ?? 0).toDouble();
              final imagen = data['imagen_url'] ?? '';
              final descripcion = data['descripcion'] ?? '';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // FOTO DEL PRODUCTO
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: imagen.isNotEmpty
                            ? Image.network(imagen, fit: BoxFit.cover)
                            : Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400], size: 40),
                        ),
                      ),
                    ),

                    // INFORMACIÓN
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (descripcion.isNotEmpty)
                                  Text(
                                    descripcion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                              ],
                            ),

                            // PRECIO Y BOTÓN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "\$${precio.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: config.colorPrimario,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.green,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.message, size: 20, color: Colors.white),
                                    onPressed: () => _pedirPorWhatsApp(context, titulo, precio),
                                    tooltip: "Pedir por WhatsApp",
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
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