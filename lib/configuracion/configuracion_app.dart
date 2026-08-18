import 'package:flutter/material.dart';

class ConfiguracionApp {
  final String nombreApp;

  // Identificador de la aplicación / Firebase Legacy.
  //
  // Ejemplos:
  // guemes
  // fatima
  // laloma
  final String nombreSabor;

  // Identificador del club dentro de TuSede Central.
  //
  // A partir de la Etapa 4A este es el valor que debe
  // utilizar toda la arquitectura multiclub.
  final String clubIdTuSede;

  final String prefijoColeccion;

  final Color colorPrimario;
  final Color colorSecundario;

  final String rutaLogo;

  final String urlSubidaFoto;

  static late ConfiguracionApp actual;

  const ConfiguracionApp({
    required this.nombreApp,
    required this.nombreSabor,
    required this.clubIdTuSede,
    required this.prefijoColeccion,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.rutaLogo,
    required this.urlSubidaFoto,
  });
}