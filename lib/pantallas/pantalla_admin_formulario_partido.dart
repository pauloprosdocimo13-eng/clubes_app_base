import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- IMPORTANTE
import '../../configuracion/configuracion_app.dart';

class PantallaAdminFormularioPartido extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? partidoId; // Si es null, es NUEVO. Si tiene ID, es EDICIÓN.

  const PantallaAdminFormularioPartido({
    super.key,
    required this.config,
    required this.deporteId,
    this.partidoId,
  });

  @override
  State<PantallaAdminFormularioPartido> createState() => _PantallaAdminFormularioPartidoState();
}

class _PantallaAdminFormularioPartidoState extends State<PantallaAdminFormularioPartido> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _rivalController = TextEditingController();
  final TextEditingController _jornadaController = TextEditingController(); // Controlador para "Fecha 4", etc.

  // Variables de estado
  DateTime _fechaSeleccionada = DateTime.now();
  bool _esLocal = true;
  String _torneo = 'apertura';
  String _estado = 'programado';

  // Mapa de resultados
  Map<String, Map<String, int>> _resultadosTemp = {};
  List<String> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
  }

  // Carga orquestada
  Future<void> _inicializarPantalla() async {
    await _cargarCategoriasDelDeporte();

    if (widget.partidoId != null) {
      // SI ES EDICIÓN: Cargamos datos de Firebase
      await _cargarDatosExistentes();
    } else {
      // SI ES NUEVO: Intentamos recuperar la última configuración usada
      await _cargarUltimaConfiguracion();
      setState(() => _cargando = false);
    }
  }

  // --- LÓGICA DE MEMORIA (PREFS) ---
  Future<void> _cargarUltimaConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    // Recuperamos datos guardados (si existen)
    final ultimoTorneo = prefs.getString('ultimo_torneo');
    final ultimaJornada = prefs.getString('ultima_jornada');
    final ultimaFechaMillis = prefs.getInt('ultima_fecha_millis');
    final esLocal = prefs.getBool('ultimo_es_local');

    setState(() {
      if (ultimoTorneo != null) _torneo = ultimoTorneo;
      if (ultimaJornada != null) _jornadaController.text = ultimaJornada;
      if (esLocal != null) _esLocal = esLocal;
      if (ultimaFechaMillis != null) {
        _fechaSeleccionada = DateTime.fromMillisecondsSinceEpoch(ultimaFechaMillis);
      }
    });
  }

  Future<void> _guardarConfiguracionActual() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ultimo_torneo', _torneo);
    await prefs.setString('ultima_jornada', _jornadaController.text);
    await prefs.setInt('ultima_fecha_millis', _fechaSeleccionada.millisecondsSinceEpoch);
    await prefs.setBool('ultimo_es_local', _esLocal);
  }
  // ---------------------------------

  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes = List.from(data['menu_deportes'] ?? []);
        final deporteData = menuDeportes.firstWhere((e) => e['id'] == widget.deporteId, orElse: () => null);

        if (deporteData != null && deporteData['categorias'] != null) {
          categoriasEncontradas = List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      print("Error buscando configuración: $e");
    }

    if (categoriasEncontradas.isNotEmpty) {
      _categorias = categoriasEncontradas;
    } else {
      _generarCategoriasLegacy();
    }

    _resultadosTemp = {};
    for (var cat in _categorias) {
      _resultadosTemp[cat] = {'propios': 0, 'rival': 0};
    }
  }

  void _generarCategoriasLegacy() {
    final id = widget.deporteId.toLowerCase();
    _categorias = [];
    if (id.contains('futsal')) {
      _categorias = ['1ra', '3ra', '4ta', '5ta', 'Senior +35', 'Master +42', 'Femenino'];
    } else {
      final int anioActual = DateTime.now().year;
      for (int i = anioActual - 13; i <= anioActual - 7; i++) {
        _categorias.add(i.toString());
      }
    }
  }

  Future<void> _cargarDatosExistentes() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('partidos').doc(widget.partidoId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _rivalController.text = data['rival'];
        _jornadaController.text = data['jornada'] ?? ''; // Cargamos jornada
        _esLocal = data['es_local'];
        _torneo = data['torneo'] ?? 'apertura';
        _estado = data['estado'] ?? 'programado';
        _fechaSeleccionada = (data['fecha'] as Timestamp).toDate();

        List<dynamic> resultadosPrevios = data['resultados'] ?? [];
        for (var res in resultadosPrevios) {
          String cat = res['categoria'].toString();
          if (_resultadosTemp.containsKey(cat)) {
            _resultadosTemp[cat]!['propios'] = res['goles_propios'] ?? 0;
            _resultadosTemp[cat]!['rival'] = res['goles_rival'] ?? 0;
          }
        }
      }
    } catch (e) {
      print("Error cargando partido: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPartido() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    // Guardamos preferencias para la próxima carga
    await _guardarConfiguracionActual();

    List<Map<String, dynamic>> listaResultadosFinal = [];
    _resultadosTemp.forEach((cat, goles) {
      listaResultadosFinal.add({
        'categoria': cat,
        'goles_propios': goles['propios'],
        'goles_rival': goles['rival'],
      });
    });

    final datos = {
      'rival': _rivalController.text.toUpperCase(),
      'jornada': _jornadaController.text.trim(), // Guardamos jornada
      'fecha': Timestamp.fromDate(_fechaSeleccionada),
      'es_local': _esLocal,
      'torneo': _torneo,
      'estado': _estado,
      'deporte_id': widget.deporteId,
      'resultados': listaResultadosFinal,
    };

    try {
      if (widget.partidoId == null) {
        await FirebaseFirestore.instance.collection('partidos').add(datos);
      } else {
        await FirebaseFirestore.instance.collection('partidos').doc(widget.partidoId).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partidoId == null ? "Nuevo Partido" : "Editar Partido"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardarPartido,
          )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- DATOS GENERALES ---
            const Text("Datos Generales", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // RIVAL
            TextFormField(
              controller: _rivalController,
              decoration: const InputDecoration(labelText: "Nombre del Rival", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Ingresa el rival" : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),

            // JORNADA (FECHA NRO)
            TextFormField(
              controller: _jornadaController,
              decoration: const InputDecoration(labelText: "Jornada (Ej: Fecha 4)", border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),

            // TORNEO Y ESTADO
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _torneo,
                    decoration: const InputDecoration(labelText: "Torneo", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'apertura', child: Text("Apertura")),
                      DropdownMenuItem(value: 'clausura', child: Text("Clausura")),
                    ],
                    onChanged: (v) => setState(() => _torneo = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _estado,
                    decoration: const InputDecoration(labelText: "Estado", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'programado', child: Text("Programado")),
                      DropdownMenuItem(value: 'finalizado', child: Text("Finalizado")),
                    ],
                    onChanged: (v) => setState(() => _estado = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // FECHA Y LOCALÍA
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text("${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}"),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fechaSeleccionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _fechaSeleccionada = picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: Text(_esLocal ? "Somos LOCAL" : "Somos VISITANTE"),
                  selected: _esLocal,
                  onSelected: (v) => setState(() => _esLocal = v),
                  selectedColor: widget.config.colorPrimario.withOpacity(0.3),
                  checkmarkColor: widget.config.colorPrimario,
                ),
              ],
            ),

            const Divider(height: 40, thickness: 2),

            // --- CARGA DE RESULTADOS ---
            const Text("Planilla de Resultados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Si el partido no se jugó, dejá todo en 0.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 15),

            // RENDERIZADO DINÁMICO DE CATEGORÍAS
            if (_categorias.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No se encontraron categorías configuradas.", style: TextStyle(color: Colors.red)),
              )
            else
              ..._categorias.map((cat) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                              RegExp(r'^[0-9]+$').hasMatch(cat) ? "Cat. $cat" : cat,
                              style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                        // INPUT GOLES PROPIOS
                        Expanded(
                          child: TextFormField(
                            initialValue: _resultadosTemp[cat]!['propios'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Nuestros", isDense: true),
                            onChanged: (v) => _resultadosTemp[cat]!['propios'] = int.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // INPUT GOLES RIVAL
                        Expanded(
                          child: TextFormField(
                            initialValue: _resultadosTemp[cat]!['rival'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Rival", isDense: true),
                            onChanged: (v) => _resultadosTemp[cat]!['rival'] = int.tryParse(v) ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _guardarPartido,
              child: const Text("GUARDAR PARTIDO"),
            ),
          ],
        ),
      ),
    );
  }
}