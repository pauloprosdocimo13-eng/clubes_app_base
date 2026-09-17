import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaTienda extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaTienda({
    super.key,
    required this.config,
  });

  @override
  State<PantallaTienda> createState() =>
      _PantallaTiendaState();
}

class _PantallaTiendaState
    extends State<PantallaTienda> {
  Future<DatosTiendaPublica>? _futureCentral;

  @override
  void initState() {
    super.initState();

    if (ServicioDatosClub.usaTuSedeCentral) {
      _futureCentral =
          ServicioContenidoPublico.cargarTienda();
    }
  }

  void _recargarCentral() {
    setState(() {
      _futureCentral =
          ServicioContenidoPublico.cargarTienda();
    });
  }

  Future<void> _pedirPorWhatsApp(
    BuildContext context,
    String producto,
    double precio, {
    String telefonoCentral = '',
  }) async {
    // Fallback histórico para conservar compatibilidad
    // con clubes que todavía no configuraron el teléfono.
    String telefono = '5491126440284';

    if (ServicioDatosClub.usaTuSedeCentral) {
      if (telefonoCentral.trim().isNotEmpty) {
        telefono = telefonoCentral.trim();
      }
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('configuracion')
            .doc('general')
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;

          if (data.containsKey('telefono_ventas')) {
            telefono =
                data['telefono_ventas'].toString();
          } else if (
              data.containsKey('telefono_contacto')) {
            telefono =
                data['telefono_contacto'].toString();
          }
        }
      } catch (e) {
        debugPrint(
          'Error buscando teléfono: $e',
        );
      }
    }

    telefono =
        telefono.replaceAll(RegExp(r'[^0-9]'), '');

    if (telefono.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'El club todavía no configuró un teléfono de ventas.',
            ),
          ),
        );
      }
      return;
    }

    final mensaje =
        'Hola! 👋 Me interesa comprar: *$producto* '
        '(Precio: \$${precio.toStringAsFixed(0)}). '
        '¿Tienen stock?';

    final urlString =
        'https://wa.me/$telefono?text='
        '${Uri.encodeComponent(mensaje)}';

    final uri = Uri.parse(urlString);

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir WhatsApp',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda Oficial'),
        backgroundColor:
            widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: ServicioDatosClub.usaTuSedeCentral
          ? _buildCentral()
          : _buildLegacy(),
    );
  }

  Widget _buildCentral() {
    return FutureBuilder<DatosTiendaPublica>(
      future: _futureCentral,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 54,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pudimos cargar la tienda.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _recargarCentral,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final datos =
            snapshot.data ??
            const DatosTiendaPublica(
              productos: [],
              telefonoVentas: '',
            );

        return _buildProductos(
          datos.productos,
          telefonoVentas: datos.telefonoVentas,
        );
      },
    );
  }

  Widget _buildLegacy() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tienda')
          .where(
            'activo',
            isEqualTo: true,
          )
          .orderBy('titulo')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudo cargar la tienda.\n'
              '${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final productos = snapshot.data!.docs
            .map((doc) => doc.data())
            .toList();

        return _buildProductos(productos);
      },
    );
  }

  Widget _buildProductos(
    List<Map<String, dynamic>> productos, {
    String telefonoVentas = '',
  }) {
    if (productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'Muy pronto novedades...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final data = productos[index];

        final titulo =
            (data['titulo'] ?? 'Producto')
                .toString();

        final precioRaw = data['precio'];
        final precio = precioRaw is num
            ? precioRaw.toDouble()
            : double.tryParse(
                  precioRaw?.toString() ?? '',
                ) ??
                0.0;

        final imagen =
            (data['imagen_url'] ?? '')
                .toString();

        final descripcion =
            (data['descripcion'] ?? '')
                .toString();

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: imagen.isNotEmpty
                      ? Image.network(
                          imagen,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(
                            color:
                                Colors.grey[200],
                            child: Icon(
                              Icons.broken_image,
                              color:
                                  Colors.grey[400],
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding:
                      const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (descripcion.isNotEmpty)
                            Text(
                              descripcion,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: TextStyle(
                                color:
                                    Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          Text(
                            '\$${precio.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: widget.config
                                  .colorPrimario,
                              fontWeight:
                                  FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Colors.green,
                            child: IconButton(
                              padding:
                                  EdgeInsets.zero,
                              icon: const Icon(
                                Icons.message,
                                size: 20,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _pedirPorWhatsApp(
                                context,
                                titulo,
                                precio,
                                telefonoCentral:
                                    telefonoVentas,
                              ),
                              tooltip:
                                  'Pedir por WhatsApp',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
