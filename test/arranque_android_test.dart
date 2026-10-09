import 'dart:convert';
import 'dart:io';

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clubes_app_base/app_bootstrap.dart';
import 'package:clubes_app_base/configuracion/registro_flavors.dart';
import 'package:clubes_app_base/firebase_options_generico.dart' as generico;
import 'package:clubes_app_base/firebase_options_guemes.dart' as guemes;
import 'package:clubes_app_base/firebase_options_fatima.dart' as fatima;
import 'package:clubes_app_base/firebase_options_laloma.dart' as laloma;
import 'package:clubes_app_base/servicios/servicio_notificaciones_topics.dart';
import 'package:clubes_app_base/configuracion/configuracion_app.dart';
import 'package:clubes_app_base/pantallas/pantalla_splash.dart';
import 'package:clubes_app_base/pantallas/pantalla_seleccion.dart';
import 'package:clubes_app_base/tusede/servicios/contexto_club.dart';

class _FirebaseNativo extends FirebasePlatform {
  _FirebaseNativo(this.opciones);
  final FirebaseOptions opciones;
  FirebaseOptions? opcionesSolicitadas;
  String? nombreSolicitado;

  @override
  Future<FirebaseAppPlatform> initializeApp({String? name, FirebaseOptions? options}) async {
    opcionesSolicitadas = options;
    nombreSolicitado = name;
    return FirebaseAppPlatform('[DEFAULT]', opciones);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final plataformaOriginal = FirebasePlatform.instance;
  tearDown(() => FirebasePlatform.instance = plataformaOriginal);

  final opciones = {
    'generico': generico.DefaultFirebaseOptions.android,
    'guemes': guemes.DefaultFirebaseOptions.android,
    'fatima': fatima.DefaultFirebaseOptions.android,
    'laloma': laloma.DefaultFirebaseOptions.android,
  };
  final paquetes = {
    'generico': 'com.prosdodigital.generico',
    'guemes': 'com.martinguemesfutbol.app',
    'fatima': 'com.prosdodigital.fatima',
    'laloma': 'com.prosdodigital.laloma',
  };

  for (final sabor in opciones.keys) {
    test('Android $sabor: configuración Dart coincide con cliente nativo del APK', () {
      final config = jsonDecode(File('android/app/src/$sabor/google-services.json').readAsStringSync()) as Map;
      final cliente = (config['client'] as List).cast<Map>().singleWhere(
        (c) => c['client_info']['android_client_info']['package_name'] == paquetes[sabor],
      );
      final dart = opciones[sabor]!;
      expect(dart.appId, cliente['client_info']['mobilesdk_app_id']);
      expect(dart.projectId, config['project_info']['project_id']);
      expect(dart.messagingSenderId, config['project_info']['project_number']);
    });
  }

  for (final sabor in ['generico', 'guemes']) {
    test('Segundo plano $sabor recupera proyecto nativo sin asumir Güemes', () async {
      final nativo = _FirebaseNativo(opciones[sabor]!);
      FirebasePlatform.instance = nativo;
      await firebaseMessagingBackgroundHandler(const RemoteMessage(messageId: 'prueba'));
      expect(nativo.opcionesSolicitadas, isNull);
      expect(nativo.nombreSolicitado, isNull);
    });
  }

  test('Horizonte Android recibe del mismo proyecto Central que publica el backend', () {
    expect(opciones['generico']!.projectId, 'tu-sede-app');
    expect(opciones['guemes']!.projectId, 'club-guemes-2');
    final config = RegistroFlavors.configDe('generico');
    expect(ServicioNotificacionesTopics.topicGeneral(config), 'tusede_generico_general');
    expect(ServicioNotificacionesTopics.topicPartidos(config), 'tusede_generico_partidos');
    final legacy = RegistroFlavors.configDe('guemes');
    expect(ServicioNotificacionesTopics.topicGeneral(legacy), '${legacy.prefijoColeccion}_general');
  });

  test('No admite entrypoint y flavor Android de clubes distintos', () {
    expect(() => RegistroFlavors.validarFlavorAndroid('generico', 'guemes'), throwsStateError);
    expect(() => RegistroFlavors.validarFlavorAndroid('generico', null), throwsStateError);
    for (final sabor in opciones.keys) {
      expect(() => RegistroFlavors.validarFlavorAndroid(sabor, sabor), returnsNormally);
    }
  });

  testWidgets('Una notificación de inicio espera a que Splash cambie de pantalla', (tester) async {
    final config = RegistroFlavors.configDe('generico');
    ConfiguracionApp.actual = config;
    ContextoClub.inicializarDesdeConfiguracion(config);
    var listo = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: PantallaSplash(
        config: config,
        onNavegacionLista: () => listo = true,
      )));
      await tester.pump(const Duration(milliseconds: 500));
      expect(listo, isFalse);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(listo, isTrue);
      expect(find.byType(PantallaSeleccion), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      return http.Response(jsonEncode(body['accion'] == 'configuracion'
          ? {'ok': true, 'activar_multi_actividad': false, 'menu_deportes': []}
          : {'ok': true, 'datos': {}}), 200);
    }));
    ContextoClub.limpiar();
  });
}
