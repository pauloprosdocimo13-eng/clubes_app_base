import 'package:flutter/foundation.dart';

import 'contexto_club.dart';

class ServicioModulosTuSede {
  ServicioModulosTuSede._();

  // ============================================================
  // MODULO CENTRAL
  // ============================================================
  //
  // IMPORTANTE:
  //
  // Si TuSede no pudo cargar configuración o todavía estamos
  // en una app Legacy sin configuración central completa,
  // devolvemos TRUE.
  //
  // De esta manera TuSede nunca oculta funciones del sistema
  // Legacy por un error de conexión/configuración.

  static bool activo(
    String modulo, {
    bool valorPorDefecto = true,
  }) {
    try {
      if (!ContextoClub.estaInicializado) {
        return valorPorDefecto;
      }

      final clave =
          modulo.trim().toLowerCase();

      if (clave.isEmpty) {
        return valorPorDefecto;
      }

      final modulos =
          ContextoClub.modulos;

      // Configuración central todavía no preparada.
      //
      // Conservamos comportamiento Legacy.
      if (modulos.isEmpty) {
        return valorPorDefecto;
      }

      final resultado =
          ContextoClub.moduloActivo(
        clave,
        valorPorDefecto:
            valorPorDefecto,
      );

      _log(
        'Modulo TuSede: '
        '$clave=${resultado ? "ON" : "OFF"}',
      );

      return resultado;
    } catch (e) {
      _log(
        'Modulo TuSede: error leyendo $modulo. '
        'Se conserva Legacy. $e',
      );

      return valorPorDefecto;
    }
  }

  // ============================================================
  // LEGACY + TUSEDE
  // ============================================================

  static bool disponible(
    String modulo, {
    bool legacyActivo = true,
  }) {
    if (!legacyActivo) {
      return false;
    }

    return activo(
      modulo,
      valorPorDefecto: true,
    );
  }

  // ============================================================
  // LOG
  // ============================================================

  static void _log(
    String mensaje,
  ) {
    if (kDebugMode) {
      debugPrint(mensaje);
    }
  }
}