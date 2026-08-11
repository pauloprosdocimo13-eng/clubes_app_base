import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminMinuto extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAdminMinuto({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaAdminMinuto> createState() => _PantallaAdminMinutoState();
}

class _PantallaAdminMinutoState extends State<PantallaAdminMinuto> {
  // Variables para crear partido
  String _categoriaSeleccionada = '';
  String? _rivalSeleccionadoId;
  String _rivalNombre = "";
  String _rivalEscudo = "";

  List<String> _categorias = [];
  bool _cargandoCategorias = true;

  // Lista para guardar el plantel del partido actual
  List<Map<String, dynamic>> _jugadoresLocales = [];
  String _categoriaPlantelCargado = "";

  // Variables para el reloj
  Timer? _timer;
  String _tiempoDisplay = "00:00";
  Timestamp? _inicioTiempoRef;
  String _estadoRef = "";

  @override
  void initState() {
    super.initState();
    _cargarCategoriasDelDeporte();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _actualizarReloj();
    });
  }

  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes = List.from(data['menu_deportes'] ?? []);
        final deporteData = menuDeportes.firstWhere(
          (e) => e['id'] == widget.deporteId,
          orElse: () => null,
        );
        if (deporteData != null && deporteData['categorias'] != null) {
          categoriasEncontradas = List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      print("Error config: $e");
    }

    if (categoriasEncontradas.isEmpty) {
      _generarCategoriasLegacy();
    } else {
      _categorias = categoriasEncontradas;
    }

    if (_categorias.isNotEmpty) {
      _categoriaSeleccionada = _categorias.first;
    } else {
      _categorias = ['General'];
      _categoriaSeleccionada = 'General';
    }

    if (mounted) {
      setState(() => _cargandoCategorias = false);
    }
  }

  void _generarCategoriasLegacy() {
    final id = widget.deporteId.toLowerCase();
    _categorias = [];
    if (id.contains('futsal')) {
      _categorias = [
        '1ra',
        '3ra',
        '4ta',
        '5ta',
        'Senior +35',
        'Master +42',
        'Femenino',
      ];
    } else {
      final anioActual = DateTime.now().year;
      int catMasGrande = anioActual - 13;
      int catMasChica = anioActual - 7;
      for (int i = catMasGrande; i <= catMasChica; i++) {
        _categorias.add(i.toString());
      }
    }
  }

  Future<void> _cargarJugadoresLocales(String categoria) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('jugadores')
          .where('deporte_id', isEqualTo: widget.deporteId)
          .where('categoria', isEqualTo: categoria)
          .get();

      List<Map<String, dynamic>> lista = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'nombre':
              "${d['apellido']} ${d['nombre']} ${d['dorsal'] != null ? '(#${d['dorsal']})' : ''}"
                  .trim(),
        };
      }).toList();

      lista.sort((a, b) => a['nombre'].compareTo(b['nombre']));

      if (mounted) {
        setState(() {
          _jugadoresLocales = lista;
          _categoriaPlantelCargado = categoria;
        });
      }
    } catch (e) {
      print("Error cargando jugadores locales: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _actualizarReloj() {
    if (_inicioTiempoRef == null || (_estadoRef != '1T' && _estadoRef != '2T'))
      return;
    final now = DateTime.now();
    final inicio = _inicioTiempoRef!.toDate();
    final difference = now.difference(inicio);
    final minutos = difference.inMinutes;
    final segundos = difference.inSeconds % 60;
    if (mounted) {
      setState(() {
        _tiempoDisplay =
            "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
      });
    }
  }

  String _calcularTiempoEvento(Map<String, dynamic> data) {
    if (data['inicio_tiempo'] != null &&
        (data['estado'] == '1T' || data['estado'] == '2T')) {
      Timestamp inicio = data['inicio_tiempo'];
      Duration diferencia = DateTime.now().difference(inicio.toDate());
      String minutos = diferencia.inMinutes.toString();
      String segundos = (diferencia.inSeconds % 60).toString().padLeft(2, '0');
      return "$minutos:$segundos";
    }
    return data['estado'] ?? '-';
  }

  Future<void> _limpiarHistorial() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Iniciar Nueva Fecha?"),
        content: const Text(
          "Esto BORRARÁ todos los resultados del historial para dejar la lista vacía para hoy.\n\n¿Estás seguro?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SÍ, BORRAR TODO"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('historial_partidos')
            .where('deporte_id', isEqualTo: widget.deporteId)
            .get();
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) batch.delete(doc.reference);
        await batch.commit();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Historial limpio.")));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Error al borrar.")));
      }
    }
  }

  Future<void> _iniciarTransmision() async {
    if (_rivalNombre.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('partidos_en_vivo')
        .doc(widget.deporteId)
        .set({
          'activo': true,
          'categoria': _categoriaSeleccionada,
          'rival': _rivalNombre,
          'escudo_rival': _rivalEscudo,
          'goles_local': 0,
          'goles_visita': 0,
          'estado': '1T',
          'inicio_tiempo': FieldValue.serverTimestamp(),
          'inicio_partido_real': FieldValue.serverTimestamp(),
          'eventos': [],
        });

    _cargarJugadoresLocales(_categoriaSeleccionada);
  }

  Future<void> _cambiarEstado(
    String nuevoEstado, {
    String? motivoSuspension,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('partidos_en_vivo')
        .doc(widget.deporteId);
    Map<String, dynamic> updateData = {'estado': nuevoEstado};

    if (nuevoEstado == '1T' || nuevoEstado == '2T') {
      updateData['inicio_tiempo'] = FieldValue.serverTimestamp();
    }

    if (nuevoEstado == 'FINALIZADO' || nuevoEstado == 'SUSPENDIDO') {
      updateData['activo'] = false;
      if (motivoSuspension != null)
        updateData['motivo_suspension'] = motivoSuspension;

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        data['estado'] = nuevoEstado;
        data['activo'] = false;
        data['deporte_id'] = widget.deporteId;
        data['fecha'] = FieldValue.serverTimestamp();
        if (motivoSuspension != null)
          data['motivo_suspension'] = motivoSuspension;

        await FirebaseFirestore.instance
            .collection('historial_partidos')
            .add(data);
      }
    }
    await docRef.update(updateData);
  }

  // --- ANULAR EVENTO Y RESTAR ESTADÍSTICAS ---
  Future<void> _borrarEvento(Map<String, dynamic> eventoABorrar) async {
    final docRef = FirebaseFirestore.instance
        .collection('partidos_en_vivo')
        .doc(widget.deporteId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    List eventos = List.from(doc.data()!['eventos'] ?? []);
    eventos.removeWhere((e) => e['timestamp'] == eventoABorrar['timestamp']);

    WriteBatch batch = FirebaseFirestore.instance.batch();

    Map<String, dynamic> updateData = {'eventos': eventos};

    if (eventoABorrar['tipo'] == 'gol') {
      if (eventoABorrar['equipo'] == 'local') {
        updateData['goles_local'] = FieldValue.increment(-1);
        // --- ELIMINADA LA ACTUALIZACIÓN AUTOMÁTICA EN 'jugadores' ---
      } else {
        updateData['goles_visita'] = FieldValue.increment(-1);
      }
    }

    batch.update(docRef, updateData);
    await batch.commit();
  }

  Future<void> _agregarEventoBase(
    String tipo,
    String equipo,
    String detalle,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('partidos_en_vivo')
        .doc(widget.deporteId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    List eventos = List.from(data['eventos'] ?? []);

    eventos.add({
      'tipo': tipo,
      'equipo': equipo,
      'detalle': detalle,
      'minuto': _calcularTiempoEvento(data),
      'timestamp': DateTime.now().toString(),
    });

    Map<String, dynamic> updateData = {'eventos': eventos};
    if (tipo == 'gol') {
      if (equipo == 'local')
        updateData['goles_local'] = FieldValue.increment(1);
      else
        updateData['goles_visita'] = FieldValue.increment(1);
    }
    await docRef.update(updateData);
  }

  // --- REGISTRAR GOL LOCAL ---
  Future<void> _registrarGolLocal(
    String? idAutor,
    String nombreAutor,
    String? idAsistencia,
    String? nombreAsistencia,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('partidos_en_vivo')
        .doc(widget.deporteId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    List eventos = List.from(data['eventos'] ?? []);

    String detalle = nombreAutor;
    if (nombreAsistencia != null) detalle += " (Asistencia: $nombreAsistencia)";

    eventos.add({
      'tipo': 'gol',
      'equipo': 'local',
      'detalle': detalle,
      'idAutor': idAutor,
      'idAsistencia': idAsistencia,
      'minuto': _calcularTiempoEvento(data),
      'timestamp': DateTime.now().toString(),
    });

    WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.update(docRef, {
      'eventos': eventos,
      'goles_local': FieldValue.increment(1),
    });

    // --- ELIMINADA LA ACTUALIZACIÓN AUTOMÁTICA EN 'jugadores' ---
    // Si el gol se lo dan en planilla a otro, se carga manual desde la ficha del jugador.

    await batch.commit();
  }

  // --- DIÁLOGOS ---
  void _dialogoGolLocal() {
    String? seleccionAutor;
    String? idAutor;
    String? nombreAutor;

    String? seleccionAsistencia;
    String? idAsistencia;
    String? nombreAsistencia;

    final _autorManualCtrl = TextEditingController();
    final _asistenciaManualCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("⚽ GOL DE GÜEMES"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: seleccionAutor,
                  decoration: const InputDecoration(
                    labelText: "Autor del Gol *",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    if (_jugadoresLocales.isEmpty)
                      const DropdownMenuItem<String>(
                        value: 'vacio',
                        child: Text(
                          "Sin plantel cargado",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._jugadoresLocales.map(
                        (j) => DropdownMenuItem<String>(
                          value: j['id'],
                          child: Text(j['nombre']),
                        ),
                      ),
                    const DropdownMenuItem<String>(
                      value: 'manual',
                      child: Text(
                        "+ Escribir manual (Sube de cat.)",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == 'vacio') return;
                    setDialogState(() {
                      seleccionAutor = v;
                      if (v == 'manual') {
                        idAutor = null;
                        nombreAutor = _autorManualCtrl.text;
                      } else {
                        idAutor = v;
                        nombreAutor = _jugadoresLocales.firstWhere(
                          (j) => j['id'] == v,
                        )['nombre'];
                      }
                    });
                  },
                ),
                if (seleccionAutor == 'manual') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _autorManualCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre del jugador (Ej: Benja 2017)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => nombreAutor = v,
                  ),
                ],
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: seleccionAsistencia,
                  decoration: const InputDecoration(
                    labelText: "Asistencia (Opcional)",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'ninguna',
                      child: Text("Sin asistencia"),
                    ),
                    ..._jugadoresLocales
                        .where((j) => j['id'] != seleccionAutor)
                        .map(
                          (j) => DropdownMenuItem<String>(
                            value: j['id'],
                            child: Text(j['nombre']),
                          ),
                        ),
                    const DropdownMenuItem<String>(
                      value: 'manual',
                      child: Text(
                        "+ Escribir manual",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      seleccionAsistencia = v;
                      if (v == 'ninguna' || v == null) {
                        idAsistencia = null;
                        nombreAsistencia = null;
                      } else if (v == 'manual') {
                        idAsistencia = null;
                        nombreAsistencia = _asistenciaManualCtrl.text;
                      } else {
                        idAsistencia = v;
                        nombreAsistencia = _jugadoresLocales.firstWhere(
                          (j) => j['id'] == v,
                        )['nombre'];
                      }
                    });
                  },
                ),
                if (seleccionAsistencia == 'manual') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _asistenciaManualCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre de la asistencia",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => nombreAsistencia = v,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (seleccionAutor == 'manual' && _autorManualCtrl.text.isEmpty)
                  return;

                if (seleccionAutor != null && seleccionAutor != 'vacio') {
                  _registrarGolLocal(
                    idAutor,
                    nombreAutor!,
                    idAsistencia,
                    nombreAsistencia,
                  );
                  Navigator.pop(c);
                }
              },
              child: const Text("CONFIRMAR GOL"),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogoGolVisita() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Gol Rival"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Jugador / Nro (Opcional)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              _agregarEventoBase(
                'gol',
                'visita',
                controller.text.isNotEmpty ? controller.text : 'Jugador Rival',
              );
              Navigator.pop(c);
            },
            child: const Text("GOL RIVAL"),
          ),
        ],
      ),
    );
  }

  void _dialogoTarjeta(String tipo, Color color) {
    final controller = TextEditingController();
    String equipoSeleccionado = 'local';
    String? idJugadorLocal;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.style, color: color),
                const SizedBox(width: 10),
                Text("Tarjeta $tipo"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text("Local"),
                      selected: equipoSeleccionado == 'local',
                      onSelected: (v) =>
                          setStateDialog(() => equipoSeleccionado = 'local'),
                    ),
                    ChoiceChip(
                      label: const Text("Visita"),
                      selected: equipoSeleccionado == 'visita',
                      onSelected: (v) =>
                          setStateDialog(() => equipoSeleccionado = 'visita'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (equipoSeleccionado == 'local' &&
                    _jugadoresLocales.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Jugador Amonestado",
                      border: OutlineInputBorder(),
                    ),
                    items: _jugadoresLocales
                        .map(
                          (j) => DropdownMenuItem<String>(
                            value: j['nombre'],
                            child: Text(j['nombre']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateDialog(() => idJugadorLocal = v),
                  )
                else
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "Jugador / Nro",
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  String detalle = equipoSeleccionado == 'local'
                      ? (idJugadorLocal ?? controller.text)
                      : controller.text;
                  if (detalle.isNotEmpty) {
                    _agregarEventoBase(tipo, equipoSeleccionado, detalle);
                    Navigator.pop(c);
                  }
                },
                child: const Text("Aplicar"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _dialogoSuspender() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Text("Suspender Partido"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("El partido finalizará y se guardará como suspendido."),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Motivo de suspensión",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _cambiarEstado('SUSPENDIDO', motivoSuspension: controller.text);
                Navigator.pop(c);
              }
            },
            child: const Text("SUSPENDER"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consola Minuto a Minuto"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('partidos_en_vivo')
            .doc(widget.deporteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          bool activo = false;
          if (snapshot.data!.exists) {
            final d = snapshot.data!.data() as Map<String, dynamic>;
            activo = d['activo'] ?? false;
          }
          if (!activo) return _buildPantallaConfiguracion();
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _estadoRef = data['estado'] ?? '1T';
          if (data['inicio_tiempo'] != null)
            _inicioTiempoRef = data['inicio_tiempo'];
          if (_categoriaPlantelCargado != data['categoria']) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _cargarJugadoresLocales(data['categoria']);
            });
          }
          return _buildConsolaEnVivo(data);
        },
      ),
    );
  }

  Widget _buildPantallaConfiguracion() {
    if (_cargandoCategorias)
      return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Configurar Nuevo Partido",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _categoriaSeleccionada,
            decoration: const InputDecoration(
              labelText: "Categoría",
              border: OutlineInputBorder(),
            ),
            items: _categorias
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.contains(RegExp(r'[0-9]{4}')) ? "Categoría $c" : c,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _categoriaSeleccionada = v!),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rivales')
                .where('deporte_id', isEqualTo: widget.deporteId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((
                doc,
              ) {
                final d = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(d['nombre'] ?? 'Sin nombre'),
                  onTap: () {
                    _rivalNombre = d['nombre'];
                    _rivalEscudo = d['escudo_url'] ?? '';
                  },
                );
              }).toList();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Rival",
                  border: OutlineInputBorder(),
                ),
                hint: const Text("Seleccionar Club Rival"),
                items: items,
                onChanged: (v) => setState(() => _rivalSeleccionadoId = v),
              );
            },
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text("INICIAR TRANSMISIÓN EN VIVO"),
            onPressed: _iniciarTransmision,
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever),
            label: const Text("LIMPIAR HISTORIAL (NUEVA FECHA)"),
            onPressed: _limpiarHistorial,
          ),
        ],
      ),
    );
  }

  Widget _buildConsolaEnVivo(Map<String, dynamic> data) {
    String estado = data['estado'] ?? '1T';
    int golesL = data['goles_local'] ?? 0;
    int golesV = data['goles_visita'] ?? 0;
    String rival = data['rival'] ?? 'Rival';
    List eventos = List.from(data['eventos'] ?? []).reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Card(
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      widget.config.nombreApp,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      "$golesL",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("ESTADO", style: TextStyle(color: Colors.grey)),
                    Text(
                      estado,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (estado == '1T' || estado == '2T')
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _tiempoDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  children: [
                    Text(rival, style: const TextStyle(color: Colors.white)),
                    Text(
                      "$golesV",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                ),
                onPressed: _dialogoGolLocal,
                child: const Text("GOL LOCAL +"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                onPressed: _dialogoGolVisita,
                child: const Text("GOL RIVAL +"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.style, color: Colors.yellow, size: 40),
              onPressed: () => _dialogoTarjeta('amarilla', Colors.yellow),
            ),
            IconButton(
              icon: const Icon(Icons.style, color: Colors.red, size: 40),
              onPressed: () => _dialogoTarjeta('roja', Colors.red),
            ),
            IconButton(
              icon: const Icon(Icons.style, color: Colors.blue, size: 40),
              onPressed: () => _dialogoTarjeta('azul', Colors.blue),
            ),
          ],
        ),

        const Divider(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Eventos del Partido",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "${eventos.length} registrados",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (eventos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No hay eventos cargados aún",
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ...eventos.map((e) {
            IconData icon = Icons.info_outline;
            Color colorIcon = Colors.grey;
            if (e['tipo'] == 'gol') {
              icon = Icons.sports_soccer;
              colorIcon = Colors.green;
            } else if (e['tipo'] == 'amarilla') {
              icon = Icons.style;
              colorIcon = Colors.yellow;
            } else if (e['tipo'] == 'roja') {
              icon = Icons.style;
              colorIcon = Colors.red;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                dense: true,
                leading: Icon(icon, color: colorIcon, size: 18),
                title: Text(
                  "${e['minuto']} - ${e['detalle']}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  e['equipo'] == 'local' ? 'Güemes' : rival,
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_sweep,
                    color: Colors.red,
                    size: 18,
                  ),
                  tooltip: "Anular este evento",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("¿Anular Evento?"),
                        content: const Text(
                          "Si anulas el gol, desaparecerá del minuto a minuto y del marcador de la pantalla de inicio.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("No"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _borrarEvento(e);
                              Navigator.pop(c);
                            },
                            child: const Text("Sí, anular"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }),

        const Divider(height: 40),
        Text(
          "Control de Tiempos",
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (estado == '1T')
              ElevatedButton(
                onPressed: () => _cambiarEstado('ENTRETIEMPO'),
                child: const Text("Finalizar 1T"),
              ),
            if (estado == 'ENTRETIEMPO')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _cambiarEstado('2T'),
                child: const Text("Iniciar 2T"),
              ),
            if (estado == '2T')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _cambiarEstado('FINALIZADO'),
                child: const Text("FINALIZAR PARTIDO"),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.warning, color: Colors.orange),
              label: const Text(
                "SUSPENDER",
                style: TextStyle(color: Colors.orange),
              ),
              onPressed: _dialogoSuspender,
            ),
          ],
        ),
      ],
    );
  }
}
