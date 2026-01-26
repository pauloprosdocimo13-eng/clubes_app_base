import 'package:flutter/material.dart';

class ConfiguracionApp {
  final String nombreApp;
  final String nombreSabor;       // <--- Nuevo campo
  final String prefijoColeccion;  // <--- Nuevo campo
  final Color colorPrimario;
  final Color colorSecundario;
  final String rutaLogo;          // <--- Antes se llamaba escudoUrl

  const ConfiguracionApp({
    required this.nombreApp,
    required this.nombreSabor,      // <--- Lo pedimos aquí
    required this.prefijoColeccion, // <--- Lo pedimos aquí
    required this.colorPrimario,
    required this.colorSecundario,
    required this.rutaLogo,         // <--- Lo pedimos aquí
  });
}