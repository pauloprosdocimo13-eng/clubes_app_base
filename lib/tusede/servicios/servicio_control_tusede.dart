import 'package:flutter/foundation.dart';

import 'contexto_club.dart';

class ServicioControlTuSede {
  ServicioControlTuSede._();

  static bool _consultado = false;

  // Valor seguro por defecto.
  //
  // Si la configuración central no pudo cargarse,
  // TuSede queda apagado y Legacy continúa normalmente.
  static bool _bridgeActivo = false;

  static bool get bridgeActivoCache {
    return _bridgeActivo;
  }

  // ============================================================
  // CONSULTAR INTERRUPTOR
  // ============================================================
  //
  // Desde 4B ya NO hacemos otra lectura a Firestore.
  //
  // app_bootstrap carga clubes/{clubId} una sola vez
  // y guarda la configuración en ContextoClub.
  //
  // Esto evita:
  // - lecturas duplicadas;
  // - esperas innecesarias;
  // - timeouts al abrir Administración.

  static Future<bool> bridgeActivo({
    bool forzarActualizacion = false,
  }) async {
    if (_consultado &&
        !forzarActualizacion) {
      return _bridgeActivo;
    }

    try {
      // ========================================================
      // CONTEXTO DISPONIBLE
      // ========================================================

      if (!ContextoClub.estaInicializado) {
        _guardarResultado(false);

        _log(
          'Control TuSede: ContextoClub no inicializado. '
          'Bridge desactivado.',
        );

        return false;
      }

      final club =
          ContextoClub.clubActual;

      // ========================================================
      // CONFIGURACIÓN YA CARGADA DESDE TUSEDE CENTRAL
      // ========================================================

      final clubActivo =
          club.activo;

      final bridgeConfigurado =
          club.tusedeBridgeActivo;

      final resultado =
          clubActivo &&
          bridgeConfigurado;

      _guardarResultado(
        resultado,
      );

      _log(
        'Control TuSede: '
        'club=${club.id}, '
        'activo=$clubActivo, '
        'bridge=$bridgeConfigurado.',
      );

      return resultado;
    } catch (e) {
      // ========================================================
      // FAIL-SAFE
      // ========================================================
      //
      // Ante cualquier error:
      // TuSede OFF.
      // Legacy sigue funcionando.

      _guardarResultado(false);

      _log(
        'Control TuSede: error no bloqueante. '
        'Bridge desactivado. $e',
      );

      return false;
    }
  }

  // ============================================================
  // CACHE
  // ============================================================

  static void _guardarResultado(
    bool activo,
  ) {
    _bridgeActivo =
        activo;

    _consultado =
        true;
  }

  static void invalidarCache() {
    _consultado =
        false;

    _bridgeActivo =
        false;
  }

  // ============================================================
  // LOG
  // ============================================================

  static void _log(
    String mensaje,
  ) {
    if (kDebugMode) {
      debugPrint(
        mensaje,
      );
    }
  }
}