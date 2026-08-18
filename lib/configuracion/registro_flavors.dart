import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion_app.dart';

import '../firebase_options_fatima.dart' as fatima;
import '../firebase_options_generico.dart' as generico;
import '../firebase_options_guemes.dart' as guemes;
import '../firebase_options_laloma.dart' as laloma;

class RegistroFlavors {
  static const saboresValidos = [
    'guemes',
    'fatima',
    'laloma',
    'generico',
  ];

  // ============================================================
  // CONFIGURACIÓN DEL CLUB
  // ============================================================

  static ConfiguracionApp configDe(
    String sabor,
  ) {
    switch (sabor) {
      case 'fatima':
        return const ConfiguracionApp(
          nombreApp: 'Club Fátima',

          // Sistema Legacy
          nombreSabor: 'fatima',

          // TuSede Central
          clubIdTuSede: 'fatima',

          prefijoColeccion: 'fatima',

          colorPrimario:
              Color(0xFFFFD700),

          colorSecundario:
              Color(0xFF000000),

          rutaLogo:
              'assets/logo_fatima.png',

          urlSubidaFoto:
              'https://fatima.prosdodigital.site/api/subir_foto.php',
        );

      case 'laloma':
        return const ConfiguracionApp(
          nombreApp: 'Club La Loma',

          nombreSabor: 'laloma',

          clubIdTuSede: 'laloma',

          prefijoColeccion: 'laloma',

          colorPrimario:
              Color(0xFF1E88E5),

          colorSecundario:
              Color(0xFF000000),

          rutaLogo:
              'assets/la_loma.png',

          urlSubidaFoto:
              'https://laloma.prosdodigital.site/api/subir_foto.php',
        );

      case 'generico':
        return const ConfiguracionApp(
          nombreApp: 'Club Genérico',

          nombreSabor: 'generico',

          clubIdTuSede: 'generico',

          prefijoColeccion: 'generico',

          colorPrimario:
              Colors.blue,

          colorSecundario:
              Colors.grey,

          rutaLogo:
              'assets/logo_generico.png',

          urlSubidaFoto:
              'https://tusitio.com/api/clubes/generico/subir_foto.php',
        );

      case 'guemes':
      default:
        return const ConfiguracionApp(
          nombreApp:
              'Club Martín Güemes',

          // Firebase Legacy actual
          nombreSabor:
              'guemes',

          // Identificador central TuSede
          clubIdTuSede:
              'guemes',

          prefijoColeccion:
              'guemes',

          colorPrimario:
              Color(0xFFDA291C),

          colorSecundario:
              Colors.black,

          rutaLogo:
              'assets/logo_guemes.png',

          urlSubidaFoto:
              'https://martinguemes.site/api/subir_foto.php',
        );
    }
  }

  // ============================================================
  // FIREBASE LEGACY
  // ============================================================
  //
  // Esto NO cambia todavía.
  //
  // Cada aplicación sigue utilizando su Firebase actual
  // como instancia DEFAULT.

  static FirebaseOptions firebaseOptionsDe(
    String sabor,
  ) {
    switch (sabor) {
      case 'fatima':
        return fatima
            .DefaultFirebaseOptions
            .currentPlatform;

      case 'laloma':
        return laloma
            .DefaultFirebaseOptions
            .currentPlatform;

      case 'generico':
        return generico
            .DefaultFirebaseOptions
            .currentPlatform;

      case 'guemes':
      default:
        return guemes
            .DefaultFirebaseOptions
            .currentPlatform;
    }
  }
}