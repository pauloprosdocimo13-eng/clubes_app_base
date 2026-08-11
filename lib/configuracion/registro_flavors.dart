import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'configuracion_app.dart';
import '../firebase_options_fatima.dart' as fatima;
import '../firebase_options_generico.dart' as generico;
import '../firebase_options_guemes.dart' as guemes;
import '../firebase_options_laloma.dart' as laloma;

class RegistroFlavors {
  static const saboresValidos = ['guemes', 'fatima', 'laloma', 'generico'];

  static ConfiguracionApp configDe(String sabor) {
    switch (sabor) {
      case 'fatima':
        return const ConfiguracionApp(
          nombreApp: 'Club Fátima',
          nombreSabor: 'fatima',
          colorPrimario: Color(0xFFFFD700),
          colorSecundario: Color(0xFF000000),
          rutaLogo: 'assets/logo_fatima.png',
          prefijoColeccion: 'fatima',
          urlSubidaFoto: 'https://fatima.prosdodigital.site/api/subir_foto.php',
        );
      case 'laloma':
        return const ConfiguracionApp(
          nombreApp: 'Club La Loma',
          nombreSabor: 'laloma',
          colorPrimario: Color(0xFF1E88E5),
          colorSecundario: Color(0xFF000000),
          rutaLogo: 'assets/la_loma.png',
          prefijoColeccion: 'laloma',
          urlSubidaFoto: 'https://laloma.prosdodigital.site/api/subir_foto.php',
        );
      case 'generico':
        return const ConfiguracionApp(
          nombreApp: 'Club Genérico',
          nombreSabor: 'generico',
          colorPrimario: Colors.blue,
          colorSecundario: Colors.grey,
          rutaLogo: 'assets/logo_generico.png',
          prefijoColeccion: 'generico',
          urlSubidaFoto: 'https://tusitio.com/api/clubes/generico/subir_foto.php',
        );
      case 'guemes':
      default:
        return const ConfiguracionApp(
          nombreApp: 'Club Martín Güemes',
          nombreSabor: 'guemes',
          colorPrimario: Color(0xFFDA291C),
          colorSecundario: Colors.black,
          rutaLogo: 'assets/logo_guemes.png',
          prefijoColeccion: 'guemes',
          urlSubidaFoto: 'https://martinguemes.site/api/subir_foto.php',
        );
    }
  }

  static FirebaseOptions firebaseOptionsDe(String sabor) {
    switch (sabor) {
      case 'fatima':
        return fatima.DefaultFirebaseOptions.currentPlatform;
      case 'laloma':
        return laloma.DefaultFirebaseOptions.currentPlatform;
      case 'generico':
        return generico.DefaultFirebaseOptions.currentPlatform;
      case 'guemes':
      default:
        return guemes.DefaultFirebaseOptions.currentPlatform;
    }
  }
}
