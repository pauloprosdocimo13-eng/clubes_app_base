import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../configuracion/configuracion_app.dart';

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

  @override
  void initState() {
    super.initState();
    // 1. Inicializamos las categorías (Recibidas o Automáticas)
    if (widget.categorias.isNotEmpty) {
      _categorias = List.from(widget.categorias);
    } else {
      _categorias = _generarCategoriasAutomaticas();
    }

    // Aseguramos que "General" exista para ver todos
    if (!_categorias.contains('General')) {
      _categorias.insert(0, 'General');
    }
    _categoriaSeleccionada = _categorias.first;
  }

  List<String> _generarCategoriasAutomaticas() {
    int anioActual = DateTime.now().year;
    List<String> lista = ['General'];
    for (int i = 0; i < 8; i++) {
      lista.add((anioActual - 5 - i).toString());
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    // USAMOS DefaultTabController PARA LAS 3 PESTAÑAS
    return DefaultTabController(
      length: 3, // Plantel, Goles, Asistencias
      child: Scaffold(
        appBar: AppBar(
          title: Text("Plantel ${widget.tituloDeporte}"),
          backgroundColor: widget.config.colorPrimario,
          foregroundColor: Colors.white,
          // BARRA DE PESTAÑAS
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "PLANTEL"),
              Tab(text: "GOLES"),
              Tab(text: "ASIST"),
            ],
          ),
        ),
        body: Column(
          children: [
            // FILTRO DE CATEGORÍAS (Común para todas las pestañas)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.grey[200],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  final cat = _categorias[index];
                  final esSeleccionada = cat == _categoriaSeleccionada;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: esSeleccionada,
                      selectedColor: widget.config.colorPrimario,
                      labelStyle: TextStyle(
                        color: esSeleccionada ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _categoriaSeleccionada = cat);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            // CONTENIDO PRINCIPAL (Stream único para optimizar)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jugadores')
                    .where('deporte_id', isEqualTo: widget.deporteId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var allDocs = snapshot.data!.docs;
                  List<DocumentSnapshot> jugadoresFiltrados;

                  // Filtramos localmente por la categoría del Chip
                  if (_categoriaSeleccionada == 'General') {
                     jugadoresFiltrados = allDocs;
                  } else {
                    jugadoresFiltrados = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['categoria'].toString() == _categoriaSeleccionada;
                    }).toList();
                  }

                  if (jugadoresFiltrados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text("No hay jugadores en esta categoría", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  // AQUÍ DIVIDIMOS LAS VISTAS
                  return TabBarView(
                    children: [
                      // PESTAÑA 1: PLANTEL (Ordenado por Dorsal)
                      _ListaPlantel(jugadores: List.from(jugadoresFiltrados), config: widget.config),

                      // PESTAÑA 2: GOLEADORES (Ordenado por Goles)
                      _ListaRanking(
                        jugadores: List.from(jugadoresFiltrados), 
                        config: widget.config,
                        tipo: 'goles'
                      ),

                      // PESTAÑA 3: ASISTENCIAS (Ordenado por Asistencias)
                      _ListaRanking(
                        jugadores: List.from(jugadoresFiltrados), 
                        config: widget.config,
                        tipo: 'asistencias'
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET LISTA PLANTEL (ORDEN DORSAL) ---
class _ListaPlantel extends StatelessWidget {
  final List<DocumentSnapshot> jugadores;
  final ConfiguracionApp config;

  const _ListaPlantel({required this.jugadores, required this.config});

  @override
  Widget build(BuildContext context) {
    // Ordenar por dorsal (camiseta)
    jugadores.sort((a, b) {
      final dA = a.data() as Map<String, dynamic>;
      final dB = b.data() as Map<String, dynamic>;
      int numA = int.tryParse(dA['dorsal'].toString()) ?? 999;
      int numB = int.tryParse(dB['dorsal'].toString()) ?? 999;
      return numA.compareTo(numB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: jugadores.length,
      itemBuilder: (context, index) {
        final data = jugadores[index].data() as Map<String, dynamic>;
        final nombre = "${data['nombre']} ${data['apellido']}";
        final foto = data['foto'] ?? '';
        final dorsal = data['dorsal'] ?? 0;
        final posicion = data['posicion'] ?? 'Jugador';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: foto.isNotEmpty ? CachedNetworkImageProvider(foto) : null,
              child: foto.isEmpty ? Text(nombre[0], style: TextStyle(color: config.colorPrimario, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(posicion),
            trailing: CircleAvatar(
              backgroundColor: config.colorPrimario,
              radius: 18,
              child: Text("$dorsal", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET RANKING (GOLES O ASISTENCIAS) ---
class _ListaRanking extends StatelessWidget {
  final List<DocumentSnapshot> jugadores;
  final ConfiguracionApp config;
  final String tipo; // 'goles' o 'asistencias'

  const _ListaRanking({required this.jugadores, required this.config, required this.tipo});

  @override
  Widget build(BuildContext context) {
    // 1. Filtramos solo los que tienen > 0
    final ranking = jugadores.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      int valor = int.tryParse(data[tipo].toString()) ?? 0;
      return valor > 0;
    }).toList();

    if (ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tipo == 'goles' ? Icons.sports_soccer : Icons.hiking, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("Aún no hay $tipo registrados.", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 2. Ordenamos de Mayor a Menor
    ranking.sort((a, b) {
      final dA = a.data() as Map<String, dynamic>;
      final dB = b.data() as Map<String, dynamic>;
      int valA = int.tryParse(dA[tipo].toString()) ?? 0;
      int valB = int.tryParse(dB[tipo].toString()) ?? 0;
      return valB.compareTo(valA); // Descendente
    });

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: ranking.length,
      itemBuilder: (context, index) {
        final data = ranking[index].data() as Map<String, dynamic>;
        final nombre = "${data['nombre']} ${data['apellido']}";
        final foto = data['foto'] ?? '';
        final cantidad = int.tryParse(data[tipo].toString()) ?? 0;
        final posicionRanking = index + 1;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Medalla o Número de Posición
                _BadgePosicion(posicion: posicionRanking),
                const SizedBox(width: 10),
                // Foto
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: foto.isNotEmpty ? CachedNetworkImageProvider(foto) : null,
                  child: foto.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
              ],
            ),
            title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            // Mostramos la categoría en el subtítulo para contexto
            subtitle: Text("Cat: ${data['categoria']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tipo == 'goles' ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tipo == 'goles' ? Colors.green.withOpacity(0.5) : Colors.blue.withOpacity(0.5))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tipo == 'goles' ? Icons.sports_soccer : Icons.hiking, size: 16, color: tipo == 'goles' ? Colors.green[700] : Colors.blue[700]),
                  const SizedBox(width: 5),
                  Text(
                    "$cantidad", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: tipo == 'goles' ? Colors.green[800] : Colors.blue[800]
                    )
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

// Widget visual para el 1°, 2° y 3° puesto
class _BadgePosicion extends StatelessWidget {
  final int posicion;

  const _BadgePosicion({required this.posicion});

  @override
  Widget build(BuildContext context) {
    Color colorFondo;
    Color colorTexto = Colors.white;

    switch (posicion) {
      case 1: colorFondo = const Color(0xFFFFD700); break; // Oro
      case 2: colorFondo = const Color(0xFFC0C0C0); break; // Plata
      case 3: colorFondo = const Color(0xFFCD7F32); break; // Bronce
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
        boxShadow: posicion <= 3 ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(1, 1))] : null
      ),
      child: Text(
        "$posicion", 
        style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto)
      ),
    );
  }
}