import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'servicio_control_tusede.dart';
import 'servicio_firebase_tusede.dart';
import 'servicio_sesion_tusede.dart';

class ServicioVinculoTuSede {
  ServicioVinculoTuSede._();

  // ============================================================
  // BACKEND CENTRAL
  // ============================================================

  static const String _urlVinculacion =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'vincularSesionLegacy';

  static const Duration _timeoutBackend =
      Duration(seconds: 15);

  // ============================================================
  // LOGIN NORMAL CON EMAIL + PASSWORD
  // ============================================================

  static Future<void> intentarVincular({
    required String email,
    required String password,
  }) async {
    // ==========================================================
    // INTERRUPTOR DE EMERGENCIA
    // ==========================================================

    final activo =
        await ServicioControlTuSede.bridgeActivo();

    if (!activo) {
      _log(
        'TuSede Bridge desactivado. '
        'Se mantiene únicamente Legacy.',
      );

      return;
    }

    final correo =
        email.trim().toLowerCase();

    if (correo.isEmpty ||
        password.isEmpty) {
      return;
    }

    // ==========================================================
    // PRIMERO: BRIDGE SEGURO
    // ==========================================================

    final vinculado =
        await _intentarPuenteDesdeSesionLegacy();

    if (vinculado) {
      return;
    }

    // ==========================================================
    // RESPALDO CON CREDENCIALES
    // ==========================================================
    //
    // Se conserva durante la migración.
    //
    // Si también falla, Güemes sigue funcionando normalmente.

    await _intentarConCredenciales(
      email: correo,
      password: password,
    );
  }

  // ============================================================
  // USUARIO QUE YA TENÍA SESIÓN LEGACY
  // ============================================================

  static Future<void>
      intentarVincularSesionExistente() async {
    final activo =
        await ServicioControlTuSede.bridgeActivo();

    if (!activo) {
      _log(
        'TuSede Bridge desactivado '
        'para sesión existente.',
      );

      return;
    }

    await _intentarPuenteDesdeSesionLegacy();
  }

  // ============================================================
  // BRIDGE LEGACY -> TUSEDE
  // ============================================================

  static Future<bool>
      _intentarPuenteDesdeSesionLegacy() async {
    final usuarioLegacy =
        FirebaseAuth.instance.currentUser;

    if (usuarioLegacy == null) {
      return false;
    }

    final emailLegacy =
        (usuarioLegacy.email ?? '')
            .trim()
            .toLowerCase();

    if (emailLegacy.isEmpty) {
      return false;
    }

    try {
      // ========================================================
      // FIREBASE CENTRAL
      // ========================================================

      if (!ServicioFirebaseTuSede.estaInicializado) {
        final iniciado =
            await ServicioFirebaseTuSede.inicializar();

        if (!iniciado) {
          return false;
        }
      }

      // ========================================================
      // SESIÓN CENTRAL YA ABIERTA
      // ========================================================

      final usuarioFirebaseCentral =
          ServicioSesionTuSede
              .usuarioFirebaseActual;

      if (usuarioFirebaseCentral != null) {
        final emailCentral =
            (usuarioFirebaseCentral.email ?? '')
                .trim()
                .toLowerCase();

        if (emailCentral == emailLegacy) {
          final perfil =
              await ServicioSesionTuSede
                  .restaurarSesion();

          if (perfil != null) {
            _log(
              'TuSede: sesión central '
              'ya disponible para $emailLegacy.',
            );

            return true;
          }
        } else {
          // Computadora compartida.
          //
          // Nunca mezclamos dos identidades.

          await ServicioSesionTuSede
              .cerrarSesion();
        }
      }

      // ========================================================
      // TOKEN FIREBASE GÜEMES
      // ========================================================

      final idToken =
          await usuarioLegacy.getIdToken(true);

      if (idToken == null ||
          idToken.trim().isEmpty) {
        return false;
      }

      _log(
        'TuSede Bridge: sesión Legacy detectada '
        'para $emailLegacy.',
      );

      // ========================================================
      // BACKEND
      // ========================================================

      final response =
          await http
              .post(
                Uri.parse(
                  _urlVinculacion,
                ),
                headers: {
                  'Content-Type':
                      'application/json',
                  'Authorization':
                      'Bearer $idToken',
                },
                body: jsonEncode({
                  'clubId': 'guemes',
                }),
              )
              .timeout(
                _timeoutBackend,
              );

      Map<String, dynamic> data =
          <String, dynamic>{};

      try {
        final decoded =
            jsonDecode(
          response.body,
        );

        if (decoded is Map) {
          data =
              Map<String, dynamic>.from(
            decoded,
          );
        }
      } catch (_) {}

      if (response.statusCode != 200 ||
          data['ok'] != true) {
        final codigo =
            data['codigo']
                    ?.toString() ??
                'HTTP_${response.statusCode}';

        _log(
          'TuSede Bridge no realizado: '
          '$codigo.',
        );

        return false;
      }

      // ========================================================
      // CUSTOM TOKEN
      // ========================================================

      final customToken =
          data['customToken']
                  ?.toString()
                  .trim() ??
              '';

      if (customToken.isEmpty) {
        return false;
      }

      // ========================================================
      // SESIÓN FIREBASE TUSEDE
      // ========================================================

      final credential =
          await ServicioFirebaseTuSede.auth
              .signInWithCustomToken(
        customToken,
      );

      if (credential.user == null) {
        return false;
      }

      // ========================================================
      // PERFIL CENTRAL
      // ========================================================

      final usuarioTuSede =
          await ServicioSesionTuSede
              .restaurarSesion();

      if (usuarioTuSede == null) {
        return false;
      }

      // Seguridad extra.
      if (usuarioTuSede.email
              .trim()
              .toLowerCase() !=
          emailLegacy) {
        await ServicioSesionTuSede
            .cerrarSesion();

        return false;
      }

      _log(
        'TUSEDE BRIDGE OK - '
        '${usuarioTuSede.email} - '
        '${usuarioTuSede.rol}',
      );

      return true;
    } catch (e) {
      // ========================================================
      // FAIL-SAFE
      // ========================================================

      _log(
        'TuSede Bridge: error no bloqueante: $e',
      );

      return false;
    }
  }

  // ============================================================
  // RESPALDO CON EMAIL + PASSWORD
  // ============================================================

  static Future<void> _intentarConCredenciales({
    required String email,
    required String password,
  }) async {
    try {
      final centralActual =
          ServicioSesionTuSede
              .usuarioFirebaseActual;

      if (centralActual != null) {
        final emailCentral =
            (centralActual.email ?? '')
                .trim()
                .toLowerCase();

        if (emailCentral !=
            email.toLowerCase()) {
          await ServicioSesionTuSede
              .cerrarSesion();
        }
      }
    } catch (_) {}

    try {
      final usuario =
          await ServicioSesionTuSede
              .iniciarSesion(
        email: email,
        password: password,
      );

      _log(
        'TuSede Shadow OK - '
        '${usuario.email} - '
        '${usuario.rol}',
      );
    } on SesionTuSedeException catch (e) {
      _log(
        'TuSede Shadow no vinculado: '
        '${e.mensaje}',
      );
    } catch (e) {
      _log(
        'TuSede Shadow: '
        'error no bloqueante: $e',
      );
    }
  }

  // ============================================================
  // LOGS
  // ============================================================

  static void _log(
    String mensaje,
  ) {
    // Solo mostramos detalles durante desarrollo.
    //
    // En la versión de producción el administrador
    // no verá mensajes internos de TuSede.
    if (kDebugMode) {
      debugPrint(
        mensaje,
      );
    }
  }
}