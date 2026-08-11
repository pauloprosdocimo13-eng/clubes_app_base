import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

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
          title: Text("Resultados $tituloDeporte"),
          backgroundColor: config.colorPrimario,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: "Apertura"),
              Tab(text: "Clausura"),
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

class _ListaPartidos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String torneo;

  const _ListaPartidos({
    required this.config,
    required this.deporteId,
    required this.torneo,
  });

  void _mostrarGoleadores(
    BuildContext context,
    String cat,
    List<String> autoresPropios,
    List<String> autoresRival,
    bool esLocal,
    String nombreRival,
  ) {
    List<String> golesLocal = esLocal ? autoresPropios : autoresRival;
    List<String> golesVisita = esLocal ? autoresRival : autoresPropios;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Detalles Cat. $cat",
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
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No hay detalles de goleadores para este partido.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

              if (golesLocal.isNotEmpty) ...[
                Text(
                  "Goles ${esLocal ? config.nombreApp : nombreRival}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                ...golesLocal.map(
                  (g) => Padding(
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
                          child: Text(g, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              if (golesVisita.isNotEmpty) ...[
                Text(
                  "Goles ${!esLocal ? config.nombreApp : nombreRival}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                ...golesVisita.map(
                  (g) => Padding(
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
                          child: Text(g, style: const TextStyle(fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partidos')
          .where('deporte_id', isEqualTo: deporteId)
          .where('torneo', isEqualTo: torneo)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Cargando resultados... Si el problema persiste, contacte al administrador.",
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 60,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 10),
                Text(
                  "No hay partidos en el torneo $torneo.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final partidos = snapshot.data!.docs.toList();
        partidos.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp? tA = dataA['fecha'];
          Timestamp? tB = dataB['fecha'];
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tA.compareTo(tB);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: partidos.length,
          itemBuilder: (context, index) {
            final data = partidos[index].data() as Map<String, dynamic>;

            final String rival = data['rival'] ?? 'Rival';
            final bool esLocal = data['es_local'] ?? true;
            final String estado = data['estado'] ?? 'programado';
            final String jornada = data['jornada'] ?? 'Partido';

            // --- NUEVO: Extraemos la URL del escudo del rival ---
            final String escudoRival =
                data['escudo_rival'] ?? data['escudo_url'] ?? '';

            String fechaTexto = "--/--";
            if (data['fecha'] != null) {
              Timestamp ts = data['fecha'];
              DateTime dt = ts.toDate();
              fechaTexto =
                  "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
            }

            List<dynamic> listaResultados = [];
            if (data.containsKey('resultado')) {
              listaResultados = data['resultado'];
            } else if (data.containsKey('resultados')) {
              listaResultados = data['resultados'];
            }
            try {
              listaResultados.sort(
                (a, b) => (a['categoria'] ?? '').toString().compareTo(
                  (b['categoria'] ?? '').toString(),
                ),
              );
            } catch (e) {
              print(e);
            }

            String nombreEq1 = esLocal ? config.nombreApp : rival.toUpperCase();
            String nombreEq2 = esLocal ? rival.toUpperCase() : config.nombreApp;

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
                  // --- FRANJA SUPERIOR ---
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

                  // --- PARTE BLANCA DESPLEGABLE ---
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
                          // --- EQUIPO 1 (IZQUIERDA) ---
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  radius: 28,
                                  backgroundImage: esLocal
                                      ? AssetImage(config.rutaLogo)
                                            as ImageProvider
                                      : (escudoRival.isNotEmpty
                                            ? NetworkImage(escudoRival)
                                                  as ImageProvider
                                            : null),
                                  child: (!esLocal && escudoRival.isEmpty)
                                      ? Text(
                                          nombreEq1.isNotEmpty
                                              ? nombreEq1.substring(0, 1)
                                              : '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                            fontSize: 24,
                                          ),
                                        )
                                      : null,
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

                          // --- ESTADO O RESULTADO CENTRAL ---
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
                                        "PROG.",
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(
                                                0.4,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          "FINAL",
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Ver detalles",
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

                          // --- EQUIPO 2 (DERECHA) ---
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  radius: 28,
                                  backgroundImage: !esLocal
                                      ? AssetImage(config.rutaLogo)
                                            as ImageProvider
                                      : (escudoRival.isNotEmpty
                                            ? NetworkImage(escudoRival)
                                                  as ImageProvider
                                            : null),
                                  child: (esLocal && escudoRival.isEmpty)
                                      ? Text(
                                          nombreEq2.isNotEmpty
                                              ? nombreEq2.substring(0, 1)
                                              : '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                            fontSize: 24,
                                          ),
                                        )
                                      : null,
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
                                  padding: const EdgeInsets.all(15.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_soccer,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Esperando resultados...",
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
                                    if (listaResultados[i] is! Map)
                                      return const SizedBox();
                                    final resultado =
                                        listaResultados[i]
                                            as Map<String, dynamic>;

                                    String cat =
                                        resultado['categoria']?.toString() ??
                                        '-';
                                    if (RegExp(r'^[0-9]+$').hasMatch(cat))
                                      cat = "Cat. $cat";

                                    final int gProp =
                                        int.tryParse(
                                          resultado['goles_propios'].toString(),
                                        ) ??
                                        0;
                                    final int gRival =
                                        int.tryParse(
                                          resultado['goles_rival'].toString(),
                                        ) ??
                                        0;

                                    List<String> autoresPropios =
                                        List<String>.from(
                                          resultado['autores_propios'] ?? [],
                                        );
                                    List<String> autoresRival =
                                        List<String>.from(
                                          resultado['autores_rival'] ?? [],
                                        );

                                    Color colorFondo = Colors.grey[200]!;
                                    Color colorTexto = Colors.black87;
                                    if (gProp > gRival) {
                                      colorFondo = Colors.green[100]!;
                                      colorTexto = Colors.green[800]!;
                                    }
                                    if (gProp < gRival) {
                                      colorFondo = Colors.red[100]!;
                                      colorTexto = Colors.red[800]!;
                                    }
                                    if (gProp == gRival &&
                                        (gProp > 0 || gRival > 0)) {
                                      colorFondo = Colors.blue[50]!;
                                      colorTexto = Colors.blue[800]!;
                                    }

                                    int golesIzq = esLocal ? gProp : gRival;
                                    int golesDer = esLocal ? gRival : gProp;

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _mostrarGoleadores(
                                          context,
                                          cat,
                                          autoresPropios,
                                          autoresRival,
                                          esLocal,
                                          rival,
                                        ),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            color: colorFondo,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: colorTexto.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Text(
                                                cat,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "$golesIzq - $golesDer",
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
      },
    );
  }
}
