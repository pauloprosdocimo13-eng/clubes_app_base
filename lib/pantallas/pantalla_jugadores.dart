import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaJugadores extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String tituloDeporte;
  final List<String> categorias;

  const PantallaJugadores({
    super.key,
    required this.config,
    required this.deporteId,
    required this.tituloDeporte,
    required this.categorias,
  });

  @override
  State<PantallaJugadores> createState() => _PantallaJugadoresState();
}

class _PantallaJugadoresState extends State<PantallaJugadores> {
  late String _categoriaSeleccionada;
  late List<String> _categorias;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _streamJugadoresLegacy;
  Future<List<Map<String, dynamic>>>? _futureJugadoresCentral;

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  @override
  void initState() {
    super.initState();

    if (widget.categorias.isNotEmpty) {
      _categorias = List<String>.from(widget.categorias);
    } else {
      _categorias = _generarCategoriasAutomaticas();
    }

    if (!_categorias.contains('General')) {
      _categorias.insert(0, 'General');
    }

    _categoriaSeleccionada = _categorias.first;

    if (_usaCentral) {
      _cargarJugadoresCentral();
    } else {
      _streamJugadoresLegacy = FirebaseFirestore.instance
          .collection('jugadores')
          .where('deporte_id', isEqualTo: widget.deporteId)
          .snapshots();
    }
  }

  void _cargarJugadoresCentral() {
    _futureJugadoresCentral = ServicioContenidoPublico.cargarJugadores(
      widget.deporteId,
    );
  }

  void _reintentarCentral() {
    setState(() {
      _cargarJugadoresCentral();
    });
  }

  List<String> _generarCategoriasAutomaticas() {
    final anioActual = DateTime.now().year;

    final lista = <String>['General'];

    for (int i = 0; i < 8; i++) {
      lista.add((anioActual - 5 - i).toString());
    }

    return lista;
  }

  List<Map<String, dynamic>> _filtrarPorCategoria(
    List<Map<String, dynamic>> jugadores,
  ) {
    if (_categoriaSeleccionada == 'General') {
      return List<Map<String, dynamic>>.from(jugadores);
    }

    return jugadores.where((data) {
      return (data['categoria'] ?? '').toString() == _categoriaSeleccionada;
    }).toList();
  }

  Widget _contenidoConJugadores(List<Map<String, dynamic>> jugadores) {
    final jugadoresFiltrados = _filtrarPorCategoria(jugadores);

    if (jugadoresFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text(
              'No hay registros en esta categoría',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      children: [
        _ListaPlantel(
          jugadores: List<Map<String, dynamic>>.from(jugadoresFiltrados),
          config: widget.config,
        ),
        _ListaRanking(
          jugadores: List<Map<String, dynamic>>.from(jugadoresFiltrados),
          config: widget.config,
          tipo: 'goles',
        ),
        _ListaRanking(
          jugadores: List<Map<String, dynamic>>.from(jugadoresFiltrados),
          config: widget.config,
          tipo: 'asistencias',
        ),
      ],
    );
  }

  Widget _contenidoCentral() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureJugadoresCentral,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No pudimos cargar el plantel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reintentarCentral,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        return _contenidoConJugadores(
          snapshot.data ?? <Map<String, dynamic>>[],
        );
      },
    );
  }

  Widget _contenidoLegacy() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamJugadoresLegacy,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el plantel: '
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final jugadores =
            snapshot.data?.docs
                .map(
                  (doc) => <String, dynamic>{'_doc_id': doc.id, ...doc.data()},
                )
                .toList() ??
            <Map<String, dynamic>>[];

        return _contenidoConJugadores(jugadores);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Plantel ${widget.tituloDeporte}'),
          backgroundColor: widget.config.colorPrimario,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'PLANTEL'),
              Tab(text: 'GOLES'),
              Tab(text: 'ASIST'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.grey[200],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  final categoria = _categorias[index];

                  final seleccionada = categoria == _categoriaSeleccionada;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(categoria),
                      selected: seleccionada,
                      selectedColor: widget.config.colorPrimario,
                      labelStyle: TextStyle(
                        color: seleccionada ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (!selected) return;

                        setState(() {
                          _categoriaSeleccionada = categoria;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _usaCentral ? _contenidoCentral() : _contenidoLegacy(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LISTA DE PLANTEL
// ============================================================

class _ListaPlantel extends StatelessWidget {
  final List<Map<String, dynamic>> jugadores;
  final ConfiguracionApp config;

  const _ListaPlantel({required this.jugadores, required this.config});

  @override
  Widget build(BuildContext context) {
    jugadores.sort((a, b) {
      final rolA = (a['rol'] ?? 'Jugador').toString();

      final rolB = (b['rol'] ?? 'Jugador').toString();

      if (rolA == 'DT' && rolB != 'DT') {
        return -1;
      }

      if (rolA != 'DT' && rolB == 'DT') {
        return 1;
      }

      final numeroA = int.tryParse((a['dorsal'] ?? '').toString()) ?? 999;

      final numeroB = int.tryParse((b['dorsal'] ?? '').toString()) ?? 999;

      final porDorsal = numeroA.compareTo(numeroB);

      if (porDorsal != 0) {
        return porDorsal;
      }

      return (a['apellido'] ?? '').toString().compareTo(
        (b['apellido'] ?? '').toString(),
      );
    });

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: jugadores.length,
      itemBuilder: (context, index) {
        final data = jugadores[index];

        final nombre =
            '${data['nombre'] ?? ''} '
                    '${data['apellido'] ?? ''}'
                .trim();

        final foto = (data['foto'] ?? '').toString();

        final dorsal = data['dorsal'] ?? 0;

        final posicion = (data['posicion'] ?? 'Jugador').toString();

        final esDT = data['rol'] == 'DT';

        final inicial = nombre.isNotEmpty
            ? nombre.substring(0, 1).toUpperCase()
            : '?';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            onTap: () {
              _mostrarFichaJugador(context, data, config);
            },
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: esDT ? Colors.indigo[50] : Colors.grey[200],
              backgroundImage: foto.isNotEmpty
                  ? CachedNetworkImageProvider(foto)
                  : null,
              child: foto.isEmpty
                  ? Text(
                      inicial,
                      style: TextStyle(
                        color: esDT ? Colors.indigo : config.colorPrimario,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              nombre.isEmpty ? 'Sin nombre' : nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: esDT
                ? const Text(
                    'DIRECTOR TÉCNICO',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  )
                : Text(posicion),
            trailing: esDT
                ? null
                : CircleAvatar(
                    backgroundColor: config.colorPrimario,
                    radius: 18,
                    child: Text(
                      '$dorsal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// ============================================================
// RANKING DE GOLES / ASISTENCIAS
// ============================================================

class _ListaRanking extends StatelessWidget {
  final List<Map<String, dynamic>> jugadores;
  final ConfiguracionApp config;
  final String tipo;

  const _ListaRanking({
    required this.jugadores,
    required this.config,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    final ranking = jugadores.where((data) {
      if (data['rol'] == 'DT') {
        return false;
      }

      final valor = int.tryParse((data[tipo] ?? 0).toString()) ?? 0;

      return valor > 0;
    }).toList();

    if (ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tipo == 'goles' ? Icons.sports_soccer : Icons.hiking,
              size: 50,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no hay $tipo registrados.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    ranking.sort((a, b) {
      final valorA = int.tryParse((a[tipo] ?? 0).toString()) ?? 0;

      final valorB = int.tryParse((b[tipo] ?? 0).toString()) ?? 0;

      return valorB.compareTo(valorA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: ranking.length,
      itemBuilder: (context, index) {
        final data = ranking[index];

        final nombre =
            '${data['nombre'] ?? ''} '
                    '${data['apellido'] ?? ''}'
                .trim();

        final foto = (data['foto'] ?? '').toString();

        final cantidad = int.tryParse((data[tipo] ?? 0).toString()) ?? 0;

        final posicionRanking = index + 1;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: () {
              _mostrarFichaJugador(context, data, config);
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BadgePosicion(posicion: posicionRanking),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: foto.isNotEmpty
                      ? CachedNetworkImageProvider(foto)
                      : null,
                  child: foto.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
              ],
            ),
            title: Text(
              nombre.isEmpty ? 'Sin nombre' : nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Cat: '
              '${data['categoria'] ?? 'General'}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tipo == 'goles' ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tipo == 'goles'
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.blue.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tipo == 'goles' ? Icons.sports_soccer : Icons.hiking,
                    size: 16,
                    color: tipo == 'goles'
                        ? Colors.green[700]
                        : Colors.blue[700],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$cantidad',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: tipo == 'goles'
                          ? Colors.green[800]
                          : Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// POSICIÓN EN RANKING
// ============================================================

class _BadgePosicion extends StatelessWidget {
  final int posicion;

  const _BadgePosicion({required this.posicion});

  @override
  Widget build(BuildContext context) {
    Color colorFondo;
    Color colorTexto = Colors.white;

    switch (posicion) {
      case 1:
        colorFondo = const Color(0xFFFFD700);
        break;

      case 2:
        colorFondo = const Color(0xFFC0C0C0);
        break;

      case 3:
        colorFondo = const Color(0xFFCD7F32);
        break;

      default:
        colorFondo = Colors.grey[200]!;
        colorTexto = Colors.black54;
    }

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorFondo,
        shape: BoxShape.circle,
        boxShadow: posicion <= 3
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        '$posicion',
        style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto),
      ),
    );
  }
}

// ============================================================
// FICHA TÉCNICA DEL JUGADOR / DT
// ============================================================

void _mostrarFichaJugador(
  BuildContext context,
  Map<String, dynamic> data,
  ConfiguracionApp config,
) {
  final nombreCompleto =
      '${data['nombre'] ?? ''} '
              '${data['apellido'] ?? ''}'
          .trim();

  final dorsal = data['dorsal']?.toString() ?? '-';

  final posicion = (data['posicion'] ?? 'No definida').toString();

  final categoria = data['categoria']?.toString() ?? 'General';

  final foto = (data['foto'] ?? '').toString();

  final esDT = data['rol'] == 'DT';

  final fechaNacimiento = (data['fecha_nacimiento'] ?? 'No registrada')
      .toString();

  final piernaHabil = (data['pierna_habil'] ?? 'No definida').toString();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: esDT
                          ? const Color(0xFF283593)
                          : config.colorPrimario,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        config.rutaLogo,
                        width: 180,
                        height: 180,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ),
                  Positioned(
                    top: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: foto.isNotEmpty
                            ? CachedNetworkImageProvider(foto)
                            : null,
                        child: foto.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (!esDT)
                    Positioned(
                      top: 130,
                      right: MediaQuery.of(context).size.width * 0.25,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          dorsal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  nombreCompleto.isEmpty
                      ? 'SIN NOMBRE'
                      : nombreCompleto.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  esDT
                      ? 'DIRECTOR TÉCNICO  •  '
                            'Categoría $categoria'
                      : '$posicion  •  '
                            'Categoría $categoria',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: esDT ? Colors.indigo[800] : Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.cake, color: Colors.white70, size: 20),
                        const SizedBox(height: 5),
                        const Text(
                          'NACIMIENTO',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fechaNacimiento,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.white24),
                    if (esDT)
                      Column(
                        children: [
                          const Icon(
                            Icons.assignment_ind,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'FUNCIÓN',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            posicion.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Icon(
                            Icons.sports_soccer,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'PIERNA HÁBIL',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            piernaHabil,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
