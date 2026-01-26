import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminAsistencia extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminAsistencia({super.key, required this.config});

  @override
  State<PantallaAdminAsistencia> createState() => _PantallaAdminAsistenciaState();
}

class _PantallaAdminAsistenciaState extends State<PantallaAdminAsistencia> {
  // Selectores
  String? _deporteId;
  String? _categoria;
  DateTime _fecha = DateTime.now();

  List<Map<String, dynamic>> _deportesDisponibles = [];
  List<String> _categoriasDisponibles = [];
  bool _cargando = true;

  // Estado de asistencia { 'id_jugador': true/false }
  Map<String, bool> _asistencia = {};
  bool _yaGuardadoHoy = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
    if (doc.exists) {
      final menu = List.from(doc.data()!['menu_deportes'] ?? []);
      setState(() {
        _deportesDisponibles = menu.map((e) => e as Map<String, dynamic>).toList();
        _cargando = false;
        if (_deportesDisponibles.isNotEmpty) {
          _deporteId = _deportesDisponibles.first['id'];
          _actualizarCategorias();
        }
      });
    }
  }

  void _actualizarCategorias() {
    final deporte = _deportesDisponibles.firstWhere((d) => d['id'] == _deporteId, orElse: () => {});
    if (deporte.isNotEmpty) {
      setState(() {
        _categoriasDisponibles = List<String>.from(deporte['categorias'] ?? []);
        if (_categoriasDisponibles.isNotEmpty) _categoria = _categoriasDisponibles.first;
      });
      _buscarAsistenciaGuardada();
    }
  }

  Future<void> _buscarAsistenciaGuardada() async {
    // Buscamos si ya se tomó lista hoy para este grupo
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);
    final idDoc = "${_deporteId}_${_categoria}_$fechaStr"; // ID único compuesto

    final doc = await FirebaseFirestore.instance.collection('asistencias').doc(idDoc).get();
    
    if (doc.exists) {
      final presentes = List<String>.from(doc.data()!['presentes'] ?? []);
      setState(() {
        _asistencia = { for (var id in presentes) id : true };
        _yaGuardadoHoy = true;
      });
    } else {
      setState(() {
        _asistencia = {};
        _yaGuardadoHoy = false;
      });
    }
  }

  Future<void> _guardarAsistencia() async {
    if (_deporteId == null || _categoria == null) return;
    
    setState(() => _cargando = true);
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);
    final idDoc = "${_deporteId}_${_categoria}_$fechaStr";

    // Convertimos el mapa a lista de IDs presentes
    List<String> presentes = [];
    _asistencia.forEach((key, valor) {
      if (valor) presentes.add(key);
    });

    try {
      await FirebaseFirestore.instance.collection('asistencias').doc(idDoc).set({
        'fecha': Timestamp.fromDate(_fecha),
        'deporte_id': _deporteId,
        'categoria': _categoria,
        'presentes': presentes,
        'total_presentes': presentes.length,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Asistencia guardada correctamente")));
      setState(() => _yaGuardadoHoy = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control de Asistencia"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. BARRA DE FILTROS SUPERIOR
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[100],
            child: Row(
              children: [
                // Selector Deporte
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _deporteId,
                    isDense: true,
                    decoration: const InputDecoration(labelText: "Actividad", border: OutlineInputBorder()),
                    items: _deportesDisponibles.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['titulo']))).toList(),
                    onChanged: (val) {
                      setState(() => _deporteId = val);
                      _actualizarCategorias();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Selector Categoría
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _categoria,
                    isDense: true,
                    decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
                    items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      setState(() => _categoria = val);
                      _buscarAsistenciaGuardada();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Selector Fecha
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: "Cambiar fecha",
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _fecha = picked);
                      _buscarAsistenciaGuardada();
                    }
                  },
                ),
                Text(DateFormat('dd/MM').format(_fecha), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // 2. LISTA DE JUGADORES
          Expanded(
            child: _deporteId == null || _categoria == null
                ? const Center(child: Text("Seleccione actividad y categoría"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('jugadores')
                        .where('deporte_id', isEqualTo: _deporteId)
                        .where('categoria', isEqualTo: _categoria)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) return const Center(child: Text("No hay jugadores en esta categoría."));

                      // Ordenar por apellido
                      docs.sort((a, b) => (a['apellido'] ?? '').toString().compareTo(b['apellido'] ?? ''));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final id = docs[index].id;
                          final nombre = "${data['apellido']} ${data['nombre']}";
                          final presente = _asistencia[id] ?? false;

                          return CheckboxListTile(
                            title: Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, color: presente ? Colors.black : Colors.grey)),
                            subtitle: Text("DNI: ${data['dni'] ?? 'Sin DNI'}"), // Útil para verificar identidad
                            secondary: CircleAvatar(
                              backgroundColor: presente ? Colors.green : Colors.grey[300],
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            value: presente,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() {
                                _asistencia[id] = val!;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
          ),

          // 3. BARRA DE GUARDADO
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
            child: Row(
              children: [
                if (_yaGuardadoHoy) 
                  const Expanded(child: Text("✅ Asistencia ya registrada hoy", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                else 
                  const Expanded(child: Text("⚠️ Cambios sin guardar", style: TextStyle(color: Colors.orange))),
                
                ElevatedButton.icon(
                  onPressed: _cargando ? null : _guardarAsistencia,
                  icon: const Icon(Icons.save),
                  label: const Text("GUARDAR ASISTENCIA"),
                  style: ElevatedButton.styleFrom(backgroundColor: widget.config.colorPrimario, foregroundColor: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}