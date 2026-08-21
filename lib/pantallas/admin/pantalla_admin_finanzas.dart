import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../configuracion/configuracion_app.dart';
import 'package:file_saver/file_saver.dart';


const List<String> _categoriasFinanzasBase = [
  'Cuotas',
  'Alquileres',
  'Mantenimiento',
  'Servicios',
  'Materiales',
  'Torneos',
  'Sueldos',
  'Merchandising',
];

const String _opcionAgregarCategoria = '__agregar_categoria__';

class _RepositorioCategoriasFinanzas {
  static DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance
          .collection('configuracion')
          .doc('categorias_finanzas');

  static Future<List<String>> cargar() async {
    final categorias = List<String>.from(_categoriasFinanzasBase);

    try {
      final doc = await _docRef.get();
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final guardadas = data['categorias'];
        if (guardadas is List) {
          for (final item in guardadas) {
            _agregarSinDuplicar(categorias, item?.toString() ?? '');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando categorías de finanzas: $e');
    }

    return categorias;
  }

  static Future<List<String>> agregar(String nombre) async {
    final nombreLimpio = _limpiarNombre(nombre);
    if (nombreLimpio.isEmpty) {
      throw ArgumentError('La categoría no puede estar vacía.');
    }

    return FirebaseFirestore.instance.runTransaction<List<String>>((tx) async {
      final snapshot = await tx.get(_docRef);
      final categorias = List<String>.from(_categoriasFinanzasBase);

      if (snapshot.exists) {
        final data = snapshot.data() ?? <String, dynamic>{};
        final guardadas = data['categorias'];
        if (guardadas is List) {
          for (final item in guardadas) {
            _agregarSinDuplicar(categorias, item?.toString() ?? '');
          }
        }
      }

      final existe = categorias.any(
        (c) => c.toLowerCase() == nombreLimpio.toLowerCase(),
      );

      if (!existe) {
        categorias.add(nombreLimpio);
      }

      tx.set(
        _docRef,
        {
          'categorias': categorias,
          'actualizado_en': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return categorias;
    });
  }

  static String _limpiarNombre(String valor) {
    return valor.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static void _agregarSinDuplicar(List<String> lista, String valor) {
    final limpio = _limpiarNombre(valor);
    if (limpio.isEmpty) return;

    final existe = lista.any(
      (c) => c.toLowerCase() == limpio.toLowerCase(),
    );
    if (!existe) {
      lista.add(limpio);
    }
  }
}

class PantallaAdminFinanzas extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminFinanzas({super.key, required this.config});

  @override
  State<PantallaAdminFinanzas> createState() => _PantallaAdminFinanzasState();
}

class _PantallaAdminFinanzasState extends State<PantallaAdminFinanzas>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime _fechaInicio = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _fechaFin = DateTime.now();

  String? _filtroCategoria;
  String _filtroTexto = "";
  List<String> _categoriasFinanzas = List<String>.from(_categoriasFinanzasBase);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarCategoriasFinanzas();
  }

  Future<void> _cargarCategoriasFinanzas() async {
    final categorias = await _RepositorioCategoriasFinanzas.cargar();
    if (!mounted) return;

    setState(() {
      _categoriasFinanzas = categorias;
      if (_filtroCategoria != null &&
          !_categoriasFinanzas.contains(_filtroCategoria)) {
        _filtroCategoria = null;
      }
    });
  }

  Future<void> _seleccionarRangoFecha() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: widget.config.colorPrimario,
            colorScheme: ColorScheme.light(
              primary: widget.config.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end.add(const Duration(hours: 23, minutes: 59));
      });
    }
  }

  void _mostrarFiltrosAvanzados() {
    showDialog(
      context: context,
      builder: (ctx) {
        String? catTemp = _filtroCategoria;
        String txtTemp = _filtroTexto;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Filtros de Reporte"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Buscar (Nombre o Actividad)",
                      hintText: "Ej: Futbol, Perez...",
                      prefixIcon: Icon(Icons.search),
                    ),
                    controller: TextEditingController(text: _filtroTexto),
                    onChanged: (v) => txtTemp = v,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: catTemp,
                    decoration: const InputDecoration(
                      labelText: "Categoría",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._categoriasFinanzas.map(
                        (c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c),
                        ),
                      ),
                    ],
                    onChanged: (v) => setStateDialog(() => catTemp = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filtroCategoria = null;
                      _filtroTexto = "";
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("LIMPIAR"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filtroCategoria = catTemp;
                      _filtroTexto = txtTemp;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("APLICAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Caja y Reportes"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: _mostrarFiltrosAvanzados,
            tooltip: "Filtros",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _seleccionarRangoFecha,
            tooltip: "Fechas",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: widget.config.colorPrimario,
          unselectedLabelColor: Colors.grey,
          indicatorColor: widget.config.colorPrimario,
          isScrollable: true,
          tabs: const [
            Tab(text: "Movimientos"),
            Tab(text: "Liquidación"),
            Tab(text: "Nuevo Registro"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabMovimientos(
            config: widget.config,
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            filtroCategoria: _filtroCategoria,
            filtroTexto: _filtroTexto,
          ),
          _TabRecaudacionActividad(
            config: widget.config,
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
          ),
          _TabNuevoMovimiento(
            config: widget.config,
            categoriasIniciales: _categoriasFinanzas,
            alCategoriasActualizadas: (categorias) {
              if (!mounted) return;
              setState(() => _categoriasFinanzas = categorias);
            },
            alGuardar: () {
              _tabController.animateTo(0);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// TAB 1: LISTADO Y REPORTES
// =========================================================================
class _TabMovimientos extends StatelessWidget {
  final ConfiguracionApp config;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? filtroCategoria;
  final String filtroTexto;

  const _TabMovimientos({
    required this.config,
    required this.fechaInicio,
    required this.fechaFin,
    this.filtroCategoria,
    required this.filtroTexto,
  });

  Future<void> _borrarMovimiento(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    final motivoCtrl = TextEditingController();
    final usuarioCtrl = TextEditingController();

    bool confirmar =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Anular Movimiento"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Vas a anular el registro de \$${data['monto']}. Quedará guardado en el historial de eliminados por seguridad.",
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: usuarioCtrl,
                    decoration: const InputDecoration(
                      labelText: "Tu Usuario / Nombre",
                      hintText: "Ej: Juan Perez",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: motivoCtrl,
                    decoration: const InputDecoration(
                      labelText: "Motivo de la anulación",
                      hintText: "Ej: Me equivoqué de monto",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () {
                  if (usuarioCtrl.text.trim().isEmpty ||
                      motivoCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Debes completar tu nombre y el motivo para continuar",
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text(
                  "ANULAR REGISTRO",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      try {
        await FirebaseFirestore.instance
            .collection('movimientos_eliminados')
            .doc(id)
            .set({
              ...data,
              'motivo_eliminacion': motivoCtrl.text.trim(),
              'usuario_elimino': usuarioCtrl.text.trim(),
              'fecha_eliminacion': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('movimientos')
            .doc(id)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Movimiento anulado y auditado correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al anular: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportarExcel(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Caja'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue("Fecha"),
        TextCellValue("Socio / Nombre"),
        TextCellValue("Concepto / Actividad"),
        TextCellValue("Categoría"),
        TextCellValue("Ingreso (+)"),
        TextCellValue("Egreso (-)"),
      ]);

      double totalIngresos = 0;
      double totalEgresos = 0;

      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;

        DateTime fecha =
            (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
        String fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
        String socio = data['socio_nombre'] ?? '-';
        String concepto = data['concepto'] ?? '';
        String categoria = data['categoria'] ?? 'Varios';
        double monto = (data['monto'] ?? 0).toDouble();
        String tipo = (data['tipo'] ?? '').toString().toLowerCase();

        double ingreso = 0;
        double egreso = 0;

        if (tipo == 'ingreso') {
          ingreso = monto;
          totalIngresos += monto;
        } else {
          egreso = monto;
          totalEgresos += monto;
        }

        sheetObject.appendRow([
          TextCellValue(fechaStr),
          TextCellValue(socio),
          TextCellValue(concepto),
          TextCellValue(categoria),
          DoubleCellValue(ingreso),
          DoubleCellValue(egreso),
        ]);
      }

      sheetObject.appendRow([
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue("TOTALES"),
        TextCellValue(""),
        DoubleCellValue(totalIngresos),
        DoubleCellValue(totalEgresos),
      ]);

      sheetObject.appendRow([
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue("RESULTADO NETO"),
        TextCellValue(""),
        DoubleCellValue(totalIngresos - totalEgresos),
        TextCellValue(""),
      ]);

      var fileBytes = excel.save();
      String nombreArchivo =
          "Reporte_Caja_${DateFormat('dd-MM').format(fechaInicio)}_al_${DateFormat('dd-MM').format(fechaFin)}.xlsx";

      if (kIsWeb) {
        await Share.shareXFiles([
          XFile.fromData(Uint8List.fromList(fileBytes!), name: nombreArchivo),
        ], text: "Reporte de Caja");
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        String? rutaSalida = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar Excel de Caja',
          fileName: nombreArchivo,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (rutaSalida != null) {
          File(rutaSalida)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes!);

          if (context.mounted) {
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
        ], text: "Reporte de Caja $nombreArchivo");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('movimientos')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final allDocs = snapshot.data!.docs;

        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          if (data['fecha'] == null) return false;
          DateTime fechaDoc = (data['fecha'] as Timestamp).toDate();
          if (fechaDoc.isBefore(fechaInicio) || fechaDoc.isAfter(fechaFin)) {
            return false;
          }

          if (filtroCategoria != null) {
            if ((data['categoria'] ?? '') != filtroCategoria) return false;
          }

          if (filtroTexto.isNotEmpty) {
            String concepto = (data['concepto'] ?? '').toString().toLowerCase();
            String socioNombre = (data['socio_nombre'] ?? '')
                .toString()
                .toLowerCase();
            String busqueda = filtroTexto.toLowerCase();

            if (!concepto.contains(busqueda) &&
                !socioNombre.contains(busqueda)) {
              return false;
            }
          }

          return true;
        }).toList();

        double ingresos = 0;
        double egresos = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          double m = (data['monto'] ?? 0).toDouble();
          if ((data['tipo'] ?? '') == 'ingreso')
            ingresos += m;
          else
            egresos += m;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Periodo: ${DateFormat('dd/MM').format(fechaInicio)} - ${DateFormat('dd/MM').format(fechaFin)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (filtroTexto.isNotEmpty)
                          Text(
                            "Filtro: \"$filtroTexto\"",
                            style: TextStyle(
                              fontSize: 12,
                              color: config.colorPrimario,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          "Registros: ${docs.length}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: docs.isEmpty
                        ? null
                        : () => _exportarExcel(context, docs),
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text("EXCEL"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoBalance("Ingresos", ingresos, Colors.green),
                  _InfoBalance("Egresos", egresos, Colors.red),
                  _InfoBalance("Neto", ingresos - egresos, Colors.blue),
                ],
              ),
            ),

            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text("No hay movimientos con estos filtros."),
                    )
                  : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool esIngreso = data['tipo'] == 'ingreso';

                        IconData icon = Icons.attach_money;
                        String cat = data['categoria'] ?? '';
                        if (cat == 'Alquileres') icon = Icons.sports_soccer;
                        if (cat == 'Cuotas') icon = Icons.receipt_long;
                        if (cat == 'Mantenimiento') icon = Icons.build;
                        if (cat == 'Merchandising') icon = Icons.shopping_bag;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: esIngreso
                                ? Colors.green[50]
                                : Colors.red[50],
                            child: Icon(
                              icon,
                              color: esIngreso ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            data['concepto'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['socio_nombre'] != null)
                                Text(
                                  "Socio: ${data['socio_nombre']}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              Text(
                                "${DateFormat('dd/MM HH:mm').format((data['fecha'] as Timestamp).toDate())} • $cat",
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${esIngreso ? '+' : '-'} \$${data['monto']}",
                                style: TextStyle(
                                  color: esIngreso
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 5),
                              IconButton(
                                icon: const Icon(
                                  Icons.print,
                                  color: Colors.blue,
                                ),
                                tooltip: "Ver Comprobante",
                                onPressed: () {
                                  generarComprobantePDF(
                                    context,
                                    config,
                                    data['tipo'] ?? 'ingreso',
                                    (data['monto'] ?? 0).toDouble(),
                                    data['concepto'] ?? '',
                                    data['metodo'] ?? 'Efectivo',
                                    cat,
                                    (data['fecha'] as Timestamp).toDate(),
                                    data['socio_nombre'],
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: "Anular Registro",
                                onPressed: () => _borrarMovimiento(
                                  context,
                                  docs[index].id,
                                  data,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoBalance extends StatelessWidget {
  final String label;
  final double valor;
  final Color color;
  const _InfoBalance(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          "\$${valor.toStringAsFixed(0)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// TAB 2: LIQUIDACIÓN DESPLEGABLE CON REPORTE EXCEL
// =========================================================================
class _TabRecaudacionActividad extends StatefulWidget {
  final ConfiguracionApp config;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const _TabRecaudacionActividad({
    required this.config,
    required this.fechaInicio,
    required this.fechaFin,
  });

  @override
  State<_TabRecaudacionActividad> createState() =>
      _TabRecaudacionActividadState();
}

class _TabRecaudacionActividadState extends State<_TabRecaudacionActividad> {
  String? _actSeleccionada;
  Map<String, double> _preciosCache = {};
  List<String> _actividadesDisponibles = [];
  bool _cargandoPrecios = true;

  @override
  void initState() {
    super.initState();
    _cargarPrecios();
  }

  Future<void> _cargarPrecios() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        Map<String, dynamic> mapaPrecios = data['precios_cuotas'] ?? data;

        _preciosCache.clear();
        _actividadesDisponibles.clear();

        mapaPrecios.forEach((key, value) {
          if (!key.contains('_') && key != 'fecha_actualizacion') {
            _actividadesDisponibles.add(key);
            if (value is num) _preciosCache[key] = value.toDouble();
            if (value is String) {
              _preciosCache[key] = double.tryParse(value) ?? 0;
            }
          }
        });

        _actividadesDisponibles.sort();
      }
    } catch (e) {
      print("Error cargando precios: $e");
    } finally {
      if (mounted) setState(() => _cargandoPrecios = false);
    }
  }

  Future<void> _exportarExcelLiquidacion(
    BuildContext context,
    List<Map<String, dynamic>> items,
    double total,
    int cuotas,
  ) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Liquidacion'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue("Actividad: $_actSeleccionada"),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
      ]);
      sheetObject.appendRow([
        TextCellValue(
          "Periodo: ${DateFormat('dd/MM/yyyy').format(widget.fechaInicio)} al ${DateFormat('dd/MM/yyyy').format(widget.fechaFin)}",
        ),
      ]);
      sheetObject.appendRow([]);

      sheetObject.appendRow([
        TextCellValue("Fecha"),
        TextCellValue("Socio"),
        TextCellValue("Concepto"),
        TextCellValue("Valor Ticket"),
        TextCellValue("Cant. Meses"),
        TextCellValue("Subtotal Liquidado"),
      ]);

      for (var item in items) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(item['fecha'])),
          TextCellValue(item['socio']),
          TextCellValue(item['concepto']),
          DoubleCellValue(item['monto_total_ticket']),
          IntCellValue(item['ocurrencias']),
          DoubleCellValue(item['porcion_actividad']),
        ]);
      }

      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue("TOTAL CUOTAS:"),
        IntCellValue(cuotas),
      ]);
      sheetObject.appendRow([
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue("TOTAL A RENDIR:"),
        DoubleCellValue(total),
      ]);

      var fileBytes = excel.save();
      String nombreArchivo =
          "Liquidacion_${_actSeleccionada}_${DateFormat('dd-MM').format(widget.fechaInicio)}.xlsx";

      if (kIsWeb) {
        await Share.shareXFiles([
          XFile.fromData(Uint8List.fromList(fileBytes!), name: nombreArchivo),
        ], text: "Reporte de Liquidación");
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/$nombreArchivo";
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);
        await Share.shareXFiles([
          XFile(path),
        ], text: "Liquidación $_actSeleccionada");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al exportar liquidación: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoPrecios) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          color: Colors.white,
          child: DropdownButtonFormField<String>(
            value: _actSeleccionada,
            decoration: InputDecoration(
              labelText: "Seleccionar Actividad a Liquidar",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: Icon(
                Icons.sports_score,
                color: widget.config.colorPrimario,
              ),
            ),
            hint: const Text("Ej: Patin, Futbol, Zumba..."),
            items: _actividadesDisponibles.map((a) {
              return DropdownMenuItem(
                value: a,
                child: Text(
                  a,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _actSeleccionada = val;
              });
            },
          ),
        ),

        const Divider(height: 1),

        if (_actSeleccionada == null)
          const Expanded(
            child: Center(
              child: Text(
                "Seleccioná una actividad arriba\npara calcular lo que le corresponde al profe.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('movimientos')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Map<String, dynamic>> movimientosFiltrados = [];
                double totalLiquidacionActividad = 0;
                int totalCuotasCobradas = 0;

                double precioActualActividad =
                    _preciosCache[_actSeleccionada!] ?? 0;

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['fecha'] == null) continue;
                  DateTime fechaDoc = (data['fecha'] as Timestamp).toDate();
                  if (fechaDoc.isBefore(widget.fechaInicio) ||
                      fechaDoc.isAfter(widget.fechaFin)) {
                    continue;
                  }

                  if (data['tipo'] == 'ingreso') {
                    String concepto = (data['concepto'] ?? '').toString();
                    int ocurrencias = 0;

                    if (data['origen'] == 'manual') {
                      bool tieneLinkManual =
                          data['actividad_manual'] != null ||
                          data['actividad_manual_2'] != null;

                      if (tieneLinkManual) {
                        if (data['actividad_manual'] == _actSeleccionada) {
                          int m1 = data['meses_manual'] is num
                              ? (data['meses_manual'] as num).toInt()
                              : 1;
                          ocurrencias += m1;
                        }
                        if (data['actividad_manual_2'] == _actSeleccionada) {
                          int m2 = data['meses_manual_2'] is num
                              ? (data['meses_manual_2'] as num).toInt()
                              : 1;
                          ocurrencias += m2;
                        }
                      } else {
                        // --- LÓGICA DE COINCIDENCIA MÁS LARGA PARA INGRESOS MANUALES VIEJOS ---
                        String actividadDetectada = "";
                        for (String act in _actividadesDisponibles) {
                          if (concepto.contains(act) &&
                              act.length > actividadDetectada.length) {
                            actividadDetectada = act;
                          }
                        }
                        if (actividadDetectada == _actSeleccionada) {
                          ocurrencias =
                              concepto.split(actividadDetectada).length - 1;
                        }
                      }
                    } else {
                      // --- LÓGICA DE COINCIDENCIA MÁS LARGA PARA INGRESOS AUTOMÁTICOS ---
                      String actividadDetectada = "";
                      for (String act in _actividadesDisponibles) {
                        if (concepto.contains(act) &&
                            act.length > actividadDetectada.length) {
                          actividadDetectada = act;
                        }
                      }

                      if (actividadDetectada == _actSeleccionada) {
                        ocurrencias =
                            concepto.split(actividadDetectada).length - 1;

                        RegExp regExpMeses = RegExp(r'adelantado de (\d+) mes');
                        var matchMeses = regExpMeses.firstMatch(concepto);
                        if (matchMeses != null) {
                          int mesesExtraidos =
                              int.tryParse(matchMeses.group(1) ?? '1') ?? 1;
                          if (mesesExtraidos > 0) {
                            ocurrencias = mesesExtraidos;
                          }
                        }
                      }
                    }

                    if (ocurrencias > 0) {
                      double porcionActividad =
                          ocurrencias * precioActualActividad;
                      double montoTotalTicket = (data['monto'] ?? 0).toDouble();

                      double porcentajeDescuento = 0;
                      if (concepto.contains('% OFF')) {
                        RegExp regExp = RegExp(r'\((\d+)%\s*OFF\)');
                        var match = regExp.firstMatch(concepto);
                        if (match != null) {
                          porcentajeDescuento =
                              double.tryParse(match.group(1) ?? '0') ?? 0;
                        }
                      }

                      if (montoTotalTicket == 0 || porcentajeDescuento >= 100) {
                        porcionActividad = 0;
                      } else if (porcentajeDescuento > 0) {
                        porcionActividad =
                            porcionActividad -
                            (porcionActividad * (porcentajeDescuento / 100));
                      } else if (porcionActividad > montoTotalTicket) {
                        porcionActividad = montoTotalTicket;
                      }

                      totalLiquidacionActividad += porcionActividad;
                      totalCuotasCobradas += ocurrencias;

                      movimientosFiltrados.add({
                        'docId': doc.id,
                        'fecha': fechaDoc,
                        'socio': data['socio_nombre'] ?? 'Desconocido',
                        'concepto': concepto,
                        'monto_total_ticket': montoTotalTicket,
                        'ocurrencias': ocurrencias,
                        'porcion_actividad': porcionActividad,
                        'es_becado': porcionActividad == 0,
                      });
                    }
                  }
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      color: widget.config.colorPrimario.withOpacity(0.1),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "A Rendir por: $_actSeleccionada",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "$totalCuotasCobradas cuotas en este periodo.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  "(Calculado a \$${precioActualActividad.toStringAsFixed(0)} c/u descontando becas)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (movimientosFiltrados.isNotEmpty)
                            IconButton(
                              onPressed: () => _exportarExcelLiquidacion(
                                context,
                                movimientosFiltrados,
                                totalLiquidacionActividad,
                                totalCuotasCobradas,
                              ),
                              icon: const Icon(
                                Icons.file_download,
                                color: Colors.green,
                              ),
                              tooltip: "Exportar Liquidación",
                            ),
                          const SizedBox(width: 10),
                          Text(
                            "\$${totalLiquidacionActividad.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: widget.config.colorPrimario,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    Expanded(
                      child: movimientosFiltrados.isEmpty
                          ? const Center(
                              child: Text(
                                "No se encontraron cobros para esta actividad en estas fechas.",
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: movimientosFiltrados.length,
                              separatorBuilder: (c, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = movimientosFiltrados[index];
                                final bool esBecado = item['es_becado'];

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: esBecado
                                        ? Colors.grey[200]
                                        : Colors.blue[50],
                                    child: Icon(
                                      esBecado
                                          ? Icons.money_off
                                          : Icons.receipt_long,
                                      color: esBecado
                                          ? Colors.grey
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item['concepto'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: esBecado
                                          ? Colors.grey[600]
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${DateFormat('dd/MM HH:mm').format(item['fecha'])} • Socio: ${item['socio']}\nTicket Entero: \$${item['monto_total_ticket'].toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        esBecado ? "Becado" : "Rinde",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        "+\$${item['porcion_actividad'].toStringAsFixed(0)}",
                                        style: TextStyle(
                                          color: esBecado
                                              ? Colors.grey
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

// =========================================================================
// TAB 3: NUEVO REGISTRO (MANUAL)
// =========================================================================
class _TabNuevoMovimiento extends StatefulWidget {
  final ConfiguracionApp config;
  final VoidCallback alGuardar;
  final List<String> categoriasIniciales;
  final ValueChanged<List<String>> alCategoriasActualizadas;

  const _TabNuevoMovimiento({
    required this.config,
    required this.alGuardar,
    required this.categoriasIniciales,
    required this.alCategoriasActualizadas,
  });

  @override
  State<_TabNuevoMovimiento> createState() => _TabNuevoMovimientoState();
}

class _TabNuevoMovimientoState extends State<_TabNuevoMovimiento> {
  String _tipo = 'ingreso';
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  String _metodo = 'Efectivo';
  String _categoria = 'Cuotas';
  bool _guardando = false;
  List<String> _categorias = List<String>.from(_categoriasFinanzasBase);

  DateTime _fechaMovimiento = DateTime.now();

  String? _socioVinculadoId;
  String? _socioVinculadoNombre;

  List<String> _actividadesDisponibles = [];

  String? _actividadManual;
  int _cuotasManual = 1;

  String? _actividadManual2;
  int _cuotasManual2 = 1;

  @override
  void initState() {
    super.initState();
    _categorias = _combinarCategorias(widget.categoriasIniciales);
    _cargarActividades();
    _cargarCategorias();
  }

  @override
  void didUpdateWidget(covariant _TabNuevoMovimiento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoriasIniciales != widget.categoriasIniciales) {
      final nuevas = _combinarCategorias(widget.categoriasIniciales);
      if (!_listasIguales(_categorias, nuevas)) {
        setState(() => _categorias = nuevas);
      }
    }
  }

  List<String> _combinarCategorias(List<String> adicionales) {
    final resultado = List<String>.from(_categoriasFinanzasBase);
    for (final item in adicionales) {
      final limpio = item.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (limpio.isEmpty) continue;
      final existe = resultado.any(
        (c) => c.toLowerCase() == limpio.toLowerCase(),
      );
      if (!existe) resultado.add(limpio);
    }
    return resultado;
  }

  bool _listasIguales(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _cargarCategorias() async {
    final categorias = await _RepositorioCategoriasFinanzas.cargar();
    if (!mounted) return;

    setState(() {
      _categorias = categorias;
      if (!_categorias.contains(_categoria)) {
        _categoria = _categorias.isNotEmpty ? _categorias.first : 'Cuotas';
      }
    });
    widget.alCategoriasActualizadas(List<String>.from(categorias));
  }

  Future<void> _agregarNuevaCategoria() async {
    final controller = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Buffet, Eventos, Transporte...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (valor) {
            final limpio = valor.trim();
            if (limpio.isNotEmpty) Navigator.pop(ctx, limpio);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.config.colorPrimario,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final limpio = controller.text.trim();
              if (limpio.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Escribí un nombre para la categoría.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, limpio);
            },
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (nombre == null || nombre.trim().isEmpty || !mounted) return;

    final nombreLimpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    final existente = _categorias.where(
      (c) => c.toLowerCase() == nombreLimpio.toLowerCase(),
    );

    if (existente.isNotEmpty) {
      setState(() => _categoria = existente.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La categoría "${existente.first}" ya existe.')),
      );
      return;
    }

    try {
      final categorias = await _RepositorioCategoriasFinanzas.agregar(nombreLimpio);
      if (!mounted) return;

      final creada = categorias.firstWhere(
        (c) => c.toLowerCase() == nombreLimpio.toLowerCase(),
        orElse: () => nombreLimpio,
      );

      setState(() {
        _categorias = categorias;
        _categoria = creada;
      });
      widget.alCategoriasActualizadas(List<String>.from(categorias));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría "$creada" agregada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo agregar la categoría: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cargarActividades() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        Map<String, dynamic> mapaPrecios = data['precios_cuotas'] ?? data;
        List<String> acts = [];
        mapaPrecios.forEach((key, value) {
          if (!key.contains('_') && key != 'fecha_actualizacion') {
            acts.add(key);
          }
        });
        acts.sort();
        if (mounted) setState(() => _actividadesDisponibles = acts);
      }
    } catch (e) {
      print("Error cargando actividades: $e");
    }
  }

  Future<void> _seleccionarFechaMovimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaMovimiento,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: widget.config.colorPrimario,
            colorScheme: ColorScheme.light(
              primary: widget.config.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaMovimiento = DateTime(
          picked.year,
          picked.month,
          picked.day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
      });
    }
  }

  Future<void> _seleccionarSocio() async {
    String filtroBusqueda = "";

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Vincular Socio"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Buscar por Apellido o DNI...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          filtroBusqueda = val.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('socios')
                            .orderBy('apellido')
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var socios = snap.data!.docs;

                          if (filtroBusqueda.isNotEmpty) {
                            socios = socios.where((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final busquedaStr =
                                  "${d['nombre']} ${d['apellido']} ${d['dni']} ${d['busqueda']}"
                                      .toLowerCase();
                              return busquedaStr.contains(filtroBusqueda);
                            }).toList();
                          } else {
                            if (socios.length > 50) {
                              socios = socios.take(50).toList();
                            }
                          }

                          if (socios.isEmpty) {
                            return const Center(
                              child: Text("No se encontraron coincidencias."),
                            );
                          }

                          return ListView.separated(
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemCount: socios.length,
                            itemBuilder: (ctx, i) {
                              final d =
                                  socios[i].data() as Map<String, dynamic>;
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text("${d['apellido']}, ${d['nombre']}"),
                                subtitle: Text(
                                  "DNI: ${d['dni']} - Act: ${d['actividad'] ?? ''}",
                                ),
                                onTap: () {
                                  setState(() {
                                    _socioVinculadoId = socios[i].id;
                                    _socioVinculadoNombre =
                                        "${d['apellido']} ${d['nombre']}";
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
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
                  child: const Text("Cancelar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pedirClaveParaGasto() async {
    final TextEditingController _claveCtrl = TextEditingController();
    bool verificandoBD = false;

    bool autorizado =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red),
                    SizedBox(width: 10),
                    Text("Autorización Requerida"),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Para registrar una salida de dinero (Egreso), debes ingresar la clave administrativa.",
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _claveCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Contraseña",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: verificandoBD
                        ? null
                        : () => Navigator.pop(ctx, false),
                    child: const Text(
                      "CANCELAR",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: verificandoBD
                        ? null
                        : () async {
                            setStateDialog(() => verificandoBD = true);
                            try {
                              final docRef = FirebaseFirestore.instance
                                  .collection('configuracion')
                                  .doc('seguridad');
                              final doc = await docRef.get();

                              String claveReal = "admin123";

                              if (doc.exists &&
                                  doc.data()!.containsKey('clave_egresos')) {
                                claveReal = doc.data()!['clave_egresos'];
                              } else {
                                await docRef.set({
                                  'clave_egresos': 'admin123',
                                }, SetOptions(merge: true));
                              }

                              if (_claveCtrl.text == claveReal) {
                                Navigator.pop(ctx, true);
                              } else {
                                setStateDialog(() => verificandoBD = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text("❌ Contraseña incorrecta"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setStateDialog(() => verificandoBD = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text("Error al verificar clave"),
                                ),
                              );
                            }
                          },
                    child: verificandoBD
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("CONFIRMAR"),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (autorizado) {
      _guardar();
    }
  }

  Future<void> _verificarYGuardar() async {
    if (_montoCtrl.text.isEmpty || _conceptoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa Monto y Concepto")),
      );
      return;
    }

    if (_tipo == 'egreso') {
      await _pedirClaveParaGasto();
    } else {
      await _guardar();
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    double montoPdf = double.parse(_montoCtrl.text);
    String conceptoPdf = _conceptoCtrl.text;
    String metodoPdf = _metodo;
    String categoriaPdf = _categoria;
    String tipoPdf = _tipo;
    DateTime fechaPdf = _fechaMovimiento;
    String? socioPdf = _socioVinculadoNombre;

    try {
      await FirebaseFirestore.instance.collection('movimientos').add({
        'tipo': _tipo,
        'monto': double.parse(_montoCtrl.text),
        'concepto': _conceptoCtrl.text,
        'metodo': _metodo,
        'categoria': _categoria,
        'fecha': Timestamp.fromDate(_fechaMovimiento),
        'socio_id': _socioVinculadoId,
        'socio_nombre': _socioVinculadoNombre,
        'origen': 'manual',
        'actividad_manual': (_tipo == 'ingreso') ? _actividadManual : null,
        'meses_manual': (_tipo == 'ingreso' && _actividadManual != null)
            ? _cuotasManual
            : null,
        'actividad_manual_2': (_tipo == 'ingreso') ? _actividadManual2 : null,
        'meses_manual_2': (_tipo == 'ingreso' && _actividadManual2 != null)
            ? _cuotasManual2
            : null,
      });

      _montoCtrl.clear();
      _conceptoCtrl.clear();
      _socioVinculadoId = null;
      _socioVinculadoNombre = null;
      _actividadManual = null;
      _actividadManual2 = null;
      _cuotasManual = 1;
      _cuotasManual2 = 1;
      _categoria = 'Cuotas';
      _fechaMovimiento = DateTime.now();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("¡Registro Exitoso!"),
            content: const Text(
              "El movimiento se guardó correctamente en la caja del club.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.alGuardar();
                },
                child: const Text("CERRAR"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("DESCARGAR COMPROBANTE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await generarComprobantePDF(
                    context,
                    widget.config,
                    tipoPdf,
                    montoPdf,
                    conceptoPdf,
                    metodoPdf,
                    categoriaPdf,
                    fechaPdf,
                    socioPdf,
                  );
                  widget.alGuardar();
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BotonTipo(
                  "INGRESO",
                  Colors.green,
                  _tipo == 'ingreso',
                  () => setState(() => _tipo = 'ingreso'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _BotonTipo(
                  "GASTO (Egreso)",
                  Colors.red,
                  _tipo == 'egreso',
                  () => setState(() => _tipo = 'egreso'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 0,
            ),
            title: Text(
              "Fecha: ${DateFormat('dd/MM/yyyy').format(_fechaMovimiento)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              "Toca para imputar a otro mes",
              style: TextStyle(fontSize: 11),
            ),
            leading: Icon(
              Icons.calendar_today,
              color: widget.config.colorPrimario,
            ),
            trailing: const Icon(Icons.edit, size: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            onTap: _seleccionarFechaMovimiento,
          ),
          const SizedBox(height: 15),

          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Monto Total",
              prefixText: "\$ ",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _conceptoCtrl,
            decoration: const InputDecoration(
              labelText: "Concepto / Descripción",
              hintText: "Ej: Pago Luz, Compra Pelotas, Deuda...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _metodo,
                  decoration: const InputDecoration(
                    labelText: "Método",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items:
                      ['Efectivo', 'Mercado Pago', 'Transferencia', 'Tarjeta']
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _metodo = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _categoria,
                  decoration: const InputDecoration(
                    labelText: "Categoría",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: [
                    ..._categorias.map(
                      (m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: _opcionAgregarCategoria,
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Agregar nueva categoría...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    if (v == _opcionAgregarCategoria) {
                      await _agregarNuevaCategoria();
                      return;
                    }
                    setState(() => _categoria = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 0,
            ),
            title: Text(
              _socioVinculadoNombre == null
                  ? "Vincular a un Socio (Opcional)"
                  : "Vinculado a: $_socioVinculadoNombre",
              style: TextStyle(
                fontWeight: _socioVinculadoNombre != null
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            subtitle: _socioVinculadoNombre == null
                ? const Text("Para imputar gastos o cobros extra")
                : null,
            leading: Icon(Icons.person_pin, color: widget.config.colorPrimario),
            trailing: _socioVinculadoNombre == null
                ? const Icon(Icons.arrow_forward_ios, size: 14)
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _socioVinculadoId = null;
                      _socioVinculadoNombre = null;
                      _actividadManual = null;
                      _actividadManual2 = null;
                      _cuotasManual = 1;
                      _cuotasManual2 = 1;
                    }),
                  ),
            onTap: _seleccionarSocio,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),

          if (_tipo == 'ingreso' && _socioVinculadoId != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Opciones de Liquidación (Para separar el dinero)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _actividadManual,
                    decoration: const InputDecoration(
                      labelText: "Actividad Principal",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("Ninguna (Ingreso general)"),
                      ),
                      ..._actividadesDisponibles.map(
                        (a) => DropdownMenuItem(value: a, child: Text(a)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _actividadManual = v),
                  ),
                  if (_actividadManual != null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _cuotasManual.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Cantidad de meses",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.calendar_month, size: 20),
                      ),
                      onChanged: (v) => _cuotasManual = int.tryParse(v) ?? 1,
                    ),

                    const Divider(height: 30, color: Colors.blue),

                    DropdownButtonFormField<String>(
                      value: _actividadManual2,
                      decoration: const InputDecoration(
                        labelText: "Segunda Actividad (Opcional)",
                        hintText: "Ej: Cuota Social",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Ninguna"),
                        ),
                        ..._actividadesDisponibles.map(
                          (a) => DropdownMenuItem(value: a, child: Text(a)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _actividadManual2 = v),
                    ),
                    if (_actividadManual2 != null) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: _cuotasManual2.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Cantidad de meses",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.calendar_month, size: 20),
                        ),
                        onChanged: (v) => _cuotasManual2 = int.tryParse(v) ?? 1,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _guardando ? null : _verificarYGuardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tipo == 'ingreso' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "GUARDAR ${_tipo.toUpperCase()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  final String texto;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;
  const _BotonTipo(this.texto, this.color, this.seleccionado, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: seleccionado ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            color: seleccionado ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

Future<void> generarComprobantePDF(
  BuildContext context,
  ConfiguracionApp config,
  String tipo,
  double monto,
  String concepto,
  String metodo,
  String categoria,
  DateTime fecha,
  String? socioNombre,
) async {
  try {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(fecha);

    String tipoTexto = tipo == 'ingreso'
        ? 'RECIBO DE INGRESO'
        : 'COMPROBANTE DE EGRESO';
    PdfColor colorPrincipal = tipo == 'ingreso'
        ? PdfColors.green800
        : PdfColors.red800;

    pw.ImageProvider? logoProvider;
    try {
      final ByteData bytes = await rootBundle.load(config.rutaLogo);
      logoProvider = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      print("Error cargando logo para PDF: $e");
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoProvider != null)
                  pw.Center(
                    child: pw.Container(
                      height: 50,
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Image(logoProvider),
                    ),
                  ),
                pw.Center(
                  child: pw.Text(
                    config.nombreApp.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    tipoTexto,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: colorPrincipal,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  "DETALLES DEL MOVIMIENTO",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text("Fecha de registro: $fechaActual"),
                pw.Text("Categoría: $categoria"),
                pw.Text("Método de pago: $metodo"),
                if (socioNombre != null && socioNombre.isNotEmpty)
                  pw.Text("Socio Vinculado: $socioNombre"),
                pw.SizedBox(height: 15),
                pw.Text(
                  "Concepto:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(concepto),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TOTAL:",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "\$${monto.toStringAsFixed(0)}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: colorPrincipal,
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(
                  child: pw.Text(
                    "Documento generado administrativamente.\n${config.nombreApp}",
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    String nombreArchivo =
        "Comprobante_${tipo}_${fecha.millisecondsSinceEpoch}.pdf";

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: nombreArchivo,
        bytes: bytes,
        mimeType: MimeType.pdf,
      );
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      String? rutaSalida = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Comprobante',
        fileName: nombreArchivo,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (rutaSalida != null) {
        File(rutaSalida)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Comprobante guardado exitosamente.")),
          );
        }
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$nombreArchivo";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      await Share.shareXFiles([
        XFile(path),
      ], text: "Comprobante de $tipo - ${config.nombreApp}");
    }
  } catch (e) {
    print("Error generando PDF: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generando PDF: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
