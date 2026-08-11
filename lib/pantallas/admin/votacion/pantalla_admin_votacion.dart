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
  List<Map<String, dynamic>> _deportesDisponibles = [];
  String? _deporteSeleccionadoId;
  bool _cargandoConfig = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  // 1. Cargamos los Deportes y sus Categorías desde Firebase
  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final menu = List.from(data['menu_deportes'] ?? []);

        setState(() {
          _deportesDisponibles = menu
              .map(
                (e) => {
                  'id': e['id'],
                  'titulo': e['titulo'],
                  'categorias': List<String>.from(e['categorias'] ?? []),
                },
              )
              .toList();
          _cargandoConfig = false;
        });
      }
    } catch (e) {
      print("Error config: $e");
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }

  // --- LA MAGIA: GENERAR TODA LA JORNADA ---
  Future<void> _generarJornadaCompleta(String tituloRival) async {
    if (_deporteSeleccionadoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecciona un Deporte")));
      return;
    }

    Navigator.pop(context); // Cierra el diálogo de configuración

    // Mostramos cartel de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;

      // 1. Obtenemos las categorías de ese deporte
      final deporte = _deportesDisponibles.firstWhere(
        (d) => d['id'] == _deporteSeleccionadoId,
      );
      List<String> categorias = deporte['categorias'];

      if (categorias.isEmpty) {
        Navigator.pop(context); // Cierra el loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ese deporte no tiene categorías configuradas."),
          ),
        );
        return;
      }

      int votacionesCreadas = 0;

      // 2. Iteramos sobre cada categoría
      for (String cat in categorias) {
        // A. Buscamos los jugadores de ESA categoría puntual
        final queryJugadores = await db
            .collection('jugadores')
            .where('deporte_id', isEqualTo: _deporteSeleccionadoId)
            .where('categoria', isEqualTo: cat)
            .get();

        // Si no hay jugadores, salteamos esta categoría y vamos a la siguiente
        if (queryJugadores.docs.isEmpty) continue;

        // B. Armamos la lista de candidatos
        List<Map<String, dynamic>> candidatos = [];
        for (var doc in queryJugadores.docs) {
          final data = doc.data();
          candidatos.add({
            'id_jugador': doc.id,
            'nombre': "${data['nombre']} ${data['apellido']}",
            'foto': data['foto'] ?? '',
            'dorsal': data['dorsal'] ?? '',
            'votos': 0,
          });
        }

        // C. Creamos la votación en Firebase
        await db.collection('votaciones').add({
          'titulo':
              "Figura vs $tituloRival ($cat)", // Ej: Figura vs Morón (2014)
          'deporte_id': _deporteSeleccionadoId,
          'categoria': cat,
          'creada_el': FieldValue.serverTimestamp(),
          'estado': 'ABIERTA',
          'total_votos': 0,
          'candidatos': candidatos,
        });

        votacionesCreadas++;
      }

      Navigator.pop(context); // Cierra el loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "¡Éxito! Se generaron $votacionesCreadas votaciones para la jornada.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Cierra el loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // DIÁLOGO DE CREACIÓN (MÁS SIMPLE AHORA)
  void _mostrarDialogoCreacion() {
    final _tituloController = TextEditingController();

    setState(() {
      _deporteSeleccionadoId = null;
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Nueva Jornada de Votaciones"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.blue[50],
                      child: const Text(
                        "Esto creará automáticamente una votación por cada categoría del deporte seleccionado.",
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: "Nombre del Rival (ej: Morón)",
                      ),
                    ),
                    const SizedBox(height: 15),

                    // DROPDOWN DEPORTE
                    DropdownButtonFormField<String>(
                      value: _deporteSeleccionadoId,
                      hint: const Text("Seleccionar Disciplina"),
                      items: _deportesDisponibles.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'].toString(),
                          child: Text(d['titulo'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          _deporteSeleccionadoId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (_tituloController.text.isNotEmpty &&
                        _deporteSeleccionadoId != null) {
                      _generarJornadaCompleta(_tituloController.text.trim());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Completá todos los campos."),
                        ),
                      );
                    }
                  },
                  child: const Text("GENERAR JORNADA"),
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
              label: const Text("Generar Jornada"),
              icon: const Icon(Icons.auto_awesome),
              backgroundColor: widget.config.colorPrimario,
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('votaciones')
            .orderBy('creada_el', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty)
            return const Center(child: Text("No hay votaciones creadas."));

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
                    backgroundColor: estado == 'ABIERTA'
                        ? Colors.green
                        : Colors.grey,
                    child: const Icon(Icons.star, color: Colors.white),
                  ),
                  title: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Cat: $cat | Votos: $total"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Switch para Abrir/Cerrar rápido
                      Switch(
                        value: estado == 'ABIERTA',
                        activeColor: Colors.green,
                        onChanged: (val) {
                          FirebaseFirestore.instance
                              .collection('votaciones')
                              .doc(id)
                              .update({'estado': val ? 'ABIERTA' : 'CERRADA'});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text("Eliminar Votación"),
                              content: const Text(
                                "Se perderán los resultados.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('votaciones')
                                        .doc(id)
                                        .delete();
                                    Navigator.pop(c);
                                  },
                                  child: const Text(
                                    "Eliminar",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
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

  const _PantallaDetalleResultados({
    required this.config,
    required this.votacionId,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('votaciones')
            .doc(votacionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          List candidatos = List.from(data['candidatos'] ?? []);

          // Ordenamos por votos
          candidatos.sort(
            (a, b) => (b['votos'] ?? 0).compareTo(a['votos'] ?? 0),
          );

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: candidatos.length,
            itemBuilder: (context, index) {
              final c = candidatos[index];
              return Card(
                child: ListTile(
                  leading: Text(
                    "#${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  title: Text(c['nombre']),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: config.colorPrimario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${c['votos']} votos",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: config.colorPrimario,
                      ),
                    ),
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
