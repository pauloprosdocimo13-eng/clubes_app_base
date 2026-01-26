import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode

// 1. HANDLER DE SEGUNDO PLANO (Tiene que estar FUERA de la clase)
// Esta función se ejecuta cuando la app está cerrada o minimizada y llega una notificación
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Si necesitas usar Firebase aquí (ej: guardar en BD), asegúrate de inicializarlo:
  await Firebase.initializeApp();
  print("Notificación recibida en Segundo Plano: ${message.messageId}");
}

class NotificacionesService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> inicializar() async {
    // 2. PEDIR PERMISOS (Crítico para Android 13+ y iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Estado de permisos: ${settings.authorizationStatus}');

    // 3. DEFINIR EL MANEJADOR DE SEGUNDO PLANO
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. ESCUCHAR MENSAJES EN PRIMER PLANO (App abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificación en Primer Plano:');
      print('Título: ${message.notification?.title}');
      print('Cuerpo: ${message.notification?.body}');

      // Opcional: Si quieres mostrar un cartelito dentro de la app cuando la tienes abierta:
      // showDialog(...) o ScaffoldMessenger...
    });

    // 5. OBTENER EL TOKEN DEL DISPOSITIVO
    // Este es el "DNI" del celular. Lo necesitas para enviarle notificaciones de prueba.
    final token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print("========================================");
      print("TOKEN DE NOTIFICACIONES: $token");
      print("========================================");
    }

    // 6. SUSCRIPCIÓN A UN TEMA GENERAL (Opcional pero recomendado)
    // Esto te permite enviar una notif a "todos" sin saber sus tokens.
    await _firebaseMessaging.subscribeToTopic('general');
  }
}