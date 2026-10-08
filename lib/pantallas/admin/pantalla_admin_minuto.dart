import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/logica_minuto.dart';
import '../pantalla_historial_minuto.dart';

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
  String get _nombreClubLocal {
    if (ServicioDatosClub.usaTuSedeCentral) {
      final nombre = ContextoClub.nombreClub.trim();

      if (nombre.isNotEmpty) {
        return nombre;
      }
    }

    return widget.config.nombreApp;
  }

  // Variables para crear partido
  String _categoriaSeleccionada = '';
  bool _guardando = false;
  String? _errorCategorias;
  bool _cargandoPlantel = false;
  String? _sesionVisible;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _vivoStream;

  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (_guardando || !mounted) {
      return;
    }
    setState(() => _guardando = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la operación: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _validarPartido(Map<String, dynamic>? data, String? sesion) {
    if (data == null || data['activo'] != true || data['sesion_id'] != sesion) {
      throw StateError('El partido cambió o ya terminó. Revisá la consola.');
    }
  }

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
    _vivoStream = ServicioDatosClub.partidosEnVivo
        .doc(widget.deporteId)
        .snapshots();
    _cargarCategoriasDelDeporte();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _actualizarReloj();
    });
  }

  Future<void> _cargarCategoriasDelDeporte() async {
    if (mounted) {
      setState(() {
        _cargandoCategorias = true;
        _errorCategorias = null;
      });
    }
    List<String> categoriasEncontradas = [];
    try {
      final doc = await ServicioDatosClub.configuracion.doc('general').get();
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
      if (mounted) {
        setState(() {
          _errorCategorias = 'No se pudo leer la configuración: $e';
          _cargandoCategorias = false;
        });
      }
      return;
    }

    categoriasEncontradas = categoriasEncontradas
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    if (categoriasEncontradas.isEmpty && ServicioDatosClub.usaTuSedeCentral) {
      if (mounted) {
        setState(() {
          _errorCategorias =
              'Configurá categorías para esta tira antes de iniciar un partido.';
          _cargandoCategorias = false;
        });
      }
      return;
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
    if (_cargandoPlantel || !mounted) {
      return;
    }
    _cargandoPlantel = true;
    _jugadoresLocales = [];
    _categoriaPlantelCargado = categoria;
    try {
      final snap = await ServicioDatosClub.jugadores
          .where('deporte_id', isEqualTo: widget.deporteId)
          .where('categoria', isEqualTo: categoria)
          .get();

      List<Map<String, dynamic>>
      lista = snap.docs.where((doc) => doc.data()['rol'] != 'DT').map((doc) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cargar el plantel. Podés ingresar el autor manualmente: $e',
            ),
          ),
        );
      }
    } finally {
      _cargandoPlantel = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _actualizarReloj() {
    if (_inicioTiempoRef == null ||
        (_estadoRef != '1T' && _estadoRef != '2T')) {
      return;
    }
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

    if (confirm == true && mounted) {
      try {
        final snapshot = await ServicioDatosClub.historialPartidos
            .where('deporte_id', isEqualTo: widget.deporteId)
            .get();
        for (var offset = 0; offset < snapshot.docs.length; offset += 400) {
          final batch = ServicioDatosClub.firestore.batch();
          for (final doc in snapshot.docs.skip(offset).take(400)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Historial limpio.")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No se completó la limpieza. Revisá el historial antes de reintentar.",
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _iniciarTransmision() => _ejecutar(() async {
    if (_rivalNombre.trim().isEmpty || _categoriaSeleccionada.isEmpty) {
      throw StateError('Completá categoría y rival.');
    }
    final ref = ServicioDatosClub.partidosEnVivo.doc(widget.deporteId);
    final sesion = ServicioDatosClub.historialPartidos.doc().id;
    await ServicioDatosClub.firestore.runTransaction((tx) async {
      final previo = await tx.get(ref);
      if (previo.data()?['activo'] == true) {
        throw StateError('Ya hay una transmisión activa en esta tira.');
      }
      tx.set(ref, {
        'sesion_id': sesion,
        'deporte_id': widget.deporteId,
        'activo': true,
        'categoria': _categoriaSeleccionada,
        'rival': _rivalNombre.trim(),
        'escudo_rival': _rivalEscudo,
        'goles_local': 0,
        'goles_visita': 0,
        'estado': '1T',
        'inicio_tiempo': FieldValue.serverTimestamp(),
        'inicio_partido_real': FieldValue.serverTimestamp(),
        'eventos': [],
      });
    });
    await _cargarJugadoresLocales(_categoriaSeleccionada);
  });

  Future<void> _cambiarEstado(String nuevoEstado, {String? motivoSuspension}) {
    final sesion = _sesionVisible;
    final estadoEsperado = _estadoRef;
    return _ejecutar(() async {
      final ref = ServicioDatosClub.partidosEnVivo.doc(widget.deporteId);
      final historial = ServicioDatosClub.historialPartidos.doc();
      await ServicioDatosClub.firestore.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        final data = snapshot.data();
        _validarPartido(data, sesion);
        if (data!['estado'] != estadoEsperado) {
          throw StateError('El tiempo del partido cambió. Revisá la consola.');
        }
        final cambios = <String, dynamic>{'estado': nuevoEstado};
        if (nuevoEstado == '2T') {
          cambios['inicio_tiempo'] = FieldValue.serverTimestamp();
        }
        if (nuevoEstado == 'FINALIZADO' || nuevoEstado == 'SUSPENDIDO') {
          cambios['activo'] = false;
          if (motivoSuspension != null) {
            cambios['motivo_suspension'] = motivoSuspension;
          }
          // Archivo y cierre atómicos: no se duplica el historial al reintentar.
          tx.set(historial, {
            ...data,
            ...cambios,
            'deporte_id': widget.deporteId,
            'fecha': FieldValue.serverTimestamp(),
          });
        }
        tx.update(ref, cambios);
      });
    });
  }

  Future<void> _guardarEvento(
    Map<String, dynamic> evento, {
    bool borrar = false,
  }) {
    final sesion = _sesionVisible;
    return _ejecutar(() async {
      final ref = ServicioDatosClub.partidosEnVivo.doc(widget.deporteId);
      await ServicioDatosClub.firestore.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        final data = snapshot.data();
        _validarPartido(data, sesion);
        final nuevo = {...evento};
        if (!borrar) nuevo['minuto'] = _calcularTiempoEvento(data!);
        final cambios = LogicaMinuto.actualizarEvento(
          data!,
          nuevo,
          borrar: borrar,
        );
        if (cambios.isNotEmpty) tx.update(ref, cambios);
      });
    });
  }

  Future<void> _borrarEvento(Map<String, dynamic> evento) =>
      _guardarEvento(evento, borrar: true);

  Future<void> _agregarEventoBase(String tipo, String equipo, String detalle) =>
      _guardarEvento({
        'tipo': tipo,
        'equipo': equipo,
        'detalle': detalle,
        'timestamp': DateTime.now().toIso8601String(),
      });

  Future<void> _registrarGolLocal(
    String? idAutor,
    String nombreAutor,
    String? idAsistencia,
    String? nombreAsistencia,
  ) => _guardarEvento({
    'tipo': 'gol',
    'equipo': 'local',
    'detalle': nombreAsistencia == null || nombreAsistencia.trim().isEmpty
        ? nombreAutor
        : '$nombreAutor (Asistencia: $nombreAsistencia)',
    'idAutor': idAutor,
    'idAsistencia': idAsistencia,
    'timestamp': DateTime.now().toIso8601String(),
  });

  // --- DIÁLOGOS ---
  void _dialogoGolLocal() {
    final sesionDialogo = _sesionVisible;
    String? seleccionAutor;
    String? idAutor;
    String? nombreAutor;

    String? seleccionAsistencia;
    String? idAsistencia;
    String? nombreAsistencia;

    final autorManualCtrl = TextEditingController();
    final asistenciaManualCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("⚽ GOL DE $_nombreClubLocal"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: seleccionAutor,
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
                      if (seleccionAsistencia == v) {
                        seleccionAsistencia = null;
                        idAsistencia = null;
                        nombreAsistencia = null;
                      }
                      if (v == 'manual') {
                        idAutor = null;
                        nombreAutor = autorManualCtrl.text;
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
                    controller: autorManualCtrl,
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
                  initialValue: seleccionAsistencia,
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
                        nombreAsistencia = asistenciaManualCtrl.text;
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
                    controller: asistenciaManualCtrl,
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
                if (sesionDialogo != _sesionVisible) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El partido cambió. Abrí nuevamente la acción.',
                      ),
                    ),
                  );
                  return;
                }
                if (seleccionAutor == 'manual' &&
                    autorManualCtrl.text.trim().isEmpty) {
                  return;
                }

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
    final sesionDialogo = _sesionVisible;
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
              if (sesionDialogo != _sesionVisible) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'El partido cambió. Abrí nuevamente la acción.',
                    ),
                  ),
                );
                return;
              }
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
    final sesionDialogo = _sesionVisible;
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
                  if (sesionDialogo != _sesionVisible) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El partido cambió. Abrí nuevamente la acción.',
                        ),
                      ),
                    );
                    return;
                  }
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
    final sesionDialogo = _sesionVisible;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
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
              if (sesionDialogo != _sesionVisible) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'El partido cambió. Abrí nuevamente la acción.',
                    ),
                  ),
                );
                return;
              }
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
      body: AbsorbPointer(
        absorbing: _guardando,
        child: StreamBuilder<DocumentSnapshot>(
          stream: _vivoStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('No se pudo leer el vivo: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            bool activo = false;
            if (snapshot.data!.exists) {
              final d = snapshot.data!.data() as Map<String, dynamic>;
              activo = d['activo'] ?? false;
            }
            if (!activo) {
              _inicioTiempoRef = null;
              _estadoRef = '';
              _sesionVisible = null;
              return _buildPantallaConfiguracion();
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            _sesionVisible = data['sesion_id'] as String?;
            _estadoRef = data['estado'] ?? '1T';
            _inicioTiempoRef = data['inicio_tiempo'] as Timestamp?;
            if (_categoriaPlantelCargado != data['categoria']) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _cargarJugadoresLocales(data['categoria']);
              });
            }
            return _buildConsolaEnVivo(data);
          },
        ),
      ),
    );
  }

  Widget _buildPantallaConfiguracion() {
    if (_cargandoCategorias) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCategorias != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorCategorias!),
            TextButton(
              onPressed: _cargarCategoriasDelDeporte,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
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
            initialValue: _categoriaSeleccionada,
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
          if (ServicioDatosClub.usaTuSedeCentral)
            TextFormField(
              initialValue: _rivalNombre,
              decoration: const InputDecoration(
                labelText: 'Rival',
                border: OutlineInputBorder(),
              ),
              onChanged: (valor) {
                _rivalNombre = valor;
                _rivalEscudo = '';
              },
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: ServicioDatosClub.rivales
                  .where('deporte_id', isEqualTo: widget.deporteId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('No se pudieron cargar los rivales.');
                }
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
                  onChanged: (v) {
                    final elegido = snapshot.data!.docs.firstWhere(
                      (d) => d.id == v,
                    );
                    final data = elegido.data() as Map<String, dynamic>;
                    setState(() {
                      _rivalNombre = (data['nombre'] ?? '').toString();
                      _rivalEscudo = (data['escudo_url'] ?? '').toString();
                    });
                  },
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
          TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('VER HISTORIAL'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PantallaHistorialMinuto(
                  config: widget.config,
                  deporteId: widget.deporteId,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever),
            label: const Text("LIMPIAR HISTORIAL (NUEVA FECHA)"),
            onPressed: () => _ejecutar(_limpiarHistorial),
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
                      _nombreClubLocal,
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
                  e['equipo'] == 'local' ? _nombreClubLocal : rival,
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
                    final sesionDialogo = _sesionVisible;
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
                              if (sesionDialogo == _sesionVisible) {
                                _borrarEvento(e);
                              }
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
