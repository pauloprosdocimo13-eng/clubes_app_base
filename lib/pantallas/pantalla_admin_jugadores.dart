import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_jugador.dart';

class PantallaAdminJugadores extends StatefulWidget {
  final ConfiguracionApp config;
  final String? deporteId;

  const PantallaAdminJugadores({
    super.key,
    required this.config,
    this.deporteId,
  });

  @override
  State<PantallaAdminJugadores> createState() => _PantallaAdminJugadoresState();
}

class _PantallaAdminJugadoresState extends State<PantallaAdminJugadores> {
  String? _tiraSeleccionadaId;
  List<Map<String, dynamic>> _tirasDisponibles = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.deporteId != null) {
      _tiraSeleccionadaId = widget.deporteId;
    }
    _cargarTiras();
  }

  Future<void> _cargarTiras() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menu = List.from(data['menu_deportes'] ?? []);
        setState(() {
          _tirasDisponibles = menu.map((e) => e as Map<String, dynamic>).toList();
          if (_tiraSeleccionadaId == null && _tirasDisponibles.isNotEmpty) {
            _tiraSeleccionadaId = _tirasDisponibles.first['id'];
          }
        });
      }
    } catch (e) {
      print("Error cargando tiras: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irAFormulario({String? jugadorId}) async {
    if (_tiraSeleccionadaId == null && jugadorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona una Tira/Deporte primero")));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaAdminFormularioJugador(
          config: widget.config,
          deporteId: _tiraSeleccionadaId ?? '',
          jugadorId: jugadorId,
        ),
      ),
    );
  }

  void _borrarJugador(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar Jugador?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('jugadores').doc(id).delete();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("BORRAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Plantel"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.config.colorPrimario,
        onPressed: () => _irAFormulario(),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. SELECTOR DE TIRA
          if (_tirasDisponibles.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              color: Colors.grey[100],
              child: DropdownButtonFormField<String>(
                value: _tiraSeleccionadaId,
                decoration: const InputDecoration(
                  labelText: "Filtrar por Tira / Deporte",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
                items: _tirasDisponibles.map((t) {
                  return DropdownMenuItem<String>(
                    value: t['id'],
                    child: Text(t['titulo']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _tiraSeleccionadaId = val);
                },
              ),
            ),

          // 2. LISTA DE JUGADORES (AGRUPADA POR CATEGORÍA)
          Expanded(
            child: _tiraSeleccionadaId == null
                ? const Center(child: Text("Cargando deportes..."))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('jugadores')
                        .where('deporte_id', isEqualTo: _tiraSeleccionadaId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              const Text("No hay jugadores cargados en esta tira."),
                            ],
                          ),
                        );
                      }

                      // --- ORDENAMIENTO DOBLE ---
                      // 1. Primero por Categoría (Descendente: 2015, 2014...)
                      // 2. Luego por Apellido (Ascendente: A-Z)
                      docs.sort((a, b) {
                        final dA = a.data() as Map<String, dynamic>;
                        final dB = b.data() as Map<String, dynamic>;
                        
                        String catA = (dA['categoria'] ?? '').toString();
                        String catB = (dB['categoria'] ?? '').toString();
                        
                        // Comparamos categorías (Invertido para que 2015 aparezca antes que 2014 si es número, 
                        // o según prefieras. String descendente suele funcionar bien para años recientes)
                        int compareCat = catB.compareTo(catA); 
                        if (compareCat != 0) return compareCat;

                        // Si es la misma categoría, ordenamos por Apellido
                        return (dA['apellido'] ?? '').toString().compareTo(dB['apellido'] ?? '');
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Espacio para el botón flotante
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final id = docs[index].id;
                          
                          // --- LÓGICA DE AGRUPACIÓN ---
                          bool mostrarHeader = false;
                          if (index == 0) {
                            mostrarHeader = true; // El primero siempre lleva título
                          } else {
                            final dataAnterior = docs[index - 1].data() as Map<String, dynamic>;
                            if (data['categoria'].toString() != dataAnterior['categoria'].toString()) {
                              mostrarHeader = true; // Si cambió la categoría, ponemos título
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADER DE CATEGORÍA
                              if (mostrarHeader)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  margin: const EdgeInsets.only(top: 10, bottom: 5),
                                  color: Colors.grey[300],
                                  child: Text(
                                    "CATEGORÍA ${data['categoria']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),

                              // TARJETA DEL JUGADOR
                              Card(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: (data['foto'] != null && data['foto'] != '')
                                        ? NetworkImage(data['foto'])
                                        : null,
                                    child: (data['foto'] == null || data['foto'] == '')
                                        ? Text(data['nombre'][0], style: TextStyle(color: widget.config.colorPrimario, fontWeight: FontWeight.bold)) 
                                        : null,
                                  ),
                                  title: Text(
                                    "${data['apellido']} ${data['nombre']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      if ((data['goles'] ?? 0) > 0) ...[
                                        const Icon(Icons.sports_soccer, size: 14, color: Colors.green),
                                        Text(" ${data['goles']} ", style: TextStyle(color: Colors.green[800])),
                                      ],
                                      const SizedBox(width: 5),
                                      if ((data['asistencias'] ?? 0) > 0) ...[
                                        const Icon(Icons.hiking, size: 14, color: Colors.blue),
                                        Text(" ${data['asistencias']}", style: TextStyle(color: Colors.blue[800])),
                                      ],
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _irAFormulario(jugadorId: id),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _borrarJugador(id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}