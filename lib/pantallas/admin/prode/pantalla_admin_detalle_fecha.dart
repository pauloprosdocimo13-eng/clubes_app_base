import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../configuracion/configuracion_app.dart';

class PantallaAdminDetalleFecha extends StatefulWidget {
  final ConfiguracionApp config;
  final String fechaId;
  final String titulo;

  const PantallaAdminDetalleFecha({
    super.key,
    required this.config,
    required this.fechaId,
    required this.titulo,
  });

  @override
  State<PantallaAdminDetalleFecha> createState() => _PantallaAdminDetalleFechaState();
}

class _PantallaAdminDetalleFechaState extends State<PantallaAdminDetalleFecha> {
  final _catController = TextEditingController();
  final _rivalController = TextEditingController();
  bool _calculando = false;

  // --- 1. IMPORTADOR (Versión Simple y Robusta) ---
  void _mostrarImportador() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Importar desde Fixture", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // TRUCO: Quitamos filtros complejos para asegurar que aparezcan
                  stream: FirebaseFirestore.instance.collection('partidos').limit(20).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No se encontraron partidos en la base de datos."));

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final rival = data['rival'] ?? '??';
                        final fecha = data['fecha'] ?? '';
                        final resultados = data['resultados'] as List? ?? [];

                        return ListTile(
                          title: Text("Vs $rival ($fecha)"),
                          subtitle: Text("${resultados.length} categorías"),
                          trailing: ElevatedButton(
                            child: const Text("IMPORTAR"),
                            onPressed: () => _importarPartido(doc.id, rival, resultados),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importarPartido(String realId, String rival, List cats) async {
    Navigator.pop(context);
    List<Map<String, dynamic>> nuevos = [];
    int idCounter = DateTime.now().millisecondsSinceEpoch;

    for (var c in cats) {
      nuevos.add({
        'id': "${idCounter++}",
        'categoria': c['categoria'] ?? 'Gral',
        'local': widget.config.nombreApp,
        'visitante': rival,
        'partido_real_id': realId,
        'resultado_real': null, // Inicialmente nadie ganó
      });
    }

    await FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).update({
      'partidos': FieldValue.arrayUnion(nuevos)
    });
  }

  // --- 2. DEFINIR RESULTADO MANUALMENTE ---
  Future<void> _setearResultado(Map<String, dynamic> partido, String? resultado) async {
    // 1. Borramos el partido viejo
    await FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).update({
      'partidos': FieldValue.arrayRemove([partido])
    });

    // 2. Modificamos el resultado (L, E, V, o null)
    Map<String, dynamic> partidoModificado = Map.from(partido);
    partidoModificado['resultado_real'] = resultado;

    // 3. Lo subimos de nuevo
    await FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).update({
      'partidos': FieldValue.arrayUnion([partidoModificado])
    });
  }

  // --- 3. CALCULAR PUNTOS DE TODOS LOS USUARIOS ---
  Future<void> _calcularPuntosMasivos() async {
    setState(() => _calculando = true);
    
    // A. Obtenemos la fecha con los resultados cargados
    DocumentSnapshot fechaDoc = await FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).get();
    List partidos = fechaDoc['partidos'] ?? [];

    // Creamos un mapa rápido de resultados: { 'id_partido': 'L' }
    Map<String, String> resultadosOficiales = {};
    for (var p in partidos) {
      if (p['resultado_real'] != null) {
        resultadosOficiales[p['id']] = p['resultado_real'];
      }
    }

    // B. Buscamos todos los votos de esta fecha
    QuerySnapshot votosSnapshot = await FirebaseFirestore.instance
        .collection('prode_votos')
        .where('fecha_id', isEqualTo: widget.fechaId)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    // C. Corregimos examen por examen
    for (var doc in votosSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> predicciones = data['predicciones'] ?? {};
      int puntos = 0;

      predicciones.forEach((partidoId, votoUsuario) {
        // Si el usuario acertó el resultado oficial, suma punto
        if (resultadosOficiales.containsKey(partidoId) && resultadosOficiales[partidoId] == votoUsuario) {
          puntos++;
        }
      });

      // Agregamos la actualización al lote
      batch.update(doc.reference, {'puntos': puntos});
    }

    // D. Aplicamos cambios
    await batch.commit();

    setState(() => _calculando = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Puntos calculados exitosamente!")));
  }

  // UI para cargar manual (Mantenemos la que tenías)
  Future<void> _agregarManual() async {
    if (_catController.text.isEmpty || _rivalController.text.isEmpty) return;
    final nuevo = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'categoria': _catController.text,
      'local': widget.config.nombreApp,
      'visitante': _rivalController.text,
      'resultado_real': null,
    };
    await FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).update({
      'partidos': FieldValue.arrayUnion([nuevo])
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.cloud_download), onPressed: _mostrarImportador),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('prode_fechas').doc(widget.fechaId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          List partidos = List.from(data['partidos'] ?? []);
          
          // Ordenamos por categoría para que sea prolijo
          partidos.sort((a, b) => a['categoria'].compareTo(b['categoria']));

          return Column(
            children: [
               Container(
                 padding: const EdgeInsets.all(10),
                 color: Colors.amber[100],
                 child: const Text("⚠️ Toca el icono de silbato para definir quién ganó y luego presiona 'Calcular Puntos'.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
               ),
              Expanded(
                child: ListView.builder(
                  itemCount: partidos.length,
                  itemBuilder: (context, index) {
                    final p = partidos[index];
                    String? res = p['resultado_real']; // L, E, V, o null

                    return Card(
                      child: ListTile(
                        leading: _IconoResultado(resultado: res),
                        title: Text("${p['categoria']}: ${p['local']} vs ${p['visitante']}"),
                        subtitle: Text(
                            res == null ? "Esperando resultado..." : "Ganador: ${res == 'L' ? 'Local' : res == 'E' ? 'Empate' : 'Visitante'}",
                            style: TextStyle(color: res == null ? Colors.grey : Colors.green[800], fontWeight: FontWeight.bold)
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.sports, color: Colors.blue),
                          onSelected: (valor) => _setearResultado(p, valor),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: "L", child: Text("Gana LOCAL")),
                            const PopupMenuItem(value: "E", child: Text("EMPATE")),
                            const PopupMenuItem(value: "V", child: Text("Gana VISITANTE")),
                            const PopupMenuItem(value: null, child: Text("Resetear (Sin jugar)")),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // BOTÓN PRINCIPAL: CALCULAR PUNTOS
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "manual",
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: _catController, decoration: const InputDecoration(labelText: "Categoría")),
                  TextField(controller: _rivalController, decoration: const InputDecoration(labelText: "Rival")),
                ]),
                actions: [ElevatedButton(onPressed: _agregarManual, child: const Text("Agregar"))],
              )
            ),
            label: const Text("Manual"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "calcular",
            onPressed: _calculando ? null : _calcularPuntosMasivos,
            label: _calculando ? const Text("Calculando...") : const Text("CALCULAR PUNTOS"),
            icon: const Icon(Icons.calculate),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }
}

// Iconito visual para el estado del partido
class _IconoResultado extends StatelessWidget {
  final String? resultado;
  const _IconoResultado({required this.resultado});

  @override
  Widget build(BuildContext context) {
    if (resultado == 'L') return const CircleAvatar(backgroundColor: Colors.blue, child: Text("L", style: TextStyle(color: Colors.white)));
    if (resultado == 'E') return const CircleAvatar(backgroundColor: Colors.grey, child: Text("E", style: TextStyle(color: Colors.white)));
    if (resultado == 'V') return const CircleAvatar(backgroundColor: Colors.red, child: Text("V", style: TextStyle(color: Colors.white)));
    return const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.access_time, color: Colors.grey));
  }
}