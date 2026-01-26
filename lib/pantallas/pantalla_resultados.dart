import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

class PantallaResultados extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String tituloDeporte; // <--- NUEVO CAMPO

  const PantallaResultados({
    super.key,
    required this.config,
    required this.deporteId,
    required this.tituloDeporte, // <--- LO PEDIMOS AQUÍ
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // AHORA USAMOS EL TÍTULO BONITO
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
            _ListaPartidos(config: config, deporteId: deporteId, torneo: 'apertura'),
            _ListaPartidos(config: config, deporteId: deporteId, torneo: 'clausura'),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET AUXILIAR (El resto sigue igual) ---
class _ListaPartidos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String torneo;

  const _ListaPartidos({
    required this.config,
    required this.deporteId,
    required this.torneo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partidos')
          .where('deporte_id', isEqualTo: deporteId)
          .where('torneo', isEqualTo: torneo)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Falta crear índice en Firebase o error de conexión.", style: TextStyle(color: Colors.grey[600])),
              )
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  "No hay partidos en el $torneo.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final partidos = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: partidos.length,
          itemBuilder: (context, index) {
            final data = partidos[index].data() as Map<String, dynamic>;

            final String rival = data['rival'] ?? 'Rival';
            final bool esLocal = data['es_local'] ?? true;
            final String estado = data['estado'] ?? 'programado';

            String fechaTexto = "--/--";
            if (data['fecha'] != null) {
              Timestamp ts = data['fecha'];
              DateTime dt = ts.toDate();
              fechaTexto = "${dt.day}/${dt.month}/${dt.year}";
            }

            List<dynamic> listaResultados = [];
            if (data.containsKey('resultado')) {
              listaResultados = data['resultado'];
            } else if (data.containsKey('resultados')) {
              listaResultados = data['resultados'];
            }
            try {
              listaResultados.sort((a, b) => (a['categoria'] ?? '').toString().compareTo((b['categoria'] ?? '').toString()));
            } catch (e) { print(e); }

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: Border.all(color: Colors.transparent),
                collapsedShape: Border.all(color: Colors.transparent),
                tilePadding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                collapsedBackgroundColor: config.colorPrimario,
                iconColor: config.colorPrimario,
                collapsedIconColor: Colors.white,

                title: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              esLocal ? Icons.home : Icons.directions_bus,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esLocal ? "LOCAL" : "VISITANTE",
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                rival.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        fechaTexto,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                children: [
                  estado == 'programado'
                      ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, color: Colors.orange[800]),
                        const SizedBox(width: 10),
                        Text("PARTIDO PROGRAMADO", style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold))
                      ],
                    ),
                  )
                      : Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: listaResultados.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, i) {
                          if (listaResultados[i] is! Map) return const SizedBox();
                          final resultado = listaResultados[i] as Map<String, dynamic>;
                          final String cat = resultado['categoria']?.toString() ?? '-';
                          final int gProp = int.tryParse(resultado['goles_propios'].toString()) ?? 0;
                          final int gRival = int.tryParse(resultado['goles_rival'].toString()) ?? 0;

                          Color colorResultado = Colors.grey;
                          if (gProp > gRival) colorResultado = Colors.green;
                          if (gProp < gRival) colorResultado = Colors.red;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Categoría $cat", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text("$gProp", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorResultado)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("-", style: TextStyle(color: Colors.grey))),
                                    Text("$gRival", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
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