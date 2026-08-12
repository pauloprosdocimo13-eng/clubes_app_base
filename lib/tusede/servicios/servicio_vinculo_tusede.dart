import 'package:flutter/foundation.dart';

import 'servicio_sesion_tusede.dart';

class ServicioVinculoTuSede {
  ServicioVinculoTuSede._();

  /// Intenta vincular silenciosamente una sesión administrativa
  /// existente del club con TuSede Central.
  ///
  /// IMPORTANTE:
  /// Un error en TuSede JAMÁS debe impedir que el administrador
  /// continúe utilizando el sistema Legacy del club.
  static Future<void> intentarVincular({
    required String email,
    required String password,
  }) async {
    final correo = email.trim();

    if (correo.isEmpty || password.isEmpty) {
      return;
    }

    // ============================================================
    // LIMPIAMOS UNA POSIBLE SESIÓN CENTRAL ANTERIOR
    // ============================================================
    //
    // Esto evita que una computadora compartida mantenga
    // accidentalmente el contexto TuSede de otro administrador.

    try {
      await ServicioSesionTuSede.cerrarSesion();
    } catch (e) {
      debugPrint(
        'TuSede Shadow: no se pudo limpiar '
        'la sesión anterior: $e',
      );
    }

    // ============================================================
    // INTENTO SILENCIOSO DE VINCULACIÓN
    // ============================================================

    try {
      final usuario = await ServicioSesionTuSede.iniciarSesion(
        email: correo,
        password: password,
      );

      debugPrint('===============================================');

      debugPrint('TUSEDE SHADOW - USUARIO VINCULADO');

      debugPrint('Usuario: ${usuario.nombre}');

      debugPrint('Email: ${usuario.email}');

      debugPrint('Rol: ${usuario.rol}');

      debugPrint('Club principal: ${usuario.clubPrincipal}');

      debugPrint(
        'IMPORTANTE: permisos siguen controlados '
        'por el sistema Legacy.',
      );

      debugPrint('===============================================');
    } on SesionTuSedeException catch (e) {
      // Esto NO es un error para el administrador.
      //
      // Puede significar:
      // - todavía no tiene cuenta TuSede;
      // - usa otra contraseña en TuSede;
      // - no tiene perfil central;
      // - todavía no fue migrado.
      //
      // El sistema Legacy ya lo autenticó correctamente,
      // por lo que puede seguir trabajando normalmente.

      debugPrint('TuSede Shadow: usuario todavía no vinculado.');

      debugPrint('Motivo: ${e.mensaje}');

      debugPrint('El acceso Legacy continúa normalmente.');
    } catch (e) {
      // Ningún error central debe interrumpir Güemes.

      debugPrint('TuSede Shadow: error no bloqueante: $e');

      debugPrint('El acceso Legacy continúa normalmente.');
    }
  }
}
