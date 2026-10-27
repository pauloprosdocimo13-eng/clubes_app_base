import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/pantallas/pantalla_respaldos_club.dart';

void main() {
  final backup = <String, dynamic>{
    'id': 'a' * 32,
    'tipo': 'respaldo',
    'nombre': 'Demo',
    'clubId': 'demo',
    'estado': 'completado',
    'creadoMs': 1000,
    'documentos': 2,
    'archivos': 1,
  };
  testWidgets('Recuperación exige confirmación y usa un destino nuevo', (
    tester,
  ) async {
    Map<String, dynamic>? solicitud;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaRespaldosClub(
          clubes: const [],
          ejecutar: (a, d) async {
            if (a == 'listar')
              return {
                'operaciones': [backup],
              };
            expect(a, 'restaurar');
            solicitud = d;
            return {
              'estado': 'completado',
              'tipo': 'restauracion',
              'destino': d['destino'],
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recuperar como borrador'));
    await tester.tap(find.text('Recuperar como borrador'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'nuevo');
    await tester.enterText(find.byType(TextFormField).at(1), 'distinto');
    await tester.tap(find.text('Recuperar borrador'));
    await tester.pumpAndSettle();
    expect(solicitud, isNull);
    expect(find.text('Los identificadores deben coincidir'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'nuevo');
    await tester.tap(find.text('Recuperar borrador'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(solicitud, containsPair('destino', 'nuevo'));
    expect(solicitud, containsPair('confirmacion', 'nuevo'));
    expect(solicitud, containsPair('respaldoId', 'a' * 32));
    expect(find.textContaining('quedó en borrador'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Retomar continúa la operación existente sin crear otra', (
    tester,
  ) async {
    final acciones = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaRespaldosClub(
          clubes: const [],
          ejecutar: (a, d) async {
            acciones.add(a);
            if (a == 'listar')
              return {
                'operaciones': [
                  {...backup, 'estado': 'imagenes'},
                ],
              };
            expect(a, 'continuar');
            expect(d['operacionId'], backup['id']);
            return backup;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retomar'));
    await tester.tap(find.text('Retomar'));
    await tester.pumpAndSettle();
    expect(acciones, ['listar', 'continuar', 'listar']);
    expect(find.text('Respaldo completo y verificado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
