import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'mi_aplicacion.dart';
import 'pantallas/pantalla_avisos.dart';
import 'pantallas/pantalla_noticias.dart';
import 'servicios/servicio_notificaciones_topics.dart';
import 'tusede/servicios/contexto_club.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final sabor = const String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'guemes',
  );

  await Firebase.initializeApp(
    options: RegistroFlavors.firebaseOptionsDe(sabor),
  );

  debugPrint(
    'Notificación en 2do plano: ${message.messageId}',
  );
}

Future<void> bootstrapApp(String sabor) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = RegistroFlavors.configDe(sabor);

  await Firebase.initializeApp(
    options: RegistroFlavors.firebaseOptionsDe(sabor),
  );

  // ============================================================
  // CONTEXTO GENERAL DE LA APLICACIÓN
  // ============================================================

  ConfiguracionApp.actual = config;

  // A partir de este punto TuSede conoce qué club está utilizando
  // la aplicación.
  //
  // Actualmente:
  //
  // guemes  -> clubId "guemes"
  // fatima  -> clubId "fatima"
  // laloma  -> clubId "laloma"
  //
  // Más adelante este contexto se obtendrá desde la plataforma
  // central TuSede y no desde los flavors.
  ContextoClub.inicializarDesdeConfiguracion(config);

  debugPrint(
    'TuSede iniciado - Club: ${ContextoClub.nombreClub} '
    '(${ContextoClub.clubId})',
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await _iniciarNotificaciones(config);

  runApp(
    MiAplicacion(
      config: config,
      navigatorKey: navigatorKey,
    ),
  );
}

Future<void> _iniciarNotificaciones(
  ConfiguracionApp config,
) async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus !=
            AuthorizationStatus.authorized &&
        settings.authorizationStatus !=
            AuthorizationStatus.provisional) {
      return;
    }

    if (!kIsWeb) {
      final topicGeneral =
          ServicioNotificacionesTopics.topicGeneral(config);

      final topicPartidos =
          ServicioNotificacionesTopics.topicPartidos(config);

      await messaging.subscribeToTopic(topicGeneral);
      await messaging.subscribeToTopic(topicPartidos);

      debugPrint(
        'Suscrito a $topicGeneral y $topicPartidos',
      );
    }

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        _manejarRedireccion(message, config);
      },
    );

    final initialMessage =
        await messaging.getInitialMessage();

    if (initialMessage != null) {
      Future.delayed(
        const Duration(milliseconds: 1500),
        () {
          _manejarRedireccion(
            initialMessage,
            config,
          );
        },
      );
    }

    FirebaseMessaging.onMessage.listen(
      (message) {
        debugPrint(
          'Mensaje en primer plano: '
          '${message.notification?.title}',
        );
      },
    );
  } catch (e) {
    debugPrint(
      'Error en notificaciones: $e',
    );
  }
}

void _manejarRedireccion(
  RemoteMessage message,
  ConfiguracionApp config,
) {
  final tipo = message.data['tipo'];

  final nav = navigatorKey.currentState;

  if (nav == null) return;

  if (tipo == 'noticia') {
    nav.push(
      MaterialPageRoute(
        builder: (_) => PantallaNoticias(
          config: config,
        ),
      ),
    );
  } else if (tipo == 'aviso') {
    nav.push(
      MaterialPageRoute(
        builder: (_) => PantallaAvisos(
          config: config,
          deporteId: 'general',
        ),
      ),
    );
  }
}