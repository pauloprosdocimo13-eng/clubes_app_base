import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../modelos/club_tusede.dart';

class ContextoClub {
  static ClubTuSede? _clubActual;

  ContextoClub._();

  // ============================================================
  // ESTADO
  // ============================================================

  static bool get estaInicializado {
    return _clubActual != null;
  }

  static ClubTuSede get clubActual {
    final club =
        _clubActual;

    if (club == null) {
      throw StateError(
        'ContextoClub todavía no fue inicializado. '
        'Debe inicializarse antes de utilizar datos de TuSede.',
      );
    }

    return club;
  }

  // ============================================================
  // IDENTIFICACION
  // ============================================================

  static String get clubId {
    return clubActual.id;
  }

  static String get nombreClub {
    return clubActual.nombre;
  }

  static String get nombreCorto {
    final valor =
        clubActual.nombreCorto
            .trim();

    if (valor.isNotEmpty) {
      return valor;
    }

    return nombreClub;
  }

  static String get flavorLegacy {
    return clubActual.flavorLegacy;
  }

  static bool get activo {
    return clubActual.activo;
  }

  static int get versionConfiguracion {
    return clubActual
        .versionConfiguracion;
  }

  // ============================================================
  // IDENTIDAD VISUAL CENTRAL
  // ============================================================

  static String get logoUrlCentral {
    return clubActual.logoUrl;
  }

  static String get lema {
    return clubActual.lema;
  }

  static String get colorPrimarioHex {
    return clubActual
        .colorPrimarioHex;
  }

  static String get colorSecundarioHex {
    return clubActual
        .colorSecundarioHex;
  }

  // Si el color central todavía no está configurado,
  // continuamos utilizando el color Legacy.

  static Color get colorPrimario {
    return _colorDesdeHex(
          clubActual
              .colorPrimarioHex,
        ) ??
        ConfiguracionApp
            .actual
            .colorPrimario;
  }

  static Color get colorSecundario {
    return _colorDesdeHex(
          clubActual
              .colorSecundarioHex,
        ) ??
        ConfiguracionApp
            .actual
            .colorSecundario;
  }

  // ============================================================
  // BRIDGE
  // ============================================================

  static bool get tusedeBridgeActivo {
    return clubActual
        .tusedeBridgeActivo;
  }

  // ============================================================
  // MODULOS
  // ============================================================

  static Map<String, bool>
      get modulos {
    return Map<String, bool>
        .unmodifiable(
      clubActual.modulos,
    );
  }

  static bool moduloActivo(
    String modulo, {
    bool valorPorDefecto = false,
  }) {
    return clubActual.moduloActivo(
      modulo,
      valorPorDefecto:
          valorPorDefecto,
    );
  }

  static List<String>
      get modulosActivos {
    return clubActual
        .modulosActivos;
  }

  // ============================================================
  // INICIALIZACION DESDE LEGACY
  // ============================================================

  static void
      inicializarDesdeConfiguracion(
    ConfiguracionApp configuracion,
  ) {
    final flavorLegacy =
        configuracion.nombreSabor
            .trim()
            .toLowerCase();

    // Desde 4A el ID de TuSede es independiente
    // del flavor Legacy.

    final clubId =
        _normalizarIdClub(
      configuracion.clubIdTuSede,
    );

    _clubActual =
        ClubTuSede(
      id:
          clubId,

      nombre:
          configuracion.nombreApp,

      slug:
          clubId,

      flavorLegacy:
          flavorLegacy,

      activo:
          true,

      // Valores centrales todavía desconocidos.
      // Se reemplazan cuando cargamos Firestore.

      tusedeBridgeActivo:
          false,

      versionConfiguracion:
          1,

      nombreCorto:
          configuracion.nombreApp,

      logoUrl:
          '',

      colorPrimarioHex:
          '',

      colorSecundarioHex:
          '',

      lema:
          '',

      modulos:
          const <String, bool>{},
    );
  }

  // ============================================================
  // INFORMACION CENTRAL
  // ============================================================

  static void cambiarClub(
    ClubTuSede club,
  ) {
    _clubActual =
        club;
  }

  // ============================================================
  // LIMPIAR
  // ============================================================

  static void limpiar() {
    _clubActual = null;
  }

  // ============================================================
  // COLORES
  // ============================================================

  static Color? _colorDesdeHex(
    String valor,
  ) {
    var hex =
        valor
            .trim()
            .toUpperCase();

    if (hex.startsWith('#')) {
      hex =
          hex.substring(1);
    }

    // RGB -> ARGB
    if (hex.length == 6) {
      hex =
          'FF$hex';
    }

    if (hex.length != 8) {
      return null;
    }

    final numero =
        int.tryParse(
      hex,
      radix: 16,
    );

    if (numero == null) {
      return null;
    }

    return Color(
      numero,
    );
  }

  // ============================================================
  // NORMALIZACION ID
  // ============================================================

  static String _normalizarIdClub(
    String valor,
  ) {
    var resultado =
        valor
            .trim()
            .toLowerCase();

    resultado =
        resultado
            .replaceAll(
              'á',
              'a',
            )
            .replaceAll(
              'é',
              'e',
            )
            .replaceAll(
              'í',
              'i',
            )
            .replaceAll(
              'ó',
              'o',
            )
            .replaceAll(
              'ú',
              'u',
            )
            .replaceAll(
              'ñ',
              'n',
            )
            .replaceAll(
              RegExp(
                r'[^a-z0-9_-]',
              ),
              '_',
            )
            .replaceAll(
              RegExp(
                r'_+',
              ),
              '_',
            );

    resultado =
        resultado.replaceAll(
      RegExp(
        r'^_+|_+$',
      ),
      '',
    );

    if (resultado.isEmpty) {
      throw ArgumentError(
        'No se pudo generar un clubId '
        'válido para TuSede.',
      );
    }

    return resultado;
  }
}