import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaAdminFormularioPartido extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? partidoId;

  const PantallaAdminFormularioPartido({
    super.key,
    required this.config,
    required this.deporteId,
    this.partidoId,
  });

  @override
  State<PantallaAdminFormularioPartido> createState() =>
      _PantallaAdminFormularioPartidoState();
}

class _PantallaAdminFormularioPartidoState
    extends State<PantallaAdminFormularioPartido> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _rivalController = TextEditingController();
  final TextEditingController _jornadaController = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  bool _esLocal = true;
  String _torneo = 'apertura';
  String _estado = 'programado';

  Map<String, Map<String, dynamic>> _resultadosTemp = {};
  List<String> _categorias = [];
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
  }

  @override
  void dispose() {
    _rivalController.dispose();
    _jornadaController.dispose();
    super.dispose();
  }

  String _clavePreferencia(String clave) => ServicioDatosClub.usaTuSedeCentral
      ? 'partidos_${ContextoClub.clubId}_${widget.deporteId}_$clave'
      : clave;

  Future<void> _inicializarPantalla() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      await _cargarCategoriasDelDeporte();
      if (!mounted) return;
      if (widget.partidoId != null) {
        await _cargarDatosExistentes();
      } else {
        await _cargarUltimaConfiguracion();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorCarga = 'No se pudo cargar el partido: $e');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarUltimaConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoTorneo = prefs.getString(_clavePreferencia('ultimo_torneo'));
    final ultimaJornada = prefs.getString(_clavePreferencia('ultima_jornada'));
    final ultimaFechaMillis = prefs.getInt(
      _clavePreferencia('ultima_fecha_millis'),
    );
    final esLocal = prefs.getBool(_clavePreferencia('ultimo_es_local'));

    if (!mounted) return;
    setState(() {
      if (['apertura', 'clausura'].contains(ultimoTorneo)) {
        _torneo = ultimoTorneo!;
      }
      if (ultimaJornada != null) _jornadaController.text = ultimaJornada;
      if (esLocal != null) _esLocal = esLocal;
      if (ultimaFechaMillis != null) {
        _fechaSeleccionada = DateTime.fromMillisecondsSinceEpoch(
          ultimaFechaMillis,
        );
      }
    });
  }

  Future<void> _guardarConfiguracionActual() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePreferencia('ultimo_torneo'), _torneo);
    await prefs.setString(
      _clavePreferencia('ultima_jornada'),
      _jornadaController.text,
    );
    await prefs.setInt(
      _clavePreferencia('ultima_fecha_millis'),
      _fechaSeleccionada.millisecondsSinceEpoch,
    );
    await prefs.setBool(_clavePreferencia('ultimo_es_local'), _esLocal);
  }

  Future<void> _cargarCategoriasDelDeporte() async {
    final doc = await ServicioDatosClub.configuracionDoc('general').get();
    final menu = doc.data()?['menu_deportes'];
    final deportes = menu is List ? menu.whereType<Map>() : <Map>[];
    final deporte = deportes.firstWhere(
      (e) => e['id'] == widget.deporteId,
      orElse: () => <String, dynamic>{},
    );
    final raw = deporte['categorias'];
    final categorias = raw is List
        ? raw
              .map((c) => c.toString())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    if (categorias.isNotEmpty) {
      _categorias = categorias;
    } else if (ServicioDatosClub.usaTuSedeCentral) {
      throw StateError(
        'Configurá las categorías de esta tira antes de cargar partidos.',
      );
    } else {
      _generarCategoriasLegacy();
    }
    _resultadosTemp = {
      for (final cat in _categorias)
        cat: {
          'propios': 0,
          'rival': 0,
          'autores_propios': <String>[],
          'autores_rival': <String>[],
        },
    };
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
      final int anioActual = DateTime.now().year;
      for (int i = anioActual - 13; i <= anioActual - 7; i++) {
        _categorias.add(i.toString());
      }
    }
  }

  Future<void> _cargarDatosExistentes() async {
    final doc = await ServicioDatosClub.partidos.doc(widget.partidoId).get();
    if (!mounted) return;
    if (!doc.exists) throw StateError('El partido ya no existe.');
    final data = doc.data()!;
    if (data['deporte_id'] != widget.deporteId) {
      throw StateError('El partido no pertenece a esta tira.');
    }
    _rivalController.text = (data['rival'] ?? '').toString();
    _jornadaController.text = (data['jornada'] ?? '').toString();
    _esLocal = data['es_local'] != false;
    _torneo = data['torneo'] ?? 'apertura';
    _estado = data['estado'] ?? 'programado';
    if (!['apertura', 'clausura'].contains(_torneo) ||
        !['programado', 'finalizado'].contains(_estado)) {
      throw StateError(
        'El torneo o estado guardado no es compatible con este formulario.',
      );
    }
    _fechaSeleccionada = (data['fecha'] as Timestamp).toDate();
    final resultadosPrevios = data['resultados'] as List? ?? [];
    for (final res in resultadosPrevios) {
      final cat = res['categoria'].toString();
      // Conserva resultados de categorías que se retiraron de la configuración.
      if (!_resultadosTemp.containsKey(cat)) _categorias.add(cat);
      _resultadosTemp[cat] = {
        'propios': res['goles_propios'] ?? 0,
        'rival': res['goles_rival'] ?? 0,
        'autores_propios': List<String>.from(res['autores_propios'] ?? []),
        'autores_rival': List<String>.from(res['autores_rival'] ?? []),
      };
    }
  }

  Future<void> _traerResultadosDelVivo() async {
    setState(() => _cargando = true);
    try {
      DateTime haceDosDias = DateTime.now().subtract(const Duration(days: 2));

      // LE SACAMOS EL FILTRO DE FECHA A FIREBASE PARA EVITAR EL ERROR
      final query = await ServicioDatosClub.historialPartidos
          .where('deporte_id', isEqualTo: widget.deporteId)
          .get();

      if (!mounted) return;
      int categoriasCompletadas = 0;

      for (var doc in query.docs) {
        final data = doc.data();

        // --- FILTRO DE FECHA MANUAL (TRUCO FLUTTER) ---
        if (data['fecha'] != null) {
          DateTime fechaPartido = (data['fecha'] as Timestamp).toDate();
          if (fechaPartido.isBefore(haceDosDias)) {
            continue; // Si el partido es más viejo que 2 días, lo ignoramos y pasamos al siguiente
          }
        }

        String cat = data['categoria'].toString();

        if (_resultadosTemp.containsKey(cat)) {
          int gL = data['goles_local'] ?? 0;
          int gV = data['goles_visita'] ?? 0;

          List eventos = data['eventos'] ?? [];
          List<String> autoresLocales = [];
          List<String> autoresVisita = [];

          for (var e in eventos) {
            if (e['tipo'] == 'gol') {
              if (e['equipo'] == 'local') {
                autoresLocales.add(e['detalle'] ?? 'Gol local');
              } else {
                autoresVisita.add(e['detalle'] ?? 'Gol rival');
              }
            }
          }

          // REEMPLAZALO POR ESTO:
          _resultadosTemp[cat]!['propios'] = gL;
          _resultadosTemp[cat]!['rival'] = gV;

          _resultadosTemp[cat]!['autores_propios'] = autoresLocales;
          _resultadosTemp[cat]!['autores_rival'] = autoresVisita;

          categoriasCompletadas++;
        }
      }

      if (categoriasCompletadas > 0) {
        _estado = 'finalizado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "¡Magia! Se rellenaron los resultados y goleadores de $categoriasCompletadas categorías.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se encontraron partidos recientes."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al buscar en el historial: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPartido() async {
    if (_cargando || _errorCarga != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _cargando = true);

    List<Map<String, dynamic>> listaResultadosFinal = [];
    _resultadosTemp.forEach((cat, datosResultados) {
      listaResultadosFinal.add({
        'categoria': cat,
        'goles_propios': datosResultados['propios'],
        'goles_rival': datosResultados['rival'],
        'autores_propios': datosResultados['autores_propios'] ?? [],
        'autores_rival': datosResultados['autores_rival'] ?? [],
      });
    });

    final datos = {
      'rival': _rivalController.text.toUpperCase(),
      'jornada': _jornadaController.text.trim(),
      'fecha': Timestamp.fromDate(_fechaSeleccionada),
      'es_local': _esLocal,
      'torneo': _torneo,
      'estado': _estado,
      'deporte_id': widget.deporteId,
      'resultados': listaResultadosFinal,
    };

    try {
      await _guardarConfiguracionActual();
      if (widget.partidoId == null) {
        await ServicioDatosClub.partidos.add(datos);
      } else {
        await ServicioDatosClub.partidos.doc(widget.partidoId).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.partidoId == null ? "Nuevo Partido" : "Editar Partido",
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _cargando || _errorCarga != null
                ? null
                : _guardarPartido,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorCarga!),
                  TextButton(
                    onPressed: _inicializarPantalla,
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "Datos Generales",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _rivalController,
                    decoration: const InputDecoration(
                      labelText: "Nombre del Rival",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? "Ingresa el rival" : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _jornadaController,
                    decoration: const InputDecoration(
                      labelText: "Jornada (Ej: Fecha 4)",
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _torneo,
                          decoration: const InputDecoration(
                            labelText: "Torneo",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'apertura',
                              child: Text("Apertura"),
                            ),
                            DropdownMenuItem(
                              value: 'clausura',
                              child: Text("Clausura"),
                            ),
                          ],
                          onChanged: (v) => setState(() => _torneo = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _estado,
                          decoration: const InputDecoration(
                            labelText: "Estado",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'programado',
                              child: Text("Programado"),
                            ),
                            DropdownMenuItem(
                              value: 'finalizado',
                              child: Text("Finalizado"),
                            ),
                          ],
                          onChanged: (v) => setState(() => _estado = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaSeleccionada,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null && mounted) {
                              setState(() => _fechaSeleccionada = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        label: Text(
                          _esLocal ? "Somos LOCAL" : "Somos VISITANTE",
                        ),
                        selected: _esLocal,
                        onSelected: (v) => setState(() => _esLocal = v),
                        selectedColor: widget.config.colorPrimario.withValues(
                          alpha: 0.3,
                        ),
                        checkmarkColor: widget.config.colorPrimario,
                      ),
                    ],
                  ),

                  const Divider(height: 40, thickness: 2),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Resultados",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!ServicioDatosClub.usaTuSedeCentral)
                        ElevatedButton.icon(
                          onPressed: _traerResultadosDelVivo,
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: const Text("Traer del Vivo"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ServicioDatosClub.usaTuSedeCentral
                        ? "Cargá los resultados de cada categoría."
                        : "Trae los números y los goleadores automáticamente.",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 15),

                  if (_categorias.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "No se encontraron categorías configuradas.",
                        style: TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    ..._categorias.map((cat) {
                      List propiosList =
                          _resultadosTemp[cat]!['autores_propios'] ?? [];
                      List rivalList =
                          _resultadosTemp[cat]!['autores_rival'] ?? [];
                      bool hayGoleadores =
                          propiosList.isNotEmpty || rivalList.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 85,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      RegExp(r'^[0-9]+$').hasMatch(cat)
                                          ? "Cat. $cat"
                                          : cat,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (hayGoleadores)
                                      const Icon(
                                        Icons.sports_soccer,
                                        color: Colors.green,
                                        size: 14,
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'propios_${cat}_${_resultadosTemp[cat]!['propios']}',
                                  ),
                                  initialValue: _resultadosTemp[cat]!['propios']
                                      .toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Nuestros",
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      _resultadosTemp[cat]!['propios'] =
                                          int.tryParse(v) ?? 0,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'rival_${cat}_${_resultadosTemp[cat]!['rival']}',
                                  ),
                                  initialValue: _resultadosTemp[cat]!['rival']
                                      .toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Rival",
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      _resultadosTemp[cat]!['rival'] =
                                          int.tryParse(v) ?? 0,
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
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _cargando ? null : _guardarPartido,
                    child: const Text("GUARDAR PARTIDO FINAL"),
                  ),
                ],
              ),
            ),
    );
  }
}
