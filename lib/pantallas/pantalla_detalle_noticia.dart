import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../configuracion/configuracion_app.dart';

class PantallaDetalleNoticia extends StatelessWidget {
  final ConfiguracionApp config;
  final Map<String, dynamic> noticia;

  const PantallaDetalleNoticia({
    super.key,
    required this.config,
    required this.noticia,
  });

  @override
  Widget build(BuildContext context) {
    final String titulo = noticia['titulo'] ?? 'Sin Título';
    final String bajada = noticia['bajada'] ?? '';
    final String cuerpo = noticia['cuerpo'] ?? '';
    final String imagenUrl = noticia['imagen_url'] ?? '';
    
    // Calculamos el 35% del alto de la pantalla para la imagen
    final double altoImagen = MediaQuery.of(context).size.height * 0.35;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Noticia"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGEN GRANDE (Si existe)
            if (imagenUrl.isNotEmpty)
              Hero(
                tag: imagenUrl, // Animación bonita desde la lista
                child: Container(
                  width: double.infinity,
                  color: Colors.black87, // Fondo oscuro estilo porta-retrato
                  child: CachedNetworkImage(
                    imageUrl: imagenUrl,
                    width: double.infinity,
                    height: altoImagen, // Altura adaptable según el celular
                    fit: BoxFit.contain, // NO RECORTA LA IMAGEN
                    placeholder: (context, url) => Container(
                      height: altoImagen,
                      color: Colors.grey[900],
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. TÍTULO
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: config.colorPrimario,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. BAJADA (Resumen en negrita/gris)
                  if (bajada.isNotEmpty) ...[
                    Text(
                      bajada,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Divider(height: 30, thickness: 1),
                  ],

                  // 4. CUERPO (Texto completo)
                  if (cuerpo.isNotEmpty)
                    Text(
                      cuerpo,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5, // Espaciado para leer mejor
                        color: Colors.black87,
                      ),
                    )
                  else
                    const Text(
                      "Sin contenido adicional.",
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}