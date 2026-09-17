import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaGaleria extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaGaleria({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaGaleria> createState() => _PantallaGaleriaState();
}

class _PantallaGaleriaState extends State<PantallaGaleria> {
  String _categoriaSeleccionada = 'General';
  List<String> _categorias = [];
  bool _cargandoCategorias = true;

  List<Map<String, dynamic>> _fotosCentrales = [];
  bool _cargandoGaleriaCentral = false;
  String _errorGaleriaCentral = '';

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  @override
  void initState() {
    super.initState();

    if (_usaCentral) {
      _cargarGaleriaCentral();
    } else {
      _cargarCategoriasDelDeporteLegacy();
    }
  }

  // ==========================================================
  // TUSEDE CENTRAL
  // ==========================================================

  Future<void> _cargarGaleriaCentral() async {
    setState(() {
      _cargandoGaleriaCentral = true;
      _errorGaleriaCentral = '';
    });

    try {
      final fotos =
          await ServicioContenidoPublico.cargarGaleria(
        widget.deporteId,
      );

      final categorias = <String>{};

      for (final foto in fotos) {
        final categoria =
            (foto['categoria'] ?? '').toString().trim();

        if (categoria.isNotEmpty && categoria != 'General') {
          categorias.add(categoria);
        }
      }

      final otrasCategorias = categorias.toList()..sort();
      final categoriasFinales = <String>[
        'General',
        ...otrasCategorias,
      ];

      if (!mounted) return;

      setState(() {
        _fotosCentrales = fotos;
        _categorias = categoriasFinales;
        _categoriaSeleccionada = 'General';
        _cargandoCategorias = false;
        _cargandoGaleriaCentral = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _fotosCentrales = [];
        _categorias = const ['General'];
        _categoriaSeleccionada = 'General';
        _cargandoCategorias = false;
        _cargandoGaleriaCentral = false;
        _errorGaleriaCentral = e.toString();
      });
    }
  }

  // ==========================================================
  // FIREBASE LEGACY
  // ==========================================================

  Future<void> _cargarCategoriasDelDeporteLegacy() async {
    List<String> categoriasEncontradas = [];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes =
            List.from(data['menu_deportes'] ?? []);

        final deporteData = menuDeportes.firstWhere(
          (element) => element['id'] == widget.deporteId,
          orElse: () => <String, dynamic>{},
        );

        if (deporteData is Map &&
            deporteData.containsKey('categorias')) {
          categoriasEncontradas =
              List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      debugPrint(
        'Error cargando categorías galería Legacy: $e',
      );
    }

    if (!categoriasEncontradas.contains('General')) {
      categoriasEncontradas.insert(0, 'General');
    }

    if (mounted) {
      setState(() {
        _categorias = categoriasEncontradas;
        _cargandoCategorias = false;
        _categoriaSeleccionada = _categorias.first;
      });
    }
  }

  void _verFotoGrande(
    String url,
    String titulo,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(titulo),
          ),
          body: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(0),
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: url,
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (
                    context,
                    url,
                    error,
                  ) =>
                      const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filtrarFotos(
    List<Map<String, dynamic>> fotos,
  ) {
    if (_categoriaSeleccionada == 'General') {
      return fotos;
    }

    return fotos
        .where(
          (foto) =>
              (foto['categoria'] ?? '').toString() ==
              _categoriaSeleccionada,
        )
        .toList();
  }

  Widget _grillaDesdeMapas(
    List<Map<String, dynamic>> fotos,
  ) {
    final fotosFiltradas = _filtrarFotos(fotos);

    if (fotosFiltradas.isEmpty) {
      return const Center(
        child: Text(
          'No hay fotos en esta categoría',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemCount: fotosFiltradas.length,
      itemBuilder: (context, index) {
        final data = fotosFiltradas[index];
        final url =
            (data['imagen_url'] ?? '').toString();
        final titulo =
            (data['titulo'] ?? '').toString();

        if (url.isEmpty) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              size: 30,
              color: Colors.grey,
            ),
          );
        }

        return GestureDetector(
          onTap: () => _verFotoGrande(
            url,
            titulo,
          ),
          child: Hero(
            tag: url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (
                  context,
                  url,
                  error,
                ) =>
                    Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image,
                    size: 30,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _galeriaCentral() {
    if (_cargandoGaleriaCentral) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorGaleriaCentral.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar la galería.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorGaleriaCentral,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _cargarGaleriaCentral,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return _grillaDesdeMapas(_fotosCentrales);
  }

  Widget _galeriaLegacy() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('galeria')
          .where(
            'deporte_id',
            isEqualTo: widget.deporteId,
          )
          .orderBy(
            'fecha',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        var fotos = snapshot.data!.docs;

        if (_categoriaSeleccionada != 'General') {
          fotos = fotos.where((doc) {
            final data =
                doc.data() as Map<String, dynamic>;

            return data['categoria'] ==
                _categoriaSeleccionada;
          }).toList();
        }

        if (fotos.isEmpty) {
          return const Center(
            child: Text(
              'No hay fotos en esta categoría',
            ),
          );
        }

        final mapas = fotos
            .map(
              (doc) =>
                  doc.data() as Map<String, dynamic>,
            )
            .toList();

        return _grillaDesdeMapas(mapas);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_cargandoCategorias)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              color: Colors.grey[100],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  final cat = _categorias[index];
                  final seleccionado =
                      cat == _categoriaSeleccionada;

                  return Padding(
                    padding:
                        const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: seleccionado,
                      selectedColor:
                          widget.config.colorPrimario,
                      labelStyle: TextStyle(
                        color: seleccionado
                            ? Colors.white
                            : Colors.black,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(
                            () =>
                                _categoriaSeleccionada =
                                    cat,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child:
                _usaCentral ? _galeriaCentral() : _galeriaLegacy(),
          ),
        ],
      ),
    );
  }
}
