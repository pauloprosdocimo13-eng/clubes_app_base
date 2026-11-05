import 'package:flutter_test/flutter_test.dart';
import '../lib/servicios/fecha_caja.dart';

void main() {
  test('Argentina cambia de día a las 03 UTC, incluso al cambiar de año', () {
    final antes = FechaCaja.ahoraArgentina(DateTime.utc(2027, 1, 1, 2, 59));
    expect(antes.year, 2026);
    expect(antes.month, 12);
    expect(antes.day, 31);
    expect(antes.hour, 23);
    final despues = FechaCaja.ahoraArgentina(DateTime.utc(2027, 1, 1, 3));
    expect(despues.day, 1);
    expect(despues.hour, 0);
  });
  test('fecha elegida se convierte a instante UTC sin depender de zona del equipo', () {
    expect(FechaCaja.aUtc(DateTime(2026, 11, 4, 23, 30)), DateTime.utc(2026, 11, 5, 2, 30));
  });
}
