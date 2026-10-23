import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/diseno/identidad_tusede.dart';
import 'package:clubes_app_base/tusede/diseno/tarjeta_gestion_tusede.dart';
import 'package:clubes_app_base/tusede/pantallas/pantalla_catalogo_tusede.dart';

void main() {
  for (final ancho in [320.0, 500.0, 1200.0]) {
    testWidgets('Catálogo y acciones adaptables a $ancho con texto ampliado', (
      tester,
    ) async {
      tester.view.reset();
      tester.view.physicalSize = Size(ancho, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final club = <String, dynamic>{
        'id': 'prueba',
        'nombre': 'Club Social y Deportivo de la Comunidad',
        'estado': 'borrador',
      };
      var abierto = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaTuSede(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: VistaCatalogoTuSede(
              clubes: [club],
              onAbrir: (_) => abierto = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Conocé el club'), 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Conocé el club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conocé el club'));
      expect(abierto, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaTuSede(),
          home: Scaffold(
            body: ListView(
              children: [
                TarjetaGestionTuSede(
                  club: club,
                  onEditar: () {},
                  onAdministradores: () {},
                  onActivar: () {},
                  onLogo: () {},
                  onEliminar: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('El menú conserva las acciones y no borra al abrirse', (
    tester,
  ) async {
    var borrados = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTuSede(),
        home: Scaffold(
          body: TarjetaGestionTuSede(
            club: const {
              'id': 'prueba',
              'nombre': 'Prueba',
              'estado': 'borrador',
            },
            onLogo: () {},
            onActivar: () {},
            onEliminar: () => borrados++,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Más opciones del club'));
    await tester.pumpAndSettle();
    expect(borrados, 0);
    expect(find.text('Cambiar logo'), findsOneWidget);
    expect(find.text('Activar club'), findsOneWidget);
    await tester.tap(find.text('Eliminar club'));
    await tester.pumpAndSettle();
    expect(borrados, 1);
  });
}
