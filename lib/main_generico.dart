import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 1. IMPORTAR MESSAGING
import 'firebase_options_generico.dart'; // OJO: Usamos el archivo de opciones GENÉRICO
import 'configuracion/configuracion_app.dart';
import 'mi_aplicacion.dart';
import 'package:flutter/foundation.dart'; // Para usar kIsWeb


// 2. HANDLER DE SEGUNDO PLANO
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Notificación Genérica recibida en 2do plano: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 3. INICIALIZAR FIREBASE CON OPCIONES GENÉRICAS
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. REGISTRAR HANDLER
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final genericoConfig = ConfiguracionApp(
    nombreApp: "Club Genérico",
    nombreSabor: "generico",
    colorPrimario: Colors.blue,
    colorSecundario: Colors.grey,
    rutaLogo: "assets/logo_generico.png",
    prefijoColeccion: "generico",
  );

  // 5. ARRANCAR APP
  runApp(MiAplicacion(config: genericoConfig));

  // 6. INICIAR NOTIFICACIONES
  _iniciarNotificaciones();
}

Future<void> _iniciarNotificaciones() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Permisos Genéricos: ${settings.authorizationStatus}');

    // SUSCRIPCIÓN A TEMA GENÉRICO (Diferente al de Güemes)
    await messaging.subscribeToTopic('general');
    print("Suscrito a 'general'");

    final token = await messaging.getToken();
    print("========================================");
    print("TOKEN FCM GENÉRICO: $token");
    print("========================================");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje en primer plano: ${message.notification?.title}');
    });

  } catch (e) {
    print("Error notificaciones genérico: $e");
  }
}