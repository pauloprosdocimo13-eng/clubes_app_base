import 'package:flutter/foundation.dart';

import 'contexto_club.dart';
import 'servicio_firebase_tusede.dart';

class ServicioControlTuSede {
  ServicioControlTuSede._();

  static bool _consultado = false;

  // IMPORTANTE:
  //
  // El valor seguro por defecto es FALSE.
  //
  // Si Firebase TuSede no responde, no hay Internet,
  // existe un error de configuración o cualquier otra
  // situación inesperada, el Bridge simplemente no funciona.
  //
  // Güemes Legacy continúa normalmente.
  static bool _bridgeActivo = false;

  static bool get bridgeActivoCache {
    return _bridgeActivo;
  }

  // ============================================================
  // CONSULTAR INTERRUPTOR
  // ============================================================

  static Future<bool> bridgeActivo({
    bool forzarActualizacion = false,
  }) async {
    if (_consultado && !forzarActualizacion) {
      return _bridgeActivo;
    }

    try {
      // ========================================================
      // FIREBASE CENTRAL
      // ========================================================

      if (!ServicioFirebaseTuSede.estaInicializado) {
        final iniciado =
            await ServicioFirebaseTuSede.inicializar();

        if (!iniciado) {
          _guardarResultado(false);

          _log(
            'Control TuSede: Firebase Central no disponible. '
            'Bridge desactivado.',
          );

          return false;
        }
      }

      // ========================================================
      // LEER CONFIGURACIÓN DEL CLUB
      // ========================================================

      final clubId =
          ContextoClub.clubId.trim().toLowerCase();

      final snapshot =
          await ServicioFirebaseTuSede.firestore
              .collection('clubes')
              .doc(clubId)
              .get()
              .timeout(
                const Duration(seconds: 5),
              );

      if (!snapshot.exists) {
        _guardarResultado(false);

        _log(
          'Control TuSede: no existe clubes/$clubId. '
          'Bridge desactivado.',
        );

        return false;
      }

      final data = snapshot.data();

      if (data == null) {
        _guardarResultado(false);

        return false;
      }

      // El club además debe estar activo.
      final clubActivo =
          data['activo'] == true;

      final bridge =
          data['tusedeBridgeActivo'] == true;

      final resultado =
          clubActivo && bridge;

      _guardarResultado(
        resultado,
      );

      _log(
        'Control TuSede: '
        'club=$clubId, '
        'activo=$clubActivo, '
        'bridge=$bridge.',
      );

      return resultado;
    } catch (e) {
      // ========================================================
      // FAIL-SAFE
      // ========================================================
      //
      // Cualquier error significa:
      //
      // NO ejecutar TuSede.
      //
      // Nunca significa impedir el acceso a Güemes.

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
    _bridgeActivo = activo;
    _consultado = true;
  }

  static void invalidarCache() {
    _consultado = false;
    _bridgeActivo = false;
  }

  // ============================================================
  // LOGS
  // ============================================================

  static void _log(
    String mensaje,
  ) {
    // En producción evitamos llenar la consola.
    if (kDebugMode) {
      debugPrint(
        mensaje,
      );
    }
  }
}