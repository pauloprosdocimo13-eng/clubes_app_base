import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_firebase.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../widgets/estado_carga.dart';
import 'pantalla_detalle_noticia.dart';

class PantallaNoticias extends StatelessWidget {
  final ConfiguracionApp config;

  PantallaNoticias({
    super.key,
    required this.config,
  });

  final ServicioFirebase _servicioLegacy = ServicioFirebase();

  @override
  Widget build(BuildContext context) {
    if (ServicioDatosClub.usaTuSedeCentral) {
      return _NoticiasTuSede(config: config);
    }

    return _NoticiasLegacy(
      config: config,
      servicio: _servicioLegacy,
    );
  }
}

class _NoticiasTuSede extends StatefulWidget {
  final ConfiguracionApp config;

  const _NoticiasTuSede({
    required this.config,
  });

  @override
  State<_NoticiasTuSede> createState() =>
      _NoticiasTuSedeState();
}

class _NoticiasTuSedeState extends State<_NoticiasTuSede> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ServicioContenidoPublico.cargarNoticias();
  }

  void _recargar() {
    setState(() {
      _future = ServicioContenidoPublico.cargarNoticias();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _EstructuraNoticias(
      config: widget.config,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return EstadoCarga(
              estado: TipoEstadoPantalla.cargando,
              colorPrimario: widget.config.colorPrimario,
            );
          }

          if (snapshot.hasError) {
            return EstadoCarga(
              estado: TipoEstadoPantalla.error,
              colorPrimario: widget.config.colorPrimario,
              mensaje:
                  'No pudimos cargar las noticias.\n'
                  'Tocá para reintentar.',
              onReintentar: _recargar,
            );
          }

          final noticias =
              snapshot.data ?? <Map<String, dynamic>>[];

          if (noticias.isEmpty) {
            return EstadoCarga(
              estado: TipoEstadoPantalla.vacio,
              colorPrimario: widget.config.colorPrimario,
              mensaje: 'Todavía no hay noticias publicadas',
              iconoVacio: Icons.newspaper,
            );
          }

          return _ListaNoticias(
            config: widget.config,
            noticias: noticias,
          );
        },
      ),
    );
  }
}

class _NoticiasLegacy extends StatelessWidget {
  final ConfiguracionApp config;
  final ServicioFirebase servicio;

  const _NoticiasLegacy({
    required this.config,
    required this.servicio,
  });

  @override
  Widget build(BuildContext context) {
    return _EstructuraNoticias(
      config: config,
      child: StreamBuilder<QuerySnapshot>(
        stream: servicio.obtenerNoticias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
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

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return EstadoCarga(
              estado: TipoEstadoPantalla.vacio,
              colorPrimario: config.colorPrimario,
              mensaje: 'Todavía no hay noticias publicadas',
              iconoVacio: Icons.newspaper,
            );
          }

          final noticias = snapshot.data!.docs
              .map(
                (doc) =>
                    doc.data() as Map<String, dynamic>,
              )
              .toList();

          return _ListaNoticias(
            config: config,
            noticias: noticias,
          );
        },
      ),
    );
  }
}

class _EstructuraNoticias extends StatelessWidget {
  final ConfiguracionApp config;
  final Widget child;

  const _EstructuraNoticias({
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Últimas Novedades',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: config.colorSecundario,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ListaNoticias extends StatelessWidget {
  final ConfiguracionApp config;
  final List<Map<String, dynamic>> noticias;

  const _ListaNoticias({
    required this.config,
    required this.noticias,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: noticias.length,
      itemBuilder: (context, index) {
        final noticia = noticias[index];
        final imagenUrl =
            (noticia['imagen_url'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaDetalleNoticia(
                    config: config,
                    noticia: noticia,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                if (imagenUrl.isNotEmpty)
                  Hero(
                    tag: imagenUrl,
                    child: Container(
                      color: Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: imagenUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          height: 220,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            Container(
                          height: 220,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(
                    (noticia['titulo'] ?? 'Sin título')
                        .toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      (noticia['bajada'] ??
                              noticia['cuerpo'] ??
                              '')
                          .toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  leading: imagenUrl.isEmpty
                      ? Icon(
                          Icons.newspaper,
                          color: config.colorPrimario,
                          size: 40,
                        )
                      : null,
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
