import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaResultados extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String tituloDeporte;

  const PantallaResultados({
    super.key,
    required this.config,
    required this.deporteId,
    required this.tituloDeporte,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: Text('Resultados $tituloDeporte'),
          backgroundColor: config.colorPrimario,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Apertura'),
              Tab(text: 'Clausura'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListaPartidos(
              config: config,
              deporteId: deporteId,
              torneo: 'apertura',
            ),
            _ListaPartidos(
              config: config,
              deporteId: deporteId,
              torneo: 'clausura',
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaPartidos extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String torneo;

  const _ListaPartidos({
    required this.config,
    required this.deporteId,
    required this.torneo,
  });

  @override
  State<_ListaPartidos> createState() => _ListaPartidosState();
}

class _ListaPartidosState extends State<_ListaPartidos> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _streamLegacy;

  Future<List<Map<String, dynamic>>>? _futureCentral;

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  ConfiguracionApp get config => widget.config;

  String get deporteId => widget.deporteId;

  String get torneo => widget.torneo;

  String get _nombreClubLocal {
    if (_usaCentral) {
      final nombre = ContextoClub.nombreClub.trim();

      if (nombre.isNotEmpty) {
        return nombre;
      }
    }

    return config.nombreApp;
  }

  Widget _logoClubLocal() {
    if (_usaCentral) {
      final logoUrl = ContextoClub.logoUrlCentral.trim();

      if (logoUrl.isNotEmpty) {
        return Image.network(
          logoUrl,
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              config.rutaLogo,
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            );
          },
        );
      }
    }

    return Image.asset(
      config.rutaLogo,
      width: 56,
      height: 56,
      fit: BoxFit.contain,
    );
  }

  @override
  void initState() {
    super.initState();

    if (_usaCentral) {
      _cargarCentral();
    } else {
      _streamLegacy = FirebaseFirestore.instance
          .collection('partidos')
          .where('deporte_id', isEqualTo: deporteId)
          .where('torneo', isEqualTo: torneo)
          .snapshots();
    }
  }

  void _cargarCentral() {
    _futureCentral = ServicioContenidoPublico.cargarResultados(
      deporteId,
      torneo: torneo,
    );
  }

  void _reintentarCentral() {
    setState(() {
      _cargarCentral();
    });
  }

  void _mostrarGoleadores(
    BuildContext context,
    String categoria,
    List<String> autoresPropios,
    List<String> autoresRival,
    bool esLocal,
    String nombreRival,
  ) {
    final golesLocal = esLocal ? autoresPropios : autoresRival;

    final golesVisita = esLocal ? autoresRival : autoresPropios;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Detalles Cat. $categoria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: config.colorPrimario,
                  ),
                ),
              ),
              const Divider(height: 30),
              if (golesLocal.isEmpty && golesVisita.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No hay detalles de goleadores '
                      'para este partido.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              if (golesLocal.isNotEmpty) ...[
                Text(
                  'Goles '
                  '${esLocal ? _nombreClubLocal : nombreRival}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                ...golesLocal.map(
                  (gol) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_soccer,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gol,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],
              if (golesVisita.isNotEmpty) ...[
                Text(
                  'Goles '
                  '${!esLocal ? _nombreClubLocal : nombreRival}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                ...golesVisita.map(
                  (gol) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_soccer,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gol,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _ordenarPartidos(
    List<Map<String, dynamic>> partidos,
  ) {
    final resultado = List<Map<String, dynamic>>.from(partidos);

    resultado.sort((a, b) {
      final fechaA = a['fecha'];

      final fechaB = b['fecha'];

      if (fechaA is! Timestamp && fechaB is! Timestamp) {
        return 0;
      }

      if (fechaA is! Timestamp) {
        return 1;
      }

      if (fechaB is! Timestamp) {
        return -1;
      }

      return fechaA.compareTo(fechaB);
    });

    return resultado;
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'No hay partidos en el torneo $torneo.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _errorCentral(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar los resultados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
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

  Widget _contenidoCentral() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureCentral,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _errorCentral(snapshot.error);
        }

        final partidos = snapshot.data ?? <Map<String, dynamic>>[];

        if (partidos.isEmpty) {
          return _estadoVacio();
        }

        return _listaPartidos(partidos);
      },
    );
  }

  Widget _contenidoLegacy() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamLegacy,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Cargando resultados... '
                'Si el problema persiste, '
                'contacte al administrador.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final partidos =
            snapshot.data?.docs
                .map(
                  (doc) => <String, dynamic>{'_doc_id': doc.id, ...doc.data()},
                )
                .toList() ??
            <Map<String, dynamic>>[];

        if (partidos.isEmpty) {
          return _estadoVacio();
        }

        return _listaPartidos(partidos);
      },
    );
  }

  Widget _listaPartidos(List<Map<String, dynamic>> partidosOriginales) {
    final partidos = _ordenarPartidos(partidosOriginales);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: partidos.length,
      itemBuilder: (context, index) {
        final data = partidos[index];

        final rival = (data['rival'] ?? 'Rival').toString();

        final esLocal = data['es_local'] ?? true;

        final estado = (data['estado'] ?? 'programado').toString();

        final jornada = (data['jornada'] ?? 'Partido').toString();

        final escudoRival = (data['escudo_rival'] ?? data['escudo_url'] ?? '')
            .toString();

        String fechaTexto = '--/--';

        final fecha = data['fecha'];

        if (fecha is Timestamp) {
          final date = fecha.toDate();

          fechaTexto =
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';
        }

        final rawResultados = data['resultado'] is List
            ? data['resultado'] as List
            : data['resultados'] is List
            ? data['resultados'] as List
            : const [];

        final listaResultados = List<dynamic>.from(rawResultados);

        listaResultados.sort((a, b) {
          final categoriaA = a is Map ? (a['categoria'] ?? '').toString() : '';

          final categoriaB = b is Map ? (b['categoria'] ?? '').toString() : '';

          return categoriaA.compareTo(categoriaB);
        });

        final nombreEq1 = esLocal ? _nombreClubLocal : rival.toUpperCase();

        final nombreEq2 = esLocal ? rival.toUpperCase() : _nombreClubLocal;

        return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                color: config.colorPrimario,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      jornada.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fechaTexto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 5,
                  ),
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  iconColor: config.colorPrimario,
                  collapsedIconColor: Colors.grey[400],
                  trailing: const SizedBox.shrink(),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              radius: 28,
                              child: esLocal
                                  ? ClipOval(child: _logoClubLocal())
                                  : escudoRival.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        escudoRival,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Text(
                                                nombreEq1.isNotEmpty
                                                    ? nombreEq1.substring(0, 1)
                                                    : '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                  fontSize: 24,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Text(
                                      nombreEq1.isNotEmpty
                                          ? nombreEq1.substring(0, 1)
                                          : '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                        fontSize: 24,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nombreEq1,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: estado == 'programado'
                            ? Column(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: Colors.orange[800],
                                    size: 28,
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'PROG.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'FINAL',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Ver detalles',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: config.colorPrimario,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: config.colorPrimario,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              radius: 28,
                              child: !esLocal
                                  ? ClipOval(child: _logoClubLocal())
                                  : escudoRival.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        escudoRival,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Text(
                                                nombreEq2.isNotEmpty
                                                    ? nombreEq2.substring(0, 1)
                                                    : '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                  fontSize: 24,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Text(
                                      nombreEq2.isNotEmpty
                                          ? nombreEq2.substring(0, 1)
                                          : '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                        fontSize: 24,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nombreEq2,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      color: Colors.grey[50],
                      padding: const EdgeInsets.only(
                        left: 15,
                        right: 15,
                        bottom: 20,
                        top: 10,
                      ),
                      child: estado == 'programado'
                          ? Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_soccer,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Esperando resultados...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: listaResultados.length,
                              itemBuilder: (context, i) {
                                if (listaResultados[i] is! Map) {
                                  return const SizedBox();
                                }

                                final resultado = Map<String, dynamic>.from(
                                  listaResultados[i] as Map,
                                );

                                String categoria =
                                    (resultado['categoria'] ?? '-').toString();

                                if (RegExp(r'^[0-9]+$').hasMatch(categoria)) {
                                  categoria = 'Cat. $categoria';
                                }

                                final golesPropios =
                                    int.tryParse(
                                      (resultado['goles_propios'] ?? 0)
                                          .toString(),
                                    ) ??
                                    0;

                                final golesRival =
                                    int.tryParse(
                                      (resultado['goles_rival'] ?? 0)
                                          .toString(),
                                    ) ??
                                    0;

                                final autoresPropios = List<String>.from(
                                  resultado['autores_propios'] ?? const [],
                                );

                                final autoresRival = List<String>.from(
                                  resultado['autores_rival'] ?? const [],
                                );

                                Color colorFondo = Colors.grey[200]!;

                                Color colorTexto = Colors.black87;

                                if (golesPropios > golesRival) {
                                  colorFondo = Colors.green[100]!;
                                  colorTexto = Colors.green[800]!;
                                }

                                if (golesPropios < golesRival) {
                                  colorFondo = Colors.red[100]!;
                                  colorTexto = Colors.red[800]!;
                                }

                                if (golesPropios == golesRival &&
                                    (golesPropios > 0 || golesRival > 0)) {
                                  colorFondo = Colors.blue[50]!;
                                  colorTexto = Colors.blue[800]!;
                                }

                                final golesIzq = esLocal
                                    ? golesPropios
                                    : golesRival;

                                final golesDer = esLocal
                                    ? golesRival
                                    : golesPropios;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      _mostrarGoleadores(
                                        context,
                                        categoria,
                                        autoresPropios,
                                        autoresRival,
                                        esLocal,
                                        rival,
                                      );
                                    },
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        color: colorFondo,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colorTexto.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            categoria,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$golesIzq - $golesDer',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorTexto,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _usaCentral ? _contenidoCentral() : _contenidoLegacy();
  }
}
