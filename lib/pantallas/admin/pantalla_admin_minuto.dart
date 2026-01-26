import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminMinuto extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAdminMinuto({super.key, required this.config, required this.deporteId});

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
  bool _cargandoCategorias = true; // Variable para esperar la carga

  // Variables para el reloj
  Timer? _timer;
  String _tiempoDisplay = "00:00";
  Timestamp? _inicioTiempoRef;
  String _estadoRef = "";

  @override
  void initState() {
    super.initState();
    _cargarCategoriasDelDeporte(); // <--- Carga asíncrona

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _actualizarReloj();
    });
  }

  // --- LÓGICA DINÁMICA: Leer categorías reales de Firebase ---
  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes = List.from(data['menu_deportes'] ?? []);

        final deporteData = menuDeportes.firstWhere(
                (e) => e['id'] == widget.deporteId,
            orElse: () => null
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

    // Seleccionamos la primera por defecto
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
      _categorias = ['1ra', '3ra', '4ta', '5ta', 'Senior +35', 'Master +42', 'Femenino'];
    } else {
      final anioActual = DateTime.now().year;
      // Actualizado a -7
      int catMasGrande = anioActual - 13;
      int catMasChica = anioActual - 7;

      for (int i = catMasGrande; i <= catMasChica; i++) {
        _categorias.add(i.toString());
      }
    }
  }
  // -----------------------------------------------------------

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _actualizarReloj() {
    if (_inicioTiempoRef == null || (_estadoRef != '1T' && _estadoRef != '2T')) {
      return;
    }
    final now = DateTime.now();
    final inicio = _inicioTiempoRef!.toDate();
    final difference = now.difference(inicio);
    final minutos = difference.inMinutes;
    final segundos = difference.inSeconds % 60;
    if (mounted) {
      setState(() {
        _tiempoDisplay = "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
      });
    }
  }

  // --- LIMPIAR HISTORIAL ---
  Future<void> _limpiarHistorial() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Iniciar Nueva Fecha?"),
        content: const Text("Esto BORRARÁ todos los resultados del historial (partidos terminados de la fecha anterior) para dejar la lista vacía para hoy.\n\n¿Estás seguro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Historial limpio. ¡Buen comienzo de jornada!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al borrar historial.")));
        }
      }
    }
  }

  Future<void> _iniciarTransmision() async {
    if (_rivalNombre.isEmpty) return;

    await FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).set({
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
  }

  Future<void> _cambiarEstado(String nuevoEstado, {String? motivoSuspension}) async {
    final docRef = FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId);
    Map<String, dynamic> updateData = {'estado': nuevoEstado};

    if (nuevoEstado == '1T' || nuevoEstado == '2T') {
      updateData['inicio_tiempo'] = FieldValue.serverTimestamp();
    }

    if (nuevoEstado == 'FINALIZADO' || nuevoEstado == 'SUSPENDIDO') {
      updateData['activo'] = false;
      if (motivoSuspension != null) {
        updateData['motivo_suspension'] = motivoSuspension;
      }

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        data['estado'] = nuevoEstado;
        data['activo'] = false;
        data['deporte_id'] = widget.deporteId;
        data['fecha'] = FieldValue.serverTimestamp();
        if (motivoSuspension != null) data['motivo_suspension'] = motivoSuspension;

        await FirebaseFirestore.instance.collection('historial_partidos').add(data);
      }
    }

    await docRef.update(updateData);
  }

  Future<void> _agregarEvento(String tipo, String equipo, String detalle) async {
    final docRef = FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    List eventos = data['eventos'] ?? [];

    String tiempoEvento = "0'";

    if (data['inicio_tiempo'] != null && (data['estado'] == '1T' || data['estado'] == '2T')) {
      Timestamp inicio = data['inicio_tiempo'];
      Duration diferencia = DateTime.now().difference(inicio.toDate());
      String minutos = diferencia.inMinutes.toString();
      String segundos = (diferencia.inSeconds % 60).toString().padLeft(2, '0');
      tiempoEvento = "$minutos:$segundos";
    } else {
      tiempoEvento = data['estado'] ?? '-';
    }

    eventos.add({
      'tipo': tipo,
      'equipo': equipo,
      'detalle': detalle,
      'minuto': tiempoEvento,
      'timestamp': DateTime.now().toString(),
    });

    Map<String, dynamic> updateData = {'eventos': eventos};

    if (tipo == 'gol') {
      if (equipo == 'local') {
        updateData['goles_local'] = FieldValue.increment(1);
      } else {
        updateData['goles_visita'] = FieldValue.increment(1);
      }
    }

    await docRef.update(updateData);
  }

  void _dialogoGol(String equipo) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Gol ${equipo == 'local' ? 'Local' : 'Visita'}"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Jugador / Nro")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _agregarEvento('gol', equipo, controller.text);
                Navigator.pop(c);
              }
            },
            child: const Text("GOL"),
          )
        ],
      ),
    );
  }

  void _dialogoTarjeta(String tipo, Color color) {
    final controller = TextEditingController();
    String equipoSeleccionado = 'local';
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(children: [Icon(Icons.style, color: color), const SizedBox(width: 10), Text("Tarjeta $tipo")]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(label: const Text("Local"), selected: equipoSeleccionado == 'local', onSelected: (v) => setStateDialog(() => equipoSeleccionado = 'local')),
                      ChoiceChip(label: const Text("Visita"), selected: equipoSeleccionado == 'visita', onSelected: (v) => setStateDialog(() => equipoSeleccionado = 'visita')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: controller, decoration: const InputDecoration(labelText: "Jugador / Nro")),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      _agregarEvento(tipo, equipoSeleccionado, controller.text);
                      Navigator.pop(c);
                    }
                  },
                  child: const Text("Aplicar"),
                )
              ],
            );
          }
      ),
    );
  }

  void _dialogoSuspender() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Text("Suspender Partido")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("El partido finalizará y se guardará como suspendido."),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  labelText: "Motivo de suspensión",
                  hintText: "Ej: Lluvia, Incidentes, Falta de luz",
                  border: OutlineInputBorder()
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _cambiarEstado('SUSPENDIDO', motivoSuspension: controller.text);
                Navigator.pop(c);
              }
            },
            child: const Text("SUSPENDER DEFINITIVAMENTE"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Consola Minuto a Minuto"), backgroundColor: Colors.black87, foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          bool activo = false;
          if (snapshot.data!.exists) {
            final d = snapshot.data!.data() as Map<String, dynamic>;
            activo = d['activo'] ?? false;
          }

          if (!activo) return _buildPantallaConfiguracion();

          final data = snapshot.data!.data() as Map<String, dynamic>;

          _estadoRef = data['estado'] ?? '1T';
          if (data['inicio_tiempo'] != null) {
            _inicioTiempoRef = data['inicio_tiempo'];
          }

          return _buildConsolaEnVivo(data);
        },
      ),
    );
  }

  Widget _buildPantallaConfiguracion() {
    if (_cargandoCategorias) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Configurar Nuevo Partido", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _categoriaSeleccionada,
            decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
            items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c.contains(RegExp(r'[0-9]{4}')) ? "Categoría $c" : c))).toList(),
            onChanged: (v) => setState(() => _categoriaSeleccionada = v!),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rivales').where('deporte_id', isEqualTo: widget.deporteId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              List<DropdownMenuItem<String>> items = [];
              if (snapshot.data!.docs.isNotEmpty) {
                items = snapshot.data!.docs.map((doc) {
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
              }
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Rival", border: OutlineInputBorder()),
                hint: const Text("Seleccionar Club Rival"),
                items: items,
                onChanged: (v) => setState(() => _rivalSeleccionadoId = v),
              );
            },
          ),

          const SizedBox(height: 40),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15)
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text("INICIAR TRANSMISIÓN EN VIVO"),
            onPressed: _iniciarTransmision,
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),

          // --- BOTÓN PARA LIMPIAR HISTORIAL ---
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever),
            label: const Text("LIMPIAR HISTORIAL (NUEVA FECHA)"),
            onPressed: _limpiarHistorial,
          ),
          const Text(
            "Usar al comenzar una jornada nueva para borrar los partidos de la semana anterior.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
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
                Column(children: [Text(widget.config.nombreApp, style: const TextStyle(color: Colors.white)), Text("$golesL", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))]),

                Column(children: [
                  const Text("ESTADO", style: TextStyle(color: Colors.grey)),
                  Text(estado, style: const TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)),
                  if (estado == '1T' || estado == '2T')
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(5)),
                      child: Text(
                        _tiempoDisplay,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                ]),

                Column(children: [Text(rival, style: const TextStyle(color: Colors.white)), Text("$golesV", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: widget.config.colorPrimario), onPressed: () => _dialogoGol('local'), child: const Text("GOL LOCAL +"))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), onPressed: () => _dialogoGol('visita'), child: const Text("GOL RIVAL +"))),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(icon: const Icon(Icons.style, color: Colors.yellow, size: 40), onPressed: () => _dialogoTarjeta('amarilla', Colors.yellow)),
          IconButton(icon: const Icon(Icons.style, color: Colors.red, size: 40), onPressed: () => _dialogoTarjeta('roja', Colors.red)),
          IconButton(icon: const Icon(Icons.style, color: Colors.blue, size: 40), onPressed: () => _dialogoTarjeta('azul', Colors.blue)),
        ]),
        const Divider(height: 30),
        Text("Control de Tiempos", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (estado == '1T') ElevatedButton(onPressed: () => _cambiarEstado('ENTRETIEMPO'), child: const Text("Finalizar 1T")),
          if (estado == 'ENTRETIEMPO') ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _cambiarEstado('2T'), child: const Text("Iniciar 2T")),
          if (estado == '2T') ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => _cambiarEstado('FINALIZADO'), child: const Text("FINALIZAR PARTIDO")),

          OutlinedButton.icon(
            icon: const Icon(Icons.warning, color: Colors.orange),
            label: const Text("SUSPENDER", style: TextStyle(color: Colors.orange)),
            onPressed: _dialogoSuspender,
          ),
        ]),
      ],
    );
  }
}