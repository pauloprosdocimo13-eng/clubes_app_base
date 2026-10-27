import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/pantallas/pantalla_rivales.dart';
import 'package:clubes_app_base/configuracion/configuracion_app.dart';
import 'package:clubes_app_base/tusede/modelos/club_tusede.dart';
import 'package:clubes_app_base/tusede/servicios/contexto_club.dart';

void main() {
  const config = ConfiguracionApp(
    nombreApp: 'Prueba',
    nombreSabor: 'generico',
    clubIdTuSede: 'club-test',
    prefijoColeccion: '',
    colorPrimario: Colors.blue,
    colorSecundario: Colors.white,
    rutaLogo: '',
    urlSubidaFoto: '',
  );
  setUp(
    () => ContextoClub.cambiarClub(
      const ClubTuSede(
        id: 'club-test',
        origenDatos: 'central',
        nombre: 'Prueba',
        slug: 'club-test',
        flavorLegacy: 'generico',
      ),
    ),
  );
  tearDown(ContextoClub.limpiar);
  testWidgets('Rivales Central se muestran sin inicializar Firebase DEFAULT', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaRivales(
          config: config,
          deporteId: 'baby',
          cargarCentral: (deporte) async {
            expect(deporte, 'baby');
            return [
              {
                'nombre': 'Club Visitante',
                'direccion': 'Calle 123',
                'es_techado': true,
              },
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Club Visitante'), findsOneWidget);
    expect(find.text('CANCHA TECHADA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Error de red permite reintentar y muestra lista vacía', (
    tester,
  ) async {
    var llamadas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaRivales(
          config: config,
          deporteId: 'baby',
          cargarCentral: (_) async {
            if (++llamadas == 1) throw Exception('red');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los rivales.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay rivales cargados.'), findsOneWidget);
    expect(llamadas, 2);
    expect(tester.takeException(), isNull);
  });
}
