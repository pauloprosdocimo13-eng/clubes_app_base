import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/main_tusede.dart';
import 'package:clubes_app_base/tusede/pantallas/pantalla_acceso_club.dart';
import 'package:clubes_app_base/tusede/servicios/servicio_accesos_club.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  String estado = 'solicitado';
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    estado = 'solicitado';
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ServicioAccesosClub.canal,
      (call) async {
        calls.add(call);
        if (call.method == 'start') return {'clubId': 'naon'};
        if (call.method == 'supported') return true;
        return {'estado': estado, 'conEscudo': true};
      },
    );
  });
  tearDown(() {
    ServicioAccesosClub.canal.setMethodCallHandler(null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ServicioAccesosClub.canal,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> launch(String? id) async {
    // Simula una llamada originada por onNewIntent, no una respuesta a Dart.
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'tusede/club_shortcuts',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('launch', {'clubId': id}),
      ),
      (_) {},
    );
  }

  test(
    'La solicitud no afirma que el usuario confirmó y usa ID/nombre/escudo',
    () async {
      expect(await ServicioAccesosClub.disponible(), true);
      final msg = await ServicioAccesosClub.agregar({
        'id': 'naon',
        'nombre': 'Naon',
        'identidad': {'logoUrl': 'https://example.com/logo.png'},
      });
      expect(msg, contains('Confirmá'));
      expect(calls.last.arguments['clubId'], 'naon');
      expect(calls.last.arguments['logoUrl'], 'https://example.com/logo.png');
      estado = 'actualizado';
      expect(
        await ServicioAccesosClub.agregar({'id': 'naon', 'nombre': 'Naon'}),
        contains('ya existía'),
      );
    },
  );
  test('Nunca resuelve clubes borrador, inactivos, Legacy o IDs inválidos', () {
    final active = {
      'id': 'naon',
      'activo': true,
      'estado': 'activo',
      'origenDatos': 'central',
    };
    expect(
      clubPublicadoParaAcceso({
        'clubes': [active],
      }, 'naon'),
      isNotNull,
    );
    for (final change in [
      {'activo': false},
      {'estado': 'borrador'},
      {'origenDatos': 'legacy'},
    ]) {
      expect(
        clubPublicadoParaAcceso({
          'clubes': [
            {...active, ...change},
          ],
        }, 'naon'),
        isNull,
      );
    }
    expect(
      clubPublicadoParaAcceso({
        'clubes': [active],
      }, 'otro'),
      isNull,
    );
    expect(ServicioAccesosClub.idValido('../naon'), false);
  });
  testWidgets(
    'Arranque frío, cambio en caliente y catálogo descartan la navegación anterior',
    (tester) async {
      await tester.pumpWidget(
        AplicacionTuSede(
          crearInicio: (id) => Scaffold(body: Text(id ?? 'Catálogo')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('naon'), findsOneWidget);
      await launch('fatima');
      await tester.pumpAndSettle();
      expect(find.text('fatima'), findsOneWidget);
      expect(find.text('naon'), findsNothing);
      await launch(null);
      await tester.pumpAndSettle();
      expect(find.text('Catálogo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'Club eliminado muestra salida al catálogo sin inicializar Firebase',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaAccesoClub(
            clubId: 'borrado',
            cargar: () async => {'clubes': []},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Este club ya no está disponible en el catálogo.'),
        findsOneWidget,
      );
      expect(find.text('Ver otros clubes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('Sin conexión permite reintentar la apertura', (tester) async {
    var n = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAccesoClub(
          clubId: 'naon',
          cargar: () async {
            if (++n == 1) throw Exception('red');
            return {'clubes': []};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisá tu conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(n, 2);
    expect(
      find.text('Este club ya no está disponible en el catálogo.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
