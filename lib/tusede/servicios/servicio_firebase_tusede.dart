import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options_tusede.dart';

class ServicioFirebaseTuSede {
  ServicioFirebaseTuSede._();

  static const String nombreApp = 'tusede-central';

  static FirebaseApp? _app;

  // ============================================================
  // PLATAFORMAS
  // ============================================================

  static bool get plataformaSoportada {
    if (kIsWeb) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }

    return false;
  }

  // ============================================================
  // ESTADO
  // ============================================================

  static bool get estaInicializado {
    return _app != null;
  }

  static FirebaseApp get app {
    final firebaseApp = _app;

    if (firebaseApp == null) {
      throw StateError('Firebase TuSede Central todavía no fue inicializado.');
    }

    return firebaseApp;
  }

  // ============================================================
  // SERVICIOS FIREBASE TUSEDE
  // ============================================================

  /// Firestore perteneciente exclusivamente al proyecto
  /// central TuSede.
  static FirebaseFirestore get firestore {
    return FirebaseFirestore.instanceFor(app: app);
  }

  /// Authentication perteneciente exclusivamente al proyecto
  /// central TuSede.
  ///
  /// FirebaseAuth.instance continúa apuntando al Firebase
  /// tradicional del club.
  static FirebaseAuth get auth {
    return FirebaseAuth.instanceFor(app: app);
  }

  // ============================================================
  // INICIALIZACIÓN
  // ============================================================

  static Future<bool> inicializar() async {
    if (!plataformaSoportada) {
      debugPrint('TuSede Central: plataforma todavía no configurada.');

      return false;
    }

    // Si ya existe la aplicación secundaria, la reutilizamos.
    for (final firebaseApp in Firebase.apps) {
      if (firebaseApp.name == nombreApp) {
        _app = firebaseApp;

        debugPrint('TuSede Central: instancia existente recuperada.');

        return true;
      }
    }

    final options = _obtenerFirebaseOptions();

    _app = await Firebase.initializeApp(name: nombreApp, options: options);

    debugPrint('TuSede Central: Firebase secundario inicializado.');

    debugPrint('TuSede Central: plataforma ${_nombrePlataforma()}.');

    return true;
  }

  // ============================================================
  // FIREBASE OPTIONS
  // ============================================================

  static FirebaseOptions _obtenerFirebaseOptions() {
    if (kIsWeb) {
      return FirebaseOptionsTuSede.web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptionsTuSede.android;

      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'TuSede Central todavía no está configurado '
          'para esta plataforma.',
        );
    }
  }

  static String _nombrePlataforma() {
    if (kIsWeb) {
      return 'Web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';

      case TargetPlatform.iOS:
        return 'iOS';

      case TargetPlatform.macOS:
        return 'macOS';

      case TargetPlatform.windows:
        return 'Windows';

      case TargetPlatform.linux:
        return 'Linux';

      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
