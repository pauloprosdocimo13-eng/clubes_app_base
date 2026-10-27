import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/pantallas/pantalla_equipo_club.dart';

void main() {
  testWidgets('Protege administradores y permite desactivar equipo', (
    tester,
  ) async {
    Map<String, dynamic>? cambio;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaEquipoClub(
          clubId: 'club-test',
          nombreClub: 'Prueba',
          ejecutar: (accion, datos) async {
            expect(datos['clubId'], 'club-test');
            if (accion == 'editarEquipo') {
              cambio = datos;
              return {};
            }
            return {
              'usuarios': [
                {
                  'uid': 'admin',
                  'nombre': 'Administrador',
                  'email': 'admin@example.com',
                  'rol': 'admin',
                  'activo': true,
                  'editable': false,
                },
                {
                  'uid': 'staff',
                  'nombre': 'Empleado',
                  'email': 'staff@example.com',
                  'rol': 'deportes',
                  'activo': true,
                  'editable': true,
                },
              ],
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuenta protegida'), findsOneWidget);
    expect(find.text('Rol y acceso'), findsOneWidget);
    await tester.tap(find.text('Rol y acceso'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(cambio, containsPair('uid', 'staff'));
    expect(cambio, containsPair('activo', false));
    expect(cambio, containsPair('rol', 'deportes'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un error de acceso impide crear cuentas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaEquipoClub(
          clubId: 'club-test',
          nombreClub: 'Prueba',
          ejecutar: (_, _) async => throw Exception('Acceso denegado'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Acceso denegado'), findsOneWidget);
    final boton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(boton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
