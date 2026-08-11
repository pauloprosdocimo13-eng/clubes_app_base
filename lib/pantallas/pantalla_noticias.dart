import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_firebase.dart';
import '../widgets/estado_carga.dart';
import 'pantalla_detalle_noticia.dart';

class PantallaNoticias extends StatelessWidget {
  final ConfiguracionApp config;
  final ServicioFirebase _servicio = ServicioFirebase();

  PantallaNoticias({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TÍTULO DE LA SECCIÓN
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Últimas Novedades",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: config.colorSecundario
            ),
          ),
        ),

        // LISTA DE NOTICIAS
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _servicio.obtenerNoticias(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return EstadoCarga(
                  estado: TipoEstadoPantalla.cargando,
                  colorPrimario: config.colorPrimario,
                );
              }
              if (snapshot.hasError) {
                return EstadoCarga(
                  estado: TipoEstadoPantalla.error,
                  colorPrimario: config.colorPrimario,
                  mensaje: 'No pudimos cargar las noticias',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return EstadoCarga(
                  estado: TipoEstadoPantalla.vacio,
                  colorPrimario: config.colorPrimario,
                  mensaje: 'Todavía no hay noticias publicadas',
                  iconoVacio: Icons.newspaper,
                );
              }

              final documentos = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final noticia = documentos[index].data() as Map<String, dynamic>;
                  final String imagenUrl = noticia['imagen_url'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias, // Asegura que el InkWell respete los bordes redondos
                    child: InkWell(
                      // --- AQUÍ ESTÁ LA MAGIA DEL CLICK ---
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PantallaDetalleNoticia(
                              config: config,
                              noticia: noticia,
                            ),
                          ),
                        );
                      },
                      // ------------------------------------
                      child: Column(
                        children: [
                          // IMAGEN DE PORTADA (Si tiene)
                          if (imagenUrl.isNotEmpty)
                            Hero(
                              tag: imagenUrl, // Animación suave hacia el detalle
                              child: Container(
                                color: Colors.grey[100], // Un fondo sutil por si la imagen no ocupa todo el ancho
                                child: CachedNetworkImage(
                                  imageUrl: imagenUrl,
                                  height: 220, // Altura aumentada para que las fotos verticales luzcan mejor
                                  width: double.infinity,
                                  fit: BoxFit.contain, // Muestra la foto entera sin cortar cabezas
                                  placeholder: (context, url) => Container(
                                    height: 220,
                                    color: Colors.grey[200],
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 220,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),

                          // TEXTOS (Título y Bajada)
                          ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            title: Text(
                              noticia['titulo'] ?? 'Sin título',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                // Mostramos la bajada o un pedacito del cuerpo
                                noticia['bajada'] ?? noticia['cuerpo'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                            // Si no hay imagen grande, mostramos icono al costado
                            leading: imagenUrl.isEmpty
                                ? Icon(Icons.newspaper, color: config.colorPrimario, size: 40)
                                : null,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}