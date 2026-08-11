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
  
  // VARIABLE CLAVE: Acá guardamos el stream para optimizar lecturas
  late Stream<QuerySnapshot> _streamJugadores;

  @override
  void initState() {
    super.initState();
    // 1. Inicializamos las categorías
    if (widget.categorias.isNotEmpty) {
      _categorias = List.from(widget.categorias);
    } else {
      _categorias = _generarCategoriasAutomaticas();
    }

    if (!_categorias.contains('General')) {
      _categorias.insert(0, 'General');
    }
    _categoriaSeleccionada = _categorias.first;

    // 2. INICIALIZAMOS EL STREAM UNA SOLA VEZ ACÁ
    _streamJugadores = FirebaseFirestore.instance
        .collection('jugadores')
        .where('deporte_id', isEqualTo: widget.deporteId)
        .snapshots();
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
    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        appBar: AppBar(
          title: Text("Plantel ${widget.tituloDeporte}"),
          backgroundColor: widget.config.colorPrimario,
          foregroundColor: Colors.white,
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
            // FILTRO DE CATEGORÍAS 
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

            // CONTENIDO PRINCIPAL (Usando el Stream optimizado)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _streamJugadores,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

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
                          Icon(
                            Icons.person_off,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "No hay registros en esta categoría",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      // PESTAÑA 1: PLANTEL 
                      _ListaPlantel(
                        jugadores: List.from(jugadoresFiltrados),
                        config: widget.config,
                      ),

                      // PESTAÑA 2: GOLEADORES 
                      _ListaRanking(
                        jugadores: List.from(jugadoresFiltrados),
                        config: widget.config,
                        tipo: 'goles',
                      ),

                      // PESTAÑA 3: ASISTENCIAS 
                      _ListaRanking(
                        jugadores: List.from(jugadoresFiltrados),
                        config: widget.config,
                        tipo: 'asistencias',
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

// --- WIDGET LISTA PLANTEL ---
class _ListaPlantel extends StatelessWidget {
  final List<DocumentSnapshot> jugadores;
  final ConfiguracionApp config;

  const _ListaPlantel({required this.jugadores, required this.config});

  @override
  Widget build(BuildContext context) {
    // Ordenar: DTs primero, luego por dorsal
    jugadores.sort((a, b) {
      final dA = a.data() as Map<String, dynamic>;
      final dB = b.data() as Map<String, dynamic>;
      
      String rolA = (dA['rol'] ?? 'Jugador').toString();
      String rolB = (dB['rol'] ?? 'Jugador').toString();
      
      if (rolA == 'DT' && rolB != 'DT') return -1;
      if (rolA != 'DT' && rolB == 'DT') return 1;

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
        final esDT = data['rol'] == 'DT';

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
                      nombre[0],
                      style: TextStyle(
                        color: esDT ? Colors.indigo : config.colorPrimario,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: esDT 
                ? const Text(
                    "DIRECTOR TÉCNICO", 
                    style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)
                  )
                : Text(posicion),
            trailing: esDT 
                ? null 
                : CircleAvatar(
                    backgroundColor: config.colorPrimario,
                    radius: 18,
                    child: Text(
                      "$dorsal",
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

// --- WIDGET RANKING (GOLES O ASISTENCIAS) ---
class _ListaRanking extends StatelessWidget {
  final List<DocumentSnapshot> jugadores;
  final ConfiguracionApp config;
  final String tipo; // 'goles' o 'asistencias'

  const _ListaRanking({
    required this.jugadores,
    required this.config,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Filtramos excluyendo DTs y buscando valores > 0
    final ranking = jugadores.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['rol'] == 'DT') return false; // Excluimos a los DTs

      int valor = int.tryParse(data[tipo].toString()) ?? 0;
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
              "Aún no hay $tipo registrados.",
              style: const TextStyle(color: Colors.grey),
            ),
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
      return valB.compareTo(valA); 
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
              nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Cat: ${data['categoria']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tipo == 'goles' ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tipo == 'goles'
                      ? Colors.green.withOpacity(0.5)
                      : Colors.blue.withOpacity(0.5),
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
                    "$cantidad",
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

// Widget visual para el 1°, 2° y 3° puesto
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
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        "$posicion",
        style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto),
      ),
    );
  }
}


// ============================================================================
// FICHA TÉCNICA DEL JUGADOR O DT
// ============================================================================
void _mostrarFichaJugador(BuildContext context, Map<String, dynamic> data, ConfiguracionApp config) {
  final nombreCompleto = "${data['nombre']} ${data['apellido']}";
  final dorsal = data['dorsal']?.toString() ?? '-';
  final posicion = data['posicion'] ?? 'No definida';
  final categoria = data['categoria']?.toString() ?? 'General';
  final foto = data['foto'] ?? '';
  final esDT = data['rol'] == 'DT';
  
  final fechaNacimiento = data['fecha_nacimiento'] ?? 'No registrada';
  final piernaHabil = data['pierna_habil'] ?? 'No definida';

  showDialog(
    context: context,
    builder: (BuildContext context) {
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
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- PARTE SUPERIOR (FOTO, ESCUDO Y COLORES) ---
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: esDT ? const Color(0xFF283593) : const Color(0xFFD32F2F), // Azul para DT, Rojo para Jugador
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
                      onPressed: () => Navigator.of(context).pop(),
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
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: foto.isNotEmpty
                            ? CachedNetworkImageProvider(foto)
                            : null,
                        child: foto.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                  // Número de camiseta (Solo visible para Jugadores)
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

              // --- NOMBRE DEL INTEGRANTE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  nombreCompleto.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // Posición y Categoría
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  esDT 
                      ? "DIRECTOR TÉCNICO  •  Categoría $categoria" 
                      : "$posicion  •  Categoría $categoria",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: esDT ? Colors.indigo[800] : Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // --- PARTE INFERIOR (DATOS TÉCNICOS EN FONDO NEGRO) ---
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
                    // Columna 1: Fecha de Nacimiento
                    Column(
                      children: [
                        const Icon(Icons.cake, color: Colors.white70, size: 20),
                        const SizedBox(height: 5),
                        const Text(
                          "NACIMIENTO",
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fechaNacimiento,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    // Línea divisoria
                    Container(height: 40, width: 1, color: Colors.white24),
                    
                    // Columna 2: Pierna Hábil (O Función si es DT)
                    if (esDT)
                      Column(
                        children: [
                          const Icon(Icons.assignment_ind, color: Colors.white70, size: 20),
                          const SizedBox(height: 5),
                          const Text(
                            "FUNCIÓN",
                            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            posicion.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Icon(Icons.sports_soccer, color: Colors.white70, size: 20),
                          const SizedBox(height: 5),
                          const Text(
                            "PIERNA HÁBIL",
                            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            piernaHabil,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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