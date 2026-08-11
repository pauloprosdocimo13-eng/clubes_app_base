import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_familia.dart';
import 'pantalla_admin_precios.dart';

class PantallaAdminSocios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminSocios({super.key, required this.config});

  @override
  State<PantallaAdminSocios> createState() => _PantallaAdminSociosState();
}

class _PantallaAdminSociosState extends State<PantallaAdminSocios> {
  String _busqueda = "";
  bool _procesando = false;

  // Variables para los nuevos filtros
  String _filtroEstado = 'Todos'; // 'Todos', 'Al Día', 'Con Deuda'
  String _filtroActividad = 'Todas';

  Map<String, double> _preciosCache = {};

  @override
  void initState() {
    super.initState();
    _cargarPreciosEnMemoria();
  }

  Future<void> _cargarPreciosEnMemoria() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final map = data['precios_cuotas'] ?? {};
        map.forEach((k, v) {
          if (v is num) _preciosCache[k] = v.toDouble();
        });
        if (mounted) setState(() {});
      }
    } catch (e) {
      print("Error cargando precios: $e");
    }
  }

  // --- HELPER CENTRALIZADO PARA OBTENER ACTIVIDADES ---
  List<String> _obtenerActividadesSocio(Map<String, dynamic> data) {
    Set<String> setActividades = {};
    if (data['actividades'] != null && data['actividades'] is List) {
      for (var a in data['actividades']) {
        setActividades.addAll(
          a.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
        );
      }
    } else if (data['actividad'] != null) {
      setActividades.addAll(
        (data['actividad'] ?? '')
            .toString()
            .split(RegExp(r'[,+]'))
            .map((e) => e.trim()),
      );
    }
    setActividades.removeWhere((e) => e.isEmpty || e == 'Ninguna');
    if (setActividades.isEmpty) {
      return ['Cuota Social'];
    }
    return setActividades.toList();
  }

  void _irAFormularioFamilia({String? familiaId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaAdminFormularioFamilia(
          config: widget.config,
          familiaIdEditar: familiaId,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _irAConfigurarPrecios() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaAdminPrecios(config: widget.config),
      ),
    ).then((_) => _cargarPreciosEnMemoria());
  }

  Future<void> _toggleAptoFisico(String docId, bool valorActual) async {
    try {
      await FirebaseFirestore.instance.collection('socios').doc(docId).update({
        'apto_fisico': !valorActual,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !valorActual
                  ? "✅ Apto físico registrado"
                  : "❌ Apto físico marcado como pendiente",
            ),
            backgroundColor: !valorActual ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editarNotaInterna(String docId, String notaActual) {
    final TextEditingController _notaCtrl = TextEditingController(
      text: notaActual,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Nota Interna del Socio",
          style: TextStyle(fontSize: 16),
        ),
        content: TextField(
          controller: _notaCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Ej: Pagó cuota anual, Solo viene martes, etc.",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.config.colorPrimario,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('socios')
                    .doc(docId)
                    .update({'notas_internas': _notaCtrl.text.trim()});
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Nota guardada"),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al guardar: $e")),
                  );
                }
              }
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarAExcel() async {
    setState(() => _procesando = true);
    try {
      final query = await FirebaseFirestore.instance.collection('socios').get();
      if (query.docs.isEmpty) throw "No hay socios para exportar.";

      var excel = Excel.createExcel();
      String sheetName = "PadronSocios";
      Sheet sheet = excel[sheetName];
      excel.delete('Sheet1');

      List<String> headers = [
        "Apellido",
        "Nombre",
        "DNI",
        "Email",
        "Telefono",
        "Actividad",
        "DNI Titular",
        "Ultimo Pago",
        "Descuento %",
        "Apto Fisico",
        "Notas Internas",
      ];
      sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

      for (var doc in query.docs) {
        var data = doc.data();
        String dni = data['dni'] ?? '';
        String familiaId = data['familia_id'] ?? '';
        bool esTitular = data['es_titular'] == true;
        String dniTitularCell = (!esTitular && familiaId != dni)
            ? familiaId
            : "";

        String descuento = (data['porcentaje_descuento'] ?? 0).toString();
        String aptoFisicoStr = data['apto_fisico'] == true ? "SI" : "NO";
        String notas = data['notas_internas'] ?? '';

        List<CellValue> row = [
          TextCellValue(data['apellido'] ?? ''),
          TextCellValue(data['nombre'] ?? ''),
          TextCellValue(dni),
          TextCellValue(data['email'] ?? ''),
          TextCellValue(data['telefono'] ?? ''),
          TextCellValue(data['actividad'] ?? ''),
          TextCellValue(dniTitularCell),
          TextCellValue(data['ultimo_mes_pago'] ?? ''),
          TextCellValue(descuento),
          TextCellValue(aptoFisicoStr),
          TextCellValue(notas),
        ];
        sheet.appendRow(row);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        String nombreArchivo = 'padron_socios_${DateTime.now().year}.xlsx';

        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: nombreArchivo,
            bytes: Uint8List.fromList(fileBytes),
            mimeType: MimeType.microsoftExcel,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Excel descargado exitosamente"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          String? rutaSalida = await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar Excel de Padrón',
            fileName: nombreArchivo,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (rutaSalida != null) {
            File(rutaSalida)
              ..createSync(recursive: true)
              ..writeAsBytesSync(fileBytes);
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
            ..writeAsBytesSync(fileBytes);

          await Share.shareXFiles([XFile(path)], text: "Padrón de Socios");
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _importarDesdeExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null) return;

      setState(() => _procesando = true);

      var bytes = result.files.single.bytes;
      if (bytes == null && result.files.single.path != null) {
        bytes = File(result.files.single.path!).readAsBytesSync();
      }
      if (bytes == null) throw "No se pudo leer el archivo.";

      var excel = Excel.decodeBytes(bytes);
      var table = excel.tables[excel.tables.keys.first];
      if (table == null) throw "El Excel está vacío.";

      int importados = 0;
      final db = FirebaseFirestore.instance;
      final batchSize = 400;
      WriteBatch batch = db.batch();
      int contadorBatch = 0;

      String getVal(List<dynamic> row, int index) {
        if (index >= row.length) return '';
        var cell = row[index];
        var value = cell?.value;

        if (value == null) return '';
        if (value is double) return value.toInt().toString();
        if (value is int) return value.toString();
        return value.toString().trim();
      }

      for (var i = 1; i < table.rows.length; i++) {
        var row = table.rows[i];

        String apellido = getVal(row, 0);
        String nombre = getVal(row, 1);
        String dni = getVal(row, 2);
        String email = getVal(row, 3);
        String telefono = getVal(row, 4);
        String actividad = getVal(row, 5);
        String dniTitular = getVal(row, 6);
        String ultimoPago = getVal(row, 7);
        String descuentoStr = getVal(row, 8);

        String aptoFisicoStr = getVal(row, 9).toUpperCase();
        String notasInternasStr = getVal(row, 10);

        if (dni.isEmpty) continue;

        bool esTitular = true;
        String familiaId = dni;
        if (dniTitular.isNotEmpty) {
          esTitular = false;
          familiaId = dniTitular;
        }

        bool estaAlDia = false;
        if (ultimoPago.isNotEmpty && ultimoPago.contains('-')) {
          try {
            DateTime fechaPago = DateTime.parse("$ultimoPago-01");
            DateTime ahora = DateTime.now();
            int diff =
                (ahora.year * 12 + ahora.month) -
                (fechaPago.year * 12 + fechaPago.month);
            if (diff <= 0) estaAlDia = true;
          } catch (_) {}
        }

        int descuento = int.tryParse(descuentoStr) ?? 0;

        DocumentReference ref = db.collection('socios').doc(dni);

        DocumentSnapshot docSocio = await ref.get();
        String dbUltimoPago = '';
        if (docSocio.exists) {
          final d = docSocio.data() as Map<String, dynamic>;
          dbUltimoPago = d['ultimo_mes_pago'] ?? '';
        }

        Map<String, dynamic> datosUsuario = {
          'nombre': nombre,
          'apellido': apellido,
          'dni': dni,
          'email': email,
          'telefono': telefono,
          'actividad': actividad.isEmpty ? 'Cuota Social' : actividad,
          'es_titular': esTitular,
          'familia_id': familiaId,
          'porcentaje_descuento': descuento,
          'busqueda': "$nombre $apellido $dni".toLowerCase(),
        };

        if (aptoFisicoStr == 'SI' || aptoFisicoStr == 'TRUE') {
          datosUsuario['apto_fisico'] = true;
        } else if (aptoFisicoStr == 'NO' || aptoFisicoStr == 'FALSE') {
          datosUsuario['apto_fisico'] = false;
        }

        if (row.length > 10) {
          datosUsuario['notas_internas'] = notasInternasStr;
        }

        if (!docSocio.exists) {
          if (!datosUsuario.containsKey('apto_fisico')) {
            datosUsuario['apto_fisico'] = false;
          }
          datosUsuario['fecha_alta'] = FieldValue.serverTimestamp();
          datosUsuario['rol'] = 'socio';
          datosUsuario['nro_socio'] = dni;
          datosUsuario['actividades'] = [
            actividad.isEmpty ? 'Cuota Social' : actividad,
          ];
          datosUsuario['al_dia'] = false;
        }

        if (ultimoPago.isNotEmpty) {
          if (dbUltimoPago.isEmpty || ultimoPago.compareTo(dbUltimoPago) > 0) {
            datosUsuario['ultimo_mes_pago'] = ultimoPago;
            datosUsuario['al_dia'] = estaAlDia;
          }
        }

        batch.set(ref, datosUsuario, SetOptions(merge: true));
        importados++;
        contadorBatch++;

        if (contadorBatch >= batchSize) {
          await batch.commit();
          batch = db.batch();
          contadorBatch = 0;
        }
      }
      if (contadorBatch > 0) await batch.commit();

      setState(() => _procesando = false);
      _mostrarResultadoImportacion(importados);
    } catch (e) {
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarResultadoImportacion(int imp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Operación Finalizada"),
        content: Text("Se procesaron $imp registros correctamente."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _borrarSocio(String docId, Map<String, dynamic> data) async {
    bool esTitular = data['es_titular'] == true;
    String familiaId = esTitular ? docId : (data['familia_id'] ?? docId);

    bool confirmar =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Eliminar Socio?"),
            content: Text(
              esTitular
                  ? "ATENCIÓN: Es TITULAR. Se borrará a TODA su familia."
                  : "¿Seguro deseas eliminar a este integrante?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "ELIMINAR",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    try {
      final db = FirebaseFirestore.instance;
      if (esTitular) {
        var batch = db.batch();
        var queryFamilia = await db
            .collection('socios')
            .where('familia_id', isEqualTo: familiaId)
            .get();
        for (var doc in queryFamilia.docs) batch.delete(doc.reference);
        batch.delete(db.collection('socios').doc(docId));
        await batch.commit();
      } else {
        await db.collection('socios').doc(docId).delete();
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Eliminado.")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _generarYCompartirReciboPDF(
    Map<String, dynamic> socioData,
    double montoPagado,
    String mesAbonado,
    String detalleActividades,
  ) async {
    try {
      final pdf = pw.Document();
      final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      pw.ImageProvider? logoProvider;
      try {
        final ByteData bytes = await rootBundle.load(widget.config.rutaLogo);
        logoProvider = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        print("Error al cargar el logo para el PDF: $e");
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
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
                      widget.config.nombreApp.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      "RECIBO DE PAGO",
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "DATOS DEL SOCIO",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Nombre: ${socioData['apellido']}, ${socioData['nombre']}",
                  ),
                  pw.Text("DNI / Nro Socio: ${socioData['dni']}"),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    "DETALLE DEL PAGO",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text("Fecha de Pago: $fechaActual"),
                  pw.Text("Mes Abonado: $mesAbonado"),
                  pw.Text("Conceptos: \n$detalleActividades"),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "TOTAL ABONADO:",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "\$${montoPagado.toStringAsFixed(0)}",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Center(
                    child: pw.Text(
                      "Este documento es un comprobante válido de pago.\nGracias por colaborar con el club.",
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
      String nombreArchivo = "Recibo_${socioData['dni']}_$mesAbonado.pdf";

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: nombreArchivo,
          bytes: bytes,
          mimeType: MimeType.pdf,
        );
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        String? rutaSalida = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar Recibo de Pago',
          fileName: nombreArchivo,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (rutaSalida != null) {
          File(rutaSalida)
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Recibo guardado exitosamente.")),
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
        ], text: "Aquí tenés tu recibo de pago de ${widget.config.nombreApp}.");
      }
    } catch (e) {
      print("Error generando PDF: $e");
    }
  }

  void _mostrarDialogoCobro(String docId, Map<String, dynamic> data) {
    String ultimoMesPagoStr = data['ultimo_mes_pago'] ?? '';
    DateTime fechaBase;
    bool esPrimerPago = false;

    if (ultimoMesPagoStr.isEmpty) {
      esPrimerPago = true;
      if (data['fecha_alta'] != null && data['fecha_alta'] is Timestamp) {
        fechaBase = (data['fecha_alta'] as Timestamp).toDate();
      } else {
        fechaBase = DateTime.now();
      }
    } else {
      DateTime ultimo = DateTime.parse("$ultimoMesPagoStr-01");
      fechaBase = DateTime(ultimo.year, ultimo.month + 1, 1);
    }

    DateTime ahora = DateTime.now();
    DateTime mesActual = DateTime(ahora.year, ahora.month, 1);
    DateTime mesA_Pagar = DateTime(fechaBase.year, fechaBase.month, 1);
    bool esDeuda = mesA_Pagar.isBefore(mesActual);
    bool esAdelantado = mesA_Pagar.isAfter(mesActual);

    const meses = [
      "Ene", "Feb", "Mar", "Abr", "May", "Jun",
      "Jul", "Ago", "Sep", "Oct", "Nov", "Dic",
    ];
    String nombreMesBase = "${meses[fechaBase.month - 1]} ${fechaBase.year}";

    List<String> listaActividades = _obtenerActividadesSocio(data);

    Map<String, int> descPorActividad = {};
    Map<String, TextEditingController> preciosEditables = {};

    for (String act in listaActividades) {
      String actividadLimpia = act.trim();
      descPorActividad[actividadLimpia] = 0;

      double precioBase = 0;
      _preciosCache.forEach((key, value) {
        if (key.toLowerCase() == actividadLimpia.toLowerCase())
          precioBase = value;
      });

      preciosEditables[actividadLimpia] = TextEditingController(
        text: precioBase.toStringAsFixed(0),
      );
    }

    int cantidadMesesAPagar = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double montoTotalFinal = 0;
            descPorActividad.forEach((act, desc) {
              double precioIngresado =
                  double.tryParse(preciosEditables[act]?.text ?? '0') ?? 0;
              montoTotalFinal +=
                  (precioIngresado - (precioIngresado * desc / 100)) *
                  cantidadMesesAPagar;
            });

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.payments, color: Colors.green),
                  const SizedBox(width: 10),
                  const Text("Registrar Cobro"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${data['apellido']}, ${data['nombre']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(),
                    if (esPrimerPago)
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          "🔵 Primer cobro (desde alta)",
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.yellow[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow[700]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Meses a adelantar:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DropdownButton<int>(
                            value: cantidadMesesAPagar,
                            underline: const SizedBox(),
                            items: List.generate(12, (i) => i + 1).map((e) {
                              return DropdownMenuItem<int>(
                                value: e,
                                child: Text(
                                  "$e mes${e > 1 ? 'es' : ''}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateDialog(() {
                                cantidadMesesAPagar = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text(
                          "Inicia desde: ",
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          nombreMesBase,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.config.colorPrimario,
                          ),
                        ),
                      ],
                    ),
                    if (esDeuda)
                      const Text(
                        "⚠️ RECUPERANDO DEUDA",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (esAdelantado)
                      const Text(
                        "🟢 PAGO ADELANTADO",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 15),
                    const Text(
                      "Actividades (Precio x 1 Mes):",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),

                    ...listaActividades.map((actividadCruda) {
                      String act = actividadCruda.trim();
                      int descActual = descPorActividad[act] ?? 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                act,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 35,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: TextField(
                                  controller: preciosEditables[act],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    prefixText: "\$ ",
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 0,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: BorderSide(
                                        color: Colors.grey[400]!,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onChanged: (val) {
                                    setStateDialog(() {});
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 35,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: descActual,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                    ),
                                    items: [0, 10, 20, 30, 50, 100].map((d) {
                                      return DropdownMenuItem<int>(
                                        value: d,
                                        child: Text(
                                          d == 100
                                              ? "Beca"
                                              : (d == 0 ? "Sin Desc." : "$d%"),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: d == 100
                                                ? Colors.green
                                                : Colors.black,
                                            fontWeight: d == 100
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setStateDialog(() {
                                        descPorActividad[act] = val!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 10),
                    const Divider(thickness: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "TOTAL A COBRAR:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "\$${montoTotalFinal.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text("CONFIRMAR PAGO"),
                  onPressed: () {
                    if (montoTotalFinal >= 0) {
                      _procesarPago(
                        docId,
                        data,
                        fechaBase,
                        descPorActividad,
                        preciosEditables,
                        nombreMesBase,
                        cantidadMesesAPagar,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _procesarPago(
    String docId,
    Map<String, dynamic> socioData,
    DateTime mesBasePagado,
    Map<String, int> descuentosActividades,
    Map<String, TextEditingController> preciosEditables,
    String nombreMesFormateado,
    int cantidadMeses,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final userAdmin = FirebaseAuth.instance.currentUser;

      DateTime mesFinalCubierto = DateTime(
        mesBasePagado.year,
        mesBasePagado.month + (cantidadMeses - 1),
        1,
      );

      String nuevoUltimoMesStr =
          "${mesFinalCubierto.year}-${mesFinalCubierto.month.toString().padLeft(2, '0')}";

      WriteBatch batch = db.batch();

      batch.update(db.collection('socios').doc(docId), {
        'ultimo_mes_pago': nuevoUltimoMesStr,
        'al_dia': true,
        'porcentaje_descuento': 0,
        'fecha_ultimo_cobro_real': FieldValue.serverTimestamp(),
      });

      double montoTotalRecibo = 0;
      List<String> detallesParaElPDF = [];

      descuentosActividades.forEach((actividad, descuento) {
        double precioElegido =
            double.tryParse(preciosEditables[actividad]?.text ?? '0') ?? 0;

        double subtotalMensual =
            precioElegido - (precioElegido * descuento / 100);
        double subtotalTotal = subtotalMensual * cantidadMeses;

        montoTotalRecibo += subtotalTotal;

        String etiquetaDescuento = descuento > 0 ? " ($descuento% OFF)" : "";
        String etiquetaMeses = cantidadMeses > 1
            ? " (x$cantidadMeses meses)"
            : "";

        detallesParaElPDF.add(
          "• $actividad$etiquetaMeses$etiquetaDescuento: \$${subtotalTotal.toStringAsFixed(0)}",
        );

        batch.set(db.collection('movimientos').doc(), {
          'tipo': 'ingreso',
          'monto': subtotalTotal,
          'fecha': FieldValue.serverTimestamp(),
          'concepto':
              "Cobro adelantado de $cantidadMeses mes(es) - $actividad$etiquetaDescuento",
          'categoria': 'Cuotas',
          'socio_id': docId,
          'socio_nombre': "${socioData['apellido']} ${socioData['nombre']}",
          'admin_email': userAdmin?.email ?? 'Desconocido',
          'mes_correspondiente': nuevoUltimoMesStr,
        });
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("¡Pago registrado por $cantidadMeses mes(es)!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      String textoMesPdf = cantidadMeses == 1
          ? nombreMesFormateado
          : "$nombreMesFormateado (Adelanto de $cantidadMeses meses)";

      await _generarYCompartirReciboPDF(
        socioData,
        montoTotalRecibo,
        textoMesPdf,
        detallesParaElPDF.join("\n"),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Map<String, dynamic> _obtenerEstado(Map<String, dynamic> data) {
    String ultimoMes = data['ultimo_mes_pago'] ?? '';
    if (ultimoMes.isEmpty) return {'texto': 'SIN PAGO', 'color': Colors.grey};
    try {
      DateTime fechaPago = DateTime.parse("$ultimoMes-01");
      DateTime ahora = DateTime.now();
      int diff =
          (ahora.year * 12 + ahora.month) -
          (fechaPago.year * 12 + fechaPago.month);
      if (diff <= 0) return {'texto': 'AL DÍA', 'color': Colors.green};
      if (diff == 1 && ahora.day <= 10)
        return {'texto': 'VENCE EL 10', 'color': Colors.lightGreen};
      return {'texto': 'DEUDA ($diff meses)', 'color': Colors.red};
    } catch (e) {
      return {'texto': 'ERROR', 'color': Colors.grey};
    }
  }

  // --- NUEVA PANTALLA INFERIOR PARA FILTROS ---
  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            // Se arman las opciones de actividades leyendo los precios configurados
            List<String> opcionesActividades = ['Todas', ..._preciosCache.keys];
            opcionesActividades = opcionesActividades.toSet().toList(); // Evita repetidos
            
            if (!opcionesActividades.contains(_filtroActividad)) {
              _filtroActividad = 'Todas'; // Reset de seguridad
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Filtrar Padrón",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Estado de Pago",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ['Todos', 'Al Día', 'Con Deuda'].map((estado) {
                      return ChoiceChip(
                        label: Text(estado),
                        selected: _filtroEstado == estado,
                        selectedColor: widget.config.colorPrimario.withOpacity(0.3),
                        onSelected: (val) {
                          setStateSheet(() => _filtroEstado = estado);
                          setState(() {}); // Actualiza la pantalla principal atrás
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Actividad",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _filtroActividad,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: opcionesActividades.map((act) {
                      return DropdownMenuItem(value: act, child: Text(act));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateSheet(() => _filtroActividad = val);
                        setState(() {}); // Actualiza la pantalla principal atrás
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.config.colorPrimario,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("APLICAR FILTROS"),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hayFiltrosActivos = (_filtroEstado != 'Todos' || _filtroActividad != 'Todas');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Socios"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          if (_procesando)
            const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: "Exportar",
              onPressed: _exportarAExcel,
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: "Importar",
              onPressed: _importarDesdeExcel,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.price_change),
            tooltip: "Precios",
            onPressed: _irAConfigurarPrecios,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.config.colorPrimario,
        icon: const Icon(Icons.group_add),
        label: const Text("NUEVA FAMILIA"),
        onPressed: () => _irAFormularioFamilia(familiaId: null),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Buscar por Apellido, Nombre o DNI...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _busqueda = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                // Botón de Filtros
                Container(
                  decoration: BoxDecoration(
                    color: hayFiltrosActivos ? widget.config.colorPrimario : Colors.grey[200],
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_alt,
                      color: hayFiltrosActivos ? Colors.white : Colors.black87,
                    ),
                    tooltip: "Filtros",
                    onPressed: _mostrarFiltros,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('socios')
                  .orderBy('apellido')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;

                // --- LÓGICA DE FILTRADO ---
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;

                  // 1. Filtro por Búsqueda de Texto
                  if (_busqueda.isNotEmpty) {
                    String busquedaStr =
                        "${data['nombre']} ${data['apellido']} ${data['dni']} ${data['busqueda']}"
                            .toLowerCase();
                    if (!busquedaStr.contains(_busqueda)) return false;
                  }

                  // 2. Filtro por Estado de Pago
                  if (_filtroEstado != 'Todos') {
                    final estado = _obtenerEstado(data);
                    if (_filtroEstado == 'Al Día') {
                      if (estado['texto'] != 'AL DÍA' && estado['texto'] != 'VENCE EL 10') return false;
                    } else if (_filtroEstado == 'Con Deuda') {
                      if (!estado['texto'].toString().contains('DEUDA') && estado['texto'] != 'SIN PAGO') return false;
                    }
                  }

                  // 3. Filtro por Actividad
                  if (_filtroActividad != 'Todas') {
                    List<String> acts = _obtenerActividadesSocio(data);
                    bool tieneLaActividad = acts.any((a) => a.toLowerCase() == _filtroActividad.toLowerCase());
                    if (!tieneLaActividad) return false;
                  }

                  return true;
                }).toList();

                if (docs.isEmpty)
                  return const Center(child: Text("No se encontraron socios con esos filtros."));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final id = doc.id;
                    final estado = _obtenerEstado(data);
                    final esTitular = data['es_titular'] == true;
                    final familiaIdParaEditar = esTitular
                        ? id
                        : (data['familia_id'] ?? '');

                    int desc = (data['porcentaje_descuento'] ?? 0).toInt();
                    bool tieneAptoFisico = data['apto_fisico'] == true;
                    String notaInterna = data['notas_internas'] ?? '';

                    List<String> listaActs = _obtenerActividadesSocio(data);
                    String txtActividades = listaActs.join(', ');

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: esTitular
                            ? BorderSide(
                                color: widget.config.colorPrimario.withOpacity(
                                  0.5,
                                ),
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 5,
                              bottom: 0,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child:
                                  (data['foto_url'] != null &&
                                      data['foto_url'] != '')
                                  ? ClipOval(
                                      child: Image.network(
                                        data['foto_url'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            esTitular
                                                ? Icons.star
                                                : Icons.person,
                                            color: esTitular
                                                ? Colors.orange
                                                : Colors.grey,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      esTitular ? Icons.star : Icons.person,
                                      color: esTitular
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${data['apellido']}, ${data['nombre']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esTitular
                                          ? Colors.black
                                          : Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (desc > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: desc == 100
                                          ? Colors.green
                                          : Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      desc == 100 ? "BECADO" : "-$desc%",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "$txtActividades • DNI: ${data['dni']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (esTitular) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "TITULAR FAMILIA",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: widget.config.colorPrimario,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: estado['color'],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estado['texto'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: InkWell(
                              onTap: () => _editarNotaInterna(id, notaInterna),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.yellow[600]!,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.sticky_note_2,
                                      size: 16,
                                      color: Colors.orange[800],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        notaInterna.isEmpty
                                            ? "+ Agregar nota interna..."
                                            : notaInterna,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: notaInterna.isEmpty
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                          color: notaInterna.isEmpty
                                              ? Colors.grey[600]
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const Divider(height: 1, color: Colors.black12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    tieneAptoFisico
                                        ? Icons.health_and_safety
                                        : Icons.health_and_safety_outlined,
                                    size: 18,
                                    color: tieneAptoFisico
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                  label: Text(
                                    "Apto",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tieneAptoFisico
                                          ? Colors.blue
                                          : Colors.grey,
                                      fontWeight: tieneAptoFisico
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _toggleAptoFisico(id, tieneAptoFisico),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.payments, size: 22),
                                  color: Colors.green,
                                  tooltip: "Cobrar",
                                  onPressed: () =>
                                      _mostrarDialogoCobro(id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 22),
                                  color: Colors.blue,
                                  tooltip: "Editar",
                                  onPressed: () => _irAFormularioFamilia(
                                    familiaId: familiaIdParaEditar,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 22),
                                  color: Colors.red,
                                  tooltip: "Eliminar",
                                  onPressed: () => _borrarSocio(id, data),
                                ),
                              ],
                            ),
                          ),
                        ],
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
  }
}