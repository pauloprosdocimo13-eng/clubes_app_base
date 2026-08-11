import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminAsistencia extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminAsistencia({super.key, required this.config});

  @override
  State<PantallaAdminAsistencia> createState() =>
      _PantallaAdminAsistenciaState();
}

class _PantallaAdminAsistenciaState extends State<PantallaAdminAsistencia> {
  // Selectores
  String? _actividadSeleccionada;
  final TextEditingController _grupoCtrl =
      TextEditingController(); // Para "Clase 18hs", "Grupo A", etc.
  DateTime _fecha = DateTime.now();

  List<String> _actividadesDisponibles = [];
  bool _cargando = true;

  // Estado de asistencia { 'id_socio': true/false }
  Map<String, bool> _asistencia = {};
  bool _yaGuardadoHoy = false;

  // Filtro local (Buscador por nombre o categoría)
  String _filtroTexto = "";

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) {
      _cargarActividadesDesdePrecios();
    });
  }

  // --- FUNCIÓN INTELIGENTE PARA LEER ACTIVIDADES COMPUESTAS ---
  bool _socioHaceActividad(Map<String, dynamic> data, String actividadBuscada) {
    if (actividadBuscada.isEmpty) return false;
    List<String> listaActs = [];

    if (data['actividades'] != null && data['actividades'] is List) {
      for (var a in data['actividades']) {
        // Cortamos por comas o símbolos de suma por las dudas
        listaActs.addAll(
          a.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
        );
      }
    } else if (data['actividad'] != null) {
      listaActs = data['actividad']
          .toString()
          .split(RegExp(r'[,+]'))
          .map((e) => e.trim())
          .toList();
    }

    return listaActs.any(
      (act) => act.toLowerCase() == actividadBuscada.toLowerCase(),
    );
  }

  // --- CARGAR DESDE PRECIOS ---
  Future<void> _cargarActividadesDesdePrecios() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        Map<String, dynamic> mapaPrecios = data['precios_cuotas'] ?? data;

        List<String> listaTemp = [];
        mapaPrecios.forEach((key, value) {
          if (!key.startsWith('_') && key != 'fecha_actualizacion') {
            listaTemp.add(key);
          }
        });

        listaTemp.sort();

        if (mounted) {
          setState(() {
            _actividadesDisponibles = listaTemp;
            _cargando = false;
            if (_actividadesDisponibles.isNotEmpty) {
              _actividadSeleccionada = _actividadesDisponibles.first;
              _buscarAsistenciaGuardada();
            }
          });
        }
      }
    } catch (e) {
      print("Error cargando precios: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _buscarAsistenciaGuardada() async {
    if (_actividadSeleccionada == null) return;

    if (mounted) setState(() => _cargando = true);
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);

    final idDoc = "${_actividadSeleccionada}_$fechaStr";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('asistencias')
          .doc(idDoc)
          .get();

      if (mounted) {
        if (doc.exists) {
          final data = doc.data()!;
          final presentes = List<String>.from(data['presentes'] ?? []);
          setState(() {
            _asistencia = {for (var id in presentes) id: true};
            _grupoCtrl.text = data['grupo_etiqueta'] ?? '';
            _yaGuardadoHoy = true;
            _cargando = false;
          });
        } else {
          setState(() {
            _asistencia = {};
            _grupoCtrl.text = "";
            _yaGuardadoHoy = false;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarAsistencia() async {
    if (_actividadSeleccionada == null) return;

    setState(() => _cargando = true);
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);
    final idDoc = "${_actividadSeleccionada}_$fechaStr";

    List<String> presentes = [];
    _asistencia.forEach((key, valor) {
      if (valor) presentes.add(key);
    });

    try {
      await FirebaseFirestore.instance
          .collection('asistencias')
          .doc(idDoc)
          .set({
            'fecha': Timestamp.fromDate(_fecha),
            'actividad': _actividadSeleccionada,
            'grupo_etiqueta': _grupoCtrl.text.trim(),
            'presentes': presentes,
            'total_presentes': presentes.length,
            'mes_anio': DateFormat('yyyy-MM').format(_fecha),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Asistencia guardada correctamente")),
        );
        setState(() => _yaGuardadoHoy = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error al guardar")));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- REPORTES ---
  void _mostrarReporteInterno() async {
    DateTime mes = DateTime(_fecha.year, _fecha.month);
    String mesStr = DateFormat('yyyy-MM').format(mes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var query = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('actividad', isEqualTo: _actividadSeleccionada)
          .where('mes_anio', isEqualTo: mesStr)
          .get();

      Map<String, int> conteo = {};
      int totalClases = query.docs.length;

      for (var doc in query.docs) {
        List<dynamic> presentes = doc['presentes'] ?? [];
        for (var p in presentes) {
          conteo[p] = (conteo[p] ?? 0) + 1;
        }
      }

      // ACA APLICAMOS LA LÓGICA INTELIGENTE EN LUGAR DE LA BÚSQUEDA ESTRICTA
      var sociosQuery = await FirebaseFirestore.instance
          .collection('socios')
          .get();

      Map<String, String> mapaNombres = {};
      for (var s in sociosQuery.docs) {
        var d = s.data();
        if (_socioHaceActividad(d, _actividadSeleccionada!)) {
          mapaNombres[s.id] = "${d['apellido']} ${d['nombre']}";
        }
      }

      if (mounted) {
        Navigator.pop(context); // Cerrar loading

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              "Resumen ${DateFormat('MMMM', 'es').format(mes)} - $_actividadSeleccionada",
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total clases registradas: $totalClases"),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: mapaNombres.length,
                      itemBuilder: (c, i) {
                        String id = mapaNombres.keys.elementAt(i);
                        String nombre = mapaNombres[id]!;
                        int asistencias = conteo[id] ?? 0;
                        double porcentaje = totalClases == 0
                            ? 0
                            : (asistencias / totalClases);

                        return ListTile(
                          title: Text(nombre),
                          subtitle: LinearProgressIndicator(
                            value: porcentaje,
                            color: widget.config.colorPrimario,
                          ),
                          trailing: Text("$asistencias / $totalClases"),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CERRAR"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print(e);
    }
  }

  // --- NAVEGACIÓN INTELIGENTE DEL EXCEL ---
  Future<void> _exportarExcel() async {
    setState(() => _cargando = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Asistencias'];

      String mesStr = DateFormat('yyyy-MM').format(_fecha);

      var asistenciasQuery = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('actividad', isEqualTo: _actividadSeleccionada)
          .where('mes_anio', isEqualTo: mesStr)
          .get();

      Map<String, int> conteo = {};
      int totalClases = asistenciasQuery.docs.length;

      List<DocumentSnapshot> docsOrdenados = asistenciasQuery.docs.toList();

      docsOrdenados.sort((a, b) {
        Timestamp tA = a['fecha'] ?? Timestamp.now();
        Timestamp tB = b['fecha'] ?? Timestamp.now();
        return tA.compareTo(tB);
      });

      List<String> columnasFechas = [];
      Map<String, Set<String>> presentesPorDia = {};

      for (var doc in docsOrdenados) {
        final data = doc.data() as Map<String, dynamic>;

        String diaStr = "S/F";
        if (data['fecha'] != null) {
          diaStr = DateFormat(
            'dd/MM',
          ).format((data['fecha'] as Timestamp).toDate());
        }

        columnasFechas.add(diaStr);

        List<dynamic> presentes = data['presentes'] ?? [];
        presentesPorDia[diaStr] = presentes.map((e) => e.toString()).toSet();

        for (var p in presentes) {
          conteo[p] = (conteo[p] ?? 0) + 1;
        }
      }

      List<CellValue> encabezados = [
        TextCellValue("Apellido"),
        TextCellValue("Nombre"),
        TextCellValue("DNI"),
        TextCellValue("Actividad"),
        TextCellValue("Categoría"), // NUEVO CAMPO EN EXCEL
        TextCellValue("Asistencias"),
        TextCellValue("% Asist."),
      ];

      for (var dia in columnasFechas) {
        encabezados.add(TextCellValue(dia));
      }
      sheetObject.appendRow(encabezados);

      // ACA TAMBIÉN APLICAMOS LA LÓGICA INTELIGENTE PARA EL EXCEL
      var sociosQuery = await FirebaseFirestore.instance
          .collection('socios')
          .get();

      for (var s in sociosQuery.docs) {
        var data = s.data();
        if (!_socioHaceActividad(data, _actividadSeleccionada!)) continue;

        int asistencias = conteo[s.id] ?? 0;
        double porcentaje = totalClases == 0
            ? 0
            : (asistencias / totalClases) * 100;

        List<CellValue> filaSocio = [
          TextCellValue(data['apellido'] ?? ''),
          TextCellValue(data['nombre'] ?? ''),
          TextCellValue(data['dni'] ?? ''),
          TextCellValue(_actividadSeleccionada!),
          TextCellValue(data['categoria_deporte'] ?? ''), // NUEVO CAMPO
          IntCellValue(asistencias),
          TextCellValue("${porcentaje.toStringAsFixed(1)}%"),
        ];

        for (var dia in columnasFechas) {
          bool estabaPresente = presentesPorDia[dia]?.contains(s.id) ?? false;
          filaSocio.add(TextCellValue(estabaPresente ? "P" : "A"));
        }

        sheetObject.appendRow(filaSocio);
      }

      var fileBytes = excel.save();
      String nombreArchivo =
          "asistencia_${_actividadSeleccionada}_$mesStr.xlsx";

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        String? rutaSalida = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar Excel de Asistencias',
          fileName: nombreArchivo,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (rutaSalida != null) {
          File(rutaSalida)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes!);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Excel guardado exitosamente"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/$nombreArchivo";
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);

        await Share.shareXFiles([
          XFile(path),
        ], text: "Planilla Asistencia $_actividadSeleccionada - Mes: $mesStr");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error exportando: $e")));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control de Asistencia"),
        backgroundColor: widget.config.colorPrimario,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: "Ver Resumen Mensual",
            onPressed: _mostrarReporteInterno,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Exportar Excel",
            onPressed: _exportarExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BARRA DE CONFIGURACIÓN (Actividad y Fecha)
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[100],
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _actividadSeleccionada,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Selecciona Actividad",
                    prefixIcon: Icon(Icons.sports),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _actividadesDisponibles
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _actividadSeleccionada = val;
                      _filtroTexto = "";
                    });
                    _buscarAsistenciaGuardada();
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy').format(_fecha),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _grupoCtrl,
                        decoration: const InputDecoration(
                          labelText: "Etiqueta/Grupo (Opcional)",
                          hintText: "Ej: Juveniles",
                          border: OutlineInputBorder(),
                          isDense: true,
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. BUSCADOR RÁPIDO Y FILTRO DE CATEGORÍA
          if (_actividadSeleccionada != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Buscar alumno o categoría (Ej: 2012)",
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) =>
                    setState(() => _filtroTexto = val.toLowerCase()),
              ),
            ),

          // 3. LISTA DE SOCIOS (CON BÚSQUEDA INTELIGENTE)
          Expanded(
            child: _actividadSeleccionada == null
                ? const Center(
                    child: Text("👆 Selecciona una actividad para comenzar"),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('socios')
                        .snapshots(), // Le quitamos el filtro rígido a Firebase
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      // Filtrado inteligente en memoria
                      var docsFiltrados = docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;

                        // Si no hace la actividad, lo descartamos
                        if (!_socioHaceActividad(data, _actividadSeleccionada!))
                          return false;

                        // Si buscó un nombre o categoría y no coincide, lo descartamos
                        if (_filtroTexto.isNotEmpty) {
                          String catStr = (data['categoria_deporte'] ?? '')
                              .toString()
                              .toLowerCase();
                          String nombreCompleto =
                              "${data['apellido']} ${data['nombre']} $catStr"
                                  .toLowerCase();
                          if (!nombreCompleto.contains(_filtroTexto))
                            return false;
                        }

                        return true;
                      }).toList();

                      // Ordenamos alfabéticamente
                      docsFiltrados.sort((a, b) {
                        var dA = a.data() as Map<String, dynamic>;
                        var dB = b.data() as Map<String, dynamic>;
                        return (dA['apellido'] ?? '').toString().compareTo(
                          dB['apellido'] ?? '',
                        );
                      });

                      if (docsFiltrados.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.group_off,
                                size: 50,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No hay socios inscriptos en $_actividadSeleccionada",
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docsFiltrados.length,
                        itemBuilder: (context, index) {
                          final data =
                              docsFiltrados[index].data()
                                  as Map<String, dynamic>;
                          final id = docsFiltrados[index].id;
                          final nombre =
                              "${data['apellido']} ${data['nombre']}";
                          final dni = data['dni'] ?? '---';
                          final presente = _asistencia[id] ?? false;

                          // LEEMOS LA CATEGORÍA PARA MOSTRARLA
                          final categoriaDeporte =
                              data['categoria_deporte'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            elevation: 1,
                            color: presente ? Colors.green[50] : Colors.white,
                            child: CheckboxListTile(
                              title: Text(
                                nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: presente
                                      ? Colors.black
                                      : Colors.grey[800],
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text("DNI: $dni"),
                                  if (categoriaDeporte.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        categoriaDeporte,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              secondary: CircleAvatar(
                                backgroundImage:
                                    (data['foto_url'] != null &&
                                        data['foto_url'] != '')
                                    ? NetworkImage(data['foto_url'])
                                    : null,
                                backgroundColor: presente
                                    ? Colors.green
                                    : Colors.grey[300],
                                child:
                                    (data['foto_url'] == null ||
                                        data['foto_url'] == '')
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              value: presente,
                              activeColor: Colors.green,
                              onChanged: (val) {
                                setState(() {
                                  _asistencia[id] = val!;
                                  _yaGuardadoHoy = false;
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // 4. BARRA INFERIOR (GUARDAR)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_yaGuardadoHoy)
                    const Expanded(
                      child: Text(
                        "✅ LISTA GUARDADA",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Expanded(
                      child: Text(
                        "⚠️ CAMBIOS SIN GUARDAR",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _cargando ? null : _guardarAsistencia,
                    icon: const Icon(Icons.save),
                    label: const Text("GUARDAR ASISTENCIA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
