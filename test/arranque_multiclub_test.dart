import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clubes_app_base/configuracion/registro_flavors.dart';
import 'package:clubes_app_base/servicios/servicio_actividades.dart';
import 'package:clubes_app_base/servicios/servicio_firebase.dart';
import 'package:clubes_app_base/servicios/servicio_version.dart';
import 'package:clubes_app_base/tusede/servicios/contexto_club.dart';
import 'package:clubes_app_base/tusede/servicios/servicio_configuracion_publica.dart';

void main() {
  tearDown(ContextoClub.limpiar);
  void club(String flavor) => ContextoClub.inicializarDesdeConfiguracion(
    RegistroFlavors.configDe(flavor),
  );

  test('Central no consulta Legacy al leer configuración pública', () async {
    club('generico');
    final servicio = ServicioConfiguracionPublica(
      leerLegacy: (_) async => throw StateError('No debe acceder a Legacy'),
      leerCentral: (doc) async => {'documento': doc},
    );
    expect(await servicio.cargarDocumento('aviso_entrada'), {
      'documento': 'aviso_entrada',
    });
  });

  test('Güemes conserva lectura Legacy y modo multi actividad', () async {
    club('guemes');
    final servicio = ServicioConfiguracionPublica(
      leerLegacy: (doc) async => {'activar_multi_actividad': true},
      leerCentral: (_) async => throw StateError('No debe acceder a Central'),
    );
    expect(await servicio.consultarModoMultiActividad(), isTrue);
  });

  for (final enabled in [true, false]) {
    test('Splash Central respeta activar_multi_actividad=$enabled', () async {
      club('generico');
      await http.runWithClient(
        () async {
          // También verifica que la entrada antigua no inicialice Firebase Legacy.
          expect(
            await ServicioFirebase().consultarModoMultiActividad(),
            enabled,
          );
        },
        () => MockClient((request) async {
          expect(jsonDecode(request.body), {
            'accion': 'configuracion',
            'clubId': 'generico',
          });
          return http.Response(
            jsonEncode({'ok': true, 'activar_multi_actividad': enabled}),
            200,
          );
        }),
      );
    });
  }

  test('Fallo Central usa modo seguro sin probar Legacy', () async {
    club('generico');
    await http.runWithClient(() async {
      expect(
        await ServicioConfiguracionPublica().consultarModoMultiActividad(),
        isFalse,
      );
    }, () => MockClient((_) async => http.Response('{"ok":false}', 503)));
  });

  test('Timeout de Legacy permite terminar el Splash', () async {
    club('guemes');
    final servicio = ServicioConfiguracionPublica(
      leerLegacy: (_) => Completer<Map<String, dynamic>>().future,
    );
    expect(
      await servicio.consultarModoMultiActividad(
        timeout: const Duration(milliseconds: 1),
      ),
      isFalse,
    );
  });

  test(
    'Central sin datos no muestra contactos ni aranceles de Güemes',
    () async {
      club('generico');
      await http.runWithClient(
        () async {
          expect(await ServicioActividades.cargarActividades(), isEmpty);
          expect(await ServicioActividades.cargarContactos(), isEmpty);
        },
        () => MockClient(
          (_) async => http.Response('{"ok":true,"datos":{"items":[]}}', 200),
        ),
      );
    },
  );

  test('Versión Central usa documento público del club', () async {
    club('generico');
    await http.runWithClient(
      () async {
        expect(
          await ServicioVersion.urlPlayStore(),
          'https://example.org/central',
        );
      },
      () => MockClient((request) async {
        expect(jsonDecode(request.body), {
          'accion': 'arranque',
          'clubId': 'generico',
          'documento': 'versiones',
        });
        return http.Response(
          '{"ok":true,"datos":{"url_playstore":"https://example.org/central"}}',
          200,
        );
      }),
    );
  });
}
