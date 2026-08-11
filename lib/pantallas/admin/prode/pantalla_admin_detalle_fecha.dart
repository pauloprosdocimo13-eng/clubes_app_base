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
  State<PantallaAdminDetalleFecha> createState() =>
      _PantallaAdminDetalleFechaState();
}

class _PantallaAdminDetalleFechaState extends State<PantallaAdminDetalleFecha> {
  final _catController = TextEditingController();
  final _rivalController = TextEditingController();
  bool _calculando = false;

  Future<void> _toggleBloqueo(bool estadoActual) async {
    await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .update({'bloqueado': !estadoActual});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !estadoActual
                ? "🔒 Prode CERRADO. Nadie puede votar."
                : "🔓 Prode ABIERTO al público.",
          ),
          backgroundColor: !estadoActual ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> _mostrarGeneradorAutomatico() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();

      Navigator.pop(context);

      List menuDeportes = [];
      if (configDoc.exists) {
        var data = configDoc.data() as Map<String, dynamic>;
        menuDeportes = data['menu_deportes'] ?? [];
      }

      if (menuDeportes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se encontraron categorías en la base de datos."),
          ),
        );
        return;
      }

      String disciplinaSeleccionada = menuDeportes.first['titulo'] ?? '';
      List categoriasDeDisciplina = menuDeportes.first['categorias'] ?? [];
      String rivalGenerador = "";
      bool somosLocales = true;

      showDialog(
        context: context,
        builder: (ctxDialog) {
          // CAMBIO: Renombramos para evitar el error
          return StatefulBuilder(
            builder: (ctxStateful, setStateDialog) {
              // CAMBIO: Renombramos para evitar el error
              return AlertDialog(
                title: const Text(
                  "Generar Tira de Partidos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "1. Seleccioná la Disciplina:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: disciplinaSeleccionada,
                        items: menuDeportes.map((dep) {
                          return DropdownMenuItem<String>(
                            value: dep['titulo'],
                            child: Text(dep['titulo'] ?? 'Desconocido'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            disciplinaSeleccionada = val!;
                            var depElegido = menuDeportes.firstWhere(
                              (d) => d['titulo'] == val,
                            );
                            categoriasDeDisciplina =
                                depElegido['categorias'] ?? [];
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "2. Escribí el Rival:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: "Ej: Club Morón",
                          isDense: true,
                        ),
                        onChanged: (val) => rivalGenerador = val,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "3. ¿Dónde se juega?:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text(
                                "Local",
                                style: TextStyle(fontSize: 12),
                              ),
                              value: true,
                              groupValue: somosLocales,
                              onChanged: (val) =>
                                  setStateDialog(() => somosLocales = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text(
                                "Visitante",
                                style: TextStyle(fontSize: 12),
                              ),
                              value: false,
                              groupValue: somosLocales,
                              onChanged: (val) =>
                                  setStateDialog(() => somosLocales = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.blue[50],
                        child: Text(
                          "Se generarán ${categoriasDeDisciplina.length} partidos automáticamente.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctxStateful),
                    child: const Text("CANCELAR"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (rivalGenerador.isEmpty) return;
                      Navigator.pop(ctxStateful); // Cerramos el popup

                      List<Map<String, dynamic>> nuevos = [];
                      int idCounter = DateTime.now().millisecondsSinceEpoch;

                      for (var cat in categoriasDeDisciplina) {
                        nuevos.add({
                          'id': "${idCounter++}",
                          'categoria': "$disciplinaSeleccionada - $cat",
                          'local': somosLocales
                              ? widget.config.nombreApp
                              : rivalGenerador,
                          'visitante': somosLocales
                              ? rivalGenerador
                              : widget.config.nombreApp,
                          'goles_local_real': null,
                          'goles_visitante_real': null,
                        });
                      }

                      await FirebaseFirestore.instance
                          .collection('prode_fechas')
                          .doc(widget.fechaId)
                          .update({'partidos': FieldValue.arrayUnion(nuevos)});

                      if (mounted) {
                        // ACA ESTABA EL ERROR: Usamos el context global de la pantalla
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Tira de partidos generada con éxito.",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text("GENERAR"),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _mostrarDialogoGoles(Map<String, dynamic> partido) async {
    final glCtrl = TextEditingController(
      text: partido['goles_local_real']?.toString() ?? '',
    );
    final gvCtrl = TextEditingController(
      text: partido['goles_visitante_real']?.toString() ?? '',
    );

    String nombreLocal = partido['local'] ?? 'Local';
    String nombreVisitante = partido['visitante'] ?? 'Visitante';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resultado Oficial", textAlign: TextAlign.center),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombreLocal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: glCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "-",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombreVisitante,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: gvCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _actualizarPartido(partido, null, null);
            },
            child: const Text("RESETEAR", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (glCtrl.text.isEmpty || gvCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              await _actualizarPartido(
                partido,
                int.parse(glCtrl.text),
                int.parse(gvCtrl.text),
              );
            },
            child: const Text("GUARDAR GOLES"),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarPartido(
    Map<String, dynamic> partidoViejo,
    int? gl,
    int? gv,
  ) async {
    await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .update({
          'partidos': FieldValue.arrayRemove([partidoViejo]),
        });

    Map<String, dynamic> partidoModificado = Map.from(partidoViejo);
    partidoModificado['goles_local_real'] = gl;
    partidoModificado['goles_visitante_real'] = gv;
    partidoModificado.remove('resultado_real');

    await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .update({
          'partidos': FieldValue.arrayUnion([partidoModificado]),
        });
  }

  Future<void> _calcularPuntosMasivos() async {
    setState(() => _calculando = true);

    DocumentSnapshot fechaDoc = await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .get();
    List partidos = fechaDoc['partidos'] ?? [];

    Map<String, Map<String, int>> resultadosOficiales = {};
    for (var p in partidos) {
      if (p['goles_local_real'] != null && p['goles_visitante_real'] != null) {
        resultadosOficiales[p['id']] = {
          'gl': p['goles_local_real'],
          'gv': p['goles_visitante_real'],
        };
      }
    }

    QuerySnapshot votosSnapshot = await FirebaseFirestore.instance
        .collection('prode_votos')
        .where('fecha_id', isEqualTo: widget.fechaId)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in votosSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> predicciones = data['predicciones'] ?? {};
      int puntosTotalesUsuario = 0;

      predicciones.forEach((partidoId, votoUsuario) {
        if (resultadosOficiales.containsKey(partidoId)) {
          int glReal = resultadosOficiales[partidoId]!['gl']!;
          int gvReal = resultadosOficiales[partidoId]!['gv']!;

          if (votoUsuario != null && votoUsuario is Map) {
            int glUsu = votoUsuario['gl'] ?? 0;
            int gvUsu = votoUsuario['gv'] ?? 0;

            if (glReal == glUsu && gvReal == gvUsu) {
              puntosTotalesUsuario += 3; // EXACTO
            } else {
              bool realGanaL = glReal > gvReal;
              bool realGanaV = gvReal > glReal;
              bool realEmpate = glReal == gvReal;

              bool usuGanaL = glUsu > gvUsu;
              bool usuGanaV = gvUsu > glUsu;
              bool usuEmpate = glUsu == gvUsu;

              if ((realGanaL && usuGanaL) ||
                  (realGanaV && usuGanaV) ||
                  (realEmpate && usuEmpate)) {
                puntosTotalesUsuario += 1; // ACIERTO TENDENCIA
              }
            }
          }
        }
      });

      batch.update(doc.reference, {'puntos': puntosTotalesUsuario});
    }

    await batch.commit();

    setState(() => _calculando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("¡Puntos calculados exitosamente!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _agregarManual() async {
    if (_catController.text.isEmpty || _rivalController.text.isEmpty) return;
    final nuevo = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'categoria': _catController.text,
      'local': widget.config.nombreApp,
      'visitante': _rivalController.text,
      'goles_local_real': null,
      'goles_visitante_real': null,
    };
    await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .update({
          'partidos': FieldValue.arrayUnion([nuevo]),
        });
    Navigator.pop(context);
  }

  Future<void> _borrarPartidoIndividual(
    Map<String, dynamic> partidoViejo,
  ) async {
    await FirebaseFirestore.instance
        .collection('prode_fechas')
        .doc(widget.fechaId)
        .update({
          'partidos': FieldValue.arrayRemove([partidoViejo]),
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: "Generador Automático",
            onPressed: _mostrarGeneradorAutomatico,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prode_fechas')
            .doc(widget.fechaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          List partidos = List.from(data['partidos'] ?? []);
          partidos.sort((a, b) => a['categoria'].compareTo(b['categoria']));

          bool estaBloqueado = data['bloqueado'] ?? false;

          return Column(
            children: [
              Container(
                color: estaBloqueado ? Colors.red[50] : Colors.green[50],
                child: SwitchListTile(
                  title: Text(
                    estaBloqueado
                        ? "PRODE CERRADO (Nadie vota)"
                        : "PRODE ABIERTO (Gente votando)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: estaBloqueado
                          ? Colors.red[800]
                          : Colors.green[800],
                    ),
                  ),
                  subtitle: Text(
                    estaBloqueado
                        ? "Bloqueaste la carga de resultados"
                        : "Los hinchas pueden jugar",
                  ),
                  value: estaBloqueado,
                  activeColor: Colors.red,
                  inactiveThumbColor: Colors.green,
                  inactiveTrackColor: Colors.green[200],
                  onChanged: (val) => _toggleBloqueo(estaBloqueado),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.amber[100],
                width: double.infinity,
                child: const Text(
                  "Toca los ⚽ para cargar los Goles Reales de cada partido. Luego, 'Calcular Puntos'.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: 130,
                  ), // <--- ESTE ES EL ESPACIO INVISIBLE SALVAVIDAS
                  itemCount: partidos.length,
                  itemBuilder: (context, index) {
                    final p = partidos[index];
                    String nombreLocal = p['local'] ?? 'Local';
                    String nombreVisitante = p['visitante'] ?? 'Visitante';

                    int? gl = p['goles_local_real'];
                    int? gv = p['goles_visitante_real'];
                    bool jugado = (gl != null && gv != null);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red[300]),
                          onPressed: () => _borrarPartidoIndividual(p),
                        ),
                        title: Text(
                          "${p['categoria']}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                nombreLocal,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: jugado
                                    ? Colors.green[800]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                jugado ? "$gl - $gv" : "vs",
                                style: TextStyle(
                                  color: jugado ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                nombreVisitante,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.sports_soccer,
                            color: Colors.blue,
                          ),
                          onPressed: () => _mostrarDialogoGoles(p),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "manual",
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _catController,
                      decoration: const InputDecoration(labelText: "Categoría"),
                    ),
                    TextField(
                      controller: _rivalController,
                      decoration: const InputDecoration(labelText: "Rival"),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: _agregarManual,
                    child: const Text("Agregar Manual"),
                  ),
                ],
              ),
            ),
            label: const Text("1 Manual"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "calcular",
            onPressed: _calculando ? null : _calcularPuntosMasivos,
            label: _calculando
                ? const Text("Calculando...")
                : const Text("CALCULAR PUNTOS"),
            icon: const Icon(Icons.calculate),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }
}
