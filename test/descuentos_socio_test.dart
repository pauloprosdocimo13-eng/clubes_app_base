import 'package:flutter_test/flutter_test.dart';
import '../lib/servicios/descuentos_socio.dart';

void main() {
  test('socio sin preferencias inicia sin descuento', () {
    expect(DescuentosSocio.paraCobro(null, ['Cuota Social', 'Futbol']), {'Cuota Social': 0, 'Futbol': 0});
  });
  test('recupera beca y descuento por actividad, nuevas actividades sin descuento', () {
    expect(DescuentosSocio.paraCobro({'Cuota Social': 100, 'Futbol': 30}, ['Cuota Social', 'Futbol', 'Patin']), {'Cuota Social': 100, 'Futbol': 30, 'Patin': 0});
  });
  test('sin descuento explícito quita la preferencia para próximos cobros', () {
    expect(DescuentosSocio.paraCobro({'Futbol': 0}, ['Futbol']), {'Futbol': 0});
  });
  test('ignora valores corruptos y no hereda preferencias entre actividades', () {
    expect(DescuentosSocio.paraCobro({'Futbol': 150, 'Patin': '50', 'Cuota Social': 50.0}, ['Futbol', 'Patin', 'Cuota Social']), {'Futbol': 0, 'Patin': 0, 'Cuota Social': 50});
  });
}
