import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'firebase_options_guemes.dart'; 
import 'configuracion/configuracion_app.dart';
import 'package:flutter/foundation.dart'; 
import 'pantallas/pantalla_splash.dart';
import 'pantallas/pantalla_seleccion.dart'; 

// HANDLER DE SEGUNDO PLANO
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Notificación recibida en 2do plano: ${message.messageId}");
}

void main() async { // <--- Volvemos a poner 'async'
  WidgetsFlutterBinding.ensureInitialized();

  // --- VOLVEMOS A LA SEGURIDAD ---
  // Usamos 'await' para evitar el congelamiento (ANR).
  // Esto asegura que los canales nativos estén listos antes de dibujar nada.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Registramos el handler de fondo
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final guemesConfig = ConfiguracionApp(
    nombreApp: "Club Martín Güemes",
    nombreSabor: "guemes",
    colorPrimario: const Color(0xFFDA291C), 
    colorSecundario: Colors.black,
    rutaLogo: "assets/logo_guemes.png",
    prefijoColeccion: "guemes",
  );

  // Arrancamos la app
  runApp(MiAplicacion(config: guemesConfig));

  // Iniciamos notificaciones
  _iniciarNotificaciones();
}

// CONFIGURACIÓN DE NOTIFICACIONES
Future<void> _iniciarNotificaciones() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    print('Permisos notif: ${settings.authorizationStatus}');

    await messaging.subscribeToTopic('guemes_general');
    
    final token = await messaging.getToken();
    // print("TOKEN FCM: $token"); 

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje en primer plano: ${message.notification?.title}');
    });
  } catch (e) {
    print("Error notificaciones: $e");
  }
}

class MiAplicacion extends StatelessWidget {
  final ConfiguracionApp config;

  const MiAplicacion({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: config.nombreApp,
      theme: ThemeData(
        primaryColor: config.colorPrimario,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: config.colorPrimario),
        appBarTheme: AppBarTheme(
          backgroundColor: config.colorPrimario,
          foregroundColor: Colors.white,
        ),
      ),
      // Arrancamos con tu Splash animado
      home: PantallaSplash(config: config),
    );
  }
}