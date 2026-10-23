import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/pantallas/pantalla_eliminar_club.dart';

void main() {
  testWidgets('Abrir y escribir un ID incorrecto nunca inicia el borrado', (
    tester,
  ) async {
    final acciones = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaEliminarClub(
          clubId: 'demo',
          nombre: 'Demo',
          ejecutar: (accion, datos) async {
            acciones.add(accion);
            return {
              'enCurso': false,
              'token': 'vista',
              'cuentas': [],
              'colecciones': [],
              'archivos': 0,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(acciones, ['prepararEliminacion']);
    await tester.enterText(find.byType(TextField), 'otro');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    expect(acciones, ['prepararEliminacion']);
  });

  testWidgets(
    'ID exacto confirma con token y solo muestra éxito después de verificación',
    (tester) async {
      final acciones = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaEliminarClub(
            clubId: 'demo',
            nombre: 'Demo',
            ejecutar: (accion, datos) async {
              acciones.add(accion);
              expect(datos['clubId'], 'demo');
              if (accion == 'prepararEliminacion') {
                return {
                  'enCurso': false,
                  'token': 'vista',
                  'cuentas': [],
                  'colecciones': [],
                  'archivos': 0,
                };
              }
              if (accion == 'iniciarEliminacion') {
                expect(datos['confirmacion'], 'demo');
                expect(datos['token'], 'vista');
                return {'estado': 'usuarios'};
              }
              return {'estado': 'completada'};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'demo');
      await tester.pump();
      final boton = find.widgetWithText(
        FilledButton,
        'Eliminar definitivamente',
      );
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(acciones, [
        'prepararEliminacion',
        'iniciarEliminacion',
        'continuarEliminacion',
      ]);
      expect(find.text('Eliminación completada y verificada.'), findsOneWidget);
    },
  );

  testWidgets('Un trabajo pendiente se retoma sin crear otra eliminación', (
    tester,
  ) async {
    final acciones = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaEliminarClub(
          clubId: 'demo',
          nombre: 'Demo',
          ejecutar: (accion, datos) async {
            acciones.add(accion);
            return accion == 'prepararEliminacion'
                ? {'enCurso': true, 'estado': 'documentos'}
                : {'estado': 'completada'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Continuar eliminación'));
    await tester.pumpAndSettle();
    expect(acciones, ['prepararEliminacion', 'continuarEliminacion']);
  });
}
