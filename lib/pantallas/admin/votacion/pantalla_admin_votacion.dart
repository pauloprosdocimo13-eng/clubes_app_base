import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../configuracion/configuracion_app.dart';

class PantallaAdminVotacion extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminVotacion({super.key, required this.config});

  @override
  State<PantallaAdminVotacion> createState() => _PantallaAdminVotacionState();
}

class _PantallaAdminVotacionState extends State<PantallaAdminVotacion> {
  // Variables para el formulario de creación
  List<Map<String, dynamic>> _deportesDisponibles = [];
  String? _deporteSeleccionadoId;
  String? _categoriaSeleccionada;
  List<String> _categoriasDisponibles = [];
  bool _cargandoConfig = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  // 1. Cargamos las Tiras y Categorías desde Firebase
  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menu = List.from(data['menu_deportes'] ?? []);

        setState(() {
          _deportesDisponibles = menu.map((e) => {
            'id': e['id'],
            'titulo': e['titulo'],
            'categorias': List<String>.from(e['categorias'] ?? [])
          }).toList();
          _cargandoConfig = false;
        });
      }
    } catch (e) {
      print("Error config: $e");
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }

  // 2. Al elegir deporte, actualizamos las categorías
  void _onDeporteChanged(String? nuevoId) {
    if (nuevoId == null) return;
    final deporte = _deportesDisponibles.firstWhere((d) => d['id'] == nuevoId);
    setState(() {
      _deporteSeleccionadoId = nuevoId;
      _categoriasDisponibles = deporte['categorias'];
      _categoriaSeleccionada = null; // Resetear categoría
    });
  }

  // 3. Crear la Votación Automática
  void _crearVotacionAutomatica(String titulo) async {
    if (_deporteSeleccionadoId == null || _categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona Deporte y Categoría")));
      return;
    }

    Navigator.pop(context); // Cerrar diálogo
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Buscando jugadores y creando votación...")));

    try {
      // A. Buscamos los jugadores en la BD que coincidan con el filtro
      final queryJugadores = await FirebaseFirestore.instance
          .collection('jugadores')
          .where('deporte_id', isEqualTo: _deporteSeleccionadoId)
          .where('categoria', isEqualTo: _categoriaSeleccionada)
          .get();

      if (queryJugadores.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: No hay jugadores cargados en esa categoría.")));
        return;
      }

      // B. Armamos la lista de candidatos
      List<Map<String, dynamic>> candidatos = [];
      for (var doc in queryJugadores.docs) {
        final data = doc.data();
        candidatos.add({
          'id_jugador': doc.id,
          'nombre': "${data['nombre']} ${data['apellido']}",
          'foto': data['foto'] ?? '', // Si tiene foto la usamos
          'dorsal': data['dorsal'] ?? '',
          'votos': 0,
        });
      }

      // C. Creamos la votación con los candidatos ya cargados
      await FirebaseFirestore.instance.collection('votaciones').add({
        'titulo': "$titulo ($_categoriaSeleccionada)", // Ej: Figura vs Morón (2014)
        'deporte_id': _deporteSeleccionadoId,
        'categoria': _categoriaSeleccionada,
        'creada_el': FieldValue.serverTimestamp(),
        'estado': 'ABIERTA',
        'total_votos': 0,
        'candidatos': candidatos, // ¡MAGIA! Todos cargados
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Votación creada exitosamente!")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // DIÁLOGO DE CREACIÓN
  void _mostrarDialogoCreacion() {
    final _tituloController = TextEditingController();

    // Reseteamos selección temporalmente para obligar a elegir
    setState(() {
      _deporteSeleccionadoId = null;
      _categoriaSeleccionada = null;
      _categoriasDisponibles = [];
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Necesario para actualizar dropdowns dentro del Dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Nueva Votación por Categoría"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(labelText: "Título Rival (ej: vs Morón)"),
                    ),
                    const SizedBox(height: 15),

                    // DROPDOWN DEPORTE
                    DropdownButtonFormField<String>(
                      value: _deporteSeleccionadoId,
                      hint: const Text("Seleccionar Tira"),
                      items: _deportesDisponibles.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'].toString(),
                          child: Text(d['titulo'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          // Actualizamos lógica local del diálogo
                          final deporte = _deportesDisponibles.firstWhere((d) => d['id'] == val);
                          _deporteSeleccionadoId = val;
                          _categoriasDisponibles = deporte['categorias'];
                          _categoriaSeleccionada = null;
                        });
                        // Actualizamos lógica global por si acaso
                        _onDeporteChanged(val);
                      },
                    ),
                    const SizedBox(height: 15),

                    // DROPDOWN CATEGORÍA
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      hint: const Text("Seleccionar Categoría"),
                      items: _categoriasDisponibles.map((c) {
                        return DropdownMenuItem<String>(value: c, child: Text("Categoría $c"));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => _categoriaSeleccionada = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
                ElevatedButton(
                  onPressed: () {
                    if (_tituloController.text.isNotEmpty) {
                      _crearVotacionAutomatica(_tituloController.text);
                    }
                  },
                  child: const Text("CREAR AUTOMÁTICO"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Votaciones"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _cargandoConfig
          ? null
          : FloatingActionButton.extended(
        onPressed: _mostrarDialogoCreacion,
        label: const Text("Nueva Fecha"),
        icon: const Icon(Icons.add_task),
        backgroundColor: widget.config.colorPrimario,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('votaciones')
            .orderBy('creada_el', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("No hay votaciones creadas."));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final estado = data['estado'] ?? 'CERRADA';
              final total = data['total_votos'] ?? 0;
              final cat = data['categoria'] ?? 'General';
              final titulo = data['titulo'] ?? 'Sin Título';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estado == 'ABIERTA' ? Colors.green : Colors.grey,
                    child: const Icon(Icons.star, color: Colors.white),
                  ),
                  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Cat: $cat | Votos: $total"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Switch para Abrir/Cerrar rápido
                      Switch(
                        value: estado == 'ABIERTA',
                        activeColor: Colors.green,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('votaciones').doc(id).update({
                            'estado': val ? 'ABIERTA' : 'CERRADA'
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text("Eliminar Votación"),
                                content: const Text("Se perderán los resultados."),
                                actions: [
                                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancelar")),
                                  TextButton(onPressed: () {
                                    FirebaseFirestore.instance.collection('votaciones').doc(id).delete();
                                    Navigator.pop(c);
                                  }, child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
                                ],
                              )
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // Ver detalle (Ranking)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _PantallaDetalleResultados(
                          config: widget.config,
                          votacionId: id,
                          titulo: titulo,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- PANTALLA DE RESULTADOS (SOLO LECTURA) ---
class _PantallaDetalleResultados extends StatelessWidget {
  final ConfiguracionApp config;
  final String votacionId;
  final String titulo;

  const _PantallaDetalleResultados({required this.config, required this.votacionId, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), backgroundColor: config.colorPrimario),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('votaciones').doc(votacionId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          List candidatos = List.from(data['candidatos'] ?? []);

          // Ordenamos por votos
          candidatos.sort((a, b) => (b['votos'] ?? 0).compareTo(a['votos'] ?? 0));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: candidatos.length,
            itemBuilder: (context, index) {
              final c = candidatos[index];
              return Card(
                child: ListTile(
                  leading: Text("#${index+1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  title: Text(c['nombre']),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: config.colorPrimario.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text("${c['votos']} votos", style: TextStyle(fontWeight: FontWeight.bold, color: config.colorPrimario)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}