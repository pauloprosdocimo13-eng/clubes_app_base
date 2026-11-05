import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/servicios/exportacion_caja.dart';

void main() {
  test('Excel conserva importes y totales e incluye medio, operador y fechas', () {
    final libro = ExportacionCaja.crear([
      {'tipo':'ingreso', 'monto':100.0, 'metodo':'Transferencia',
       'admin_email':'caja@example.com',
       'fecha':Timestamp.fromDate(DateTime.utc(2026,11,3,15)),
       'fecha_registro':Timestamp.fromDate(DateTime.utc(2026,11,4,16))},
      {'tipo':'egreso', 'monto':20.0, 'metodo':'Efectivo'},
      {'tipo':'ingreso', 'monto':0.0, 'metodo':'Sin movimiento de dinero'},
    ]);
    final rows = Excel.decodeBytes(libro.save()!).tables['Caja']!.rows;
    expect(rows[0][6]!.value.toString(), 'Medio de pago');
    expect(rows[1][6]!.value.toString(), 'Transferencia');
    expect(rows[1][7]!.value.toString(), 'caja@example.com');
    expect(rows[1][0]!.value.toString(), '03/11/2026 12:00');
    expect(rows[1][8]!.value.toString(), '04/11/2026 13:00');
    expect(rows[2][6]!.value.toString(), 'Efectivo');
    expect(rows[3][6]!.value.toString(), 'Sin movimiento de dinero');
    expect(num.parse(rows[4][4]!.value.toString()), 100);
    expect(num.parse(rows[4][5]!.value.toString()), 20);
    expect(num.parse(rows[5][4]!.value.toString()), 80);
  });
  test('históricos sin datos no se clasifican como efectivo ni se inventa fecha', () {
    final rows = ExportacionCaja.crear([{'tipo':'ingreso','monto':50}]).tables['Caja']!.rows;
    for(final columna in [0,6,7,8]) {
      expect(rows[1][columna]!.value.toString(), 'Sin registrar');
    }
  });
}
