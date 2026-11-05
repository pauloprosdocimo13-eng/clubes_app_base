import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'fecha_caja.dart';

/// Exporta únicamente los movimientos filtrados por la pantalla.
class ExportacionCaja {
  static String _texto(dynamic valor, {dynamic alternativa}) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isNotEmpty) return texto;
    final respaldo = alternativa?.toString().trim() ?? '';
    return respaldo.isEmpty ? 'Sin registrar' : respaldo;
  }

  static String _fecha(dynamic valor) => valor is Timestamp
      ? DateFormat('dd/MM/yyyy HH:mm').format(FechaCaja.ahoraArgentina(valor.toDate()))
      : 'Sin registrar';

  static Excel crear(Iterable<Map<String, dynamic>> movimientos) {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Caja'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue("Fecha del movimiento (Argentina)"),
        TextCellValue("Socio / Nombre"),
        TextCellValue("Concepto / Actividad"),
        TextCellValue("Categoría"),
        TextCellValue("Ingreso (+)"),
        TextCellValue("Egreso (-)"),
        TextCellValue("Medio de pago"),
        TextCellValue("Registrado por"),
        TextCellValue("Fecha real de carga (Argentina)"),
      ]);

      double totalIngresos = 0;
      double totalEgresos = 0;

      for (final data in movimientos) {

        final fechaStr = _fecha(data['fecha']);
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
          TextCellValue(_texto(data['metodo'])),
          TextCellValue(_texto(data['admin_email'], alternativa: data['admin_uid'])),
          TextCellValue(_fecha(data['fecha_registro'])),
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


    return excel;
  }
}
