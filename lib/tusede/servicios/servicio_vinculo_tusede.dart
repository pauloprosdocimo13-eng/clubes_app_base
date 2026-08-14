import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'contexto_usuario_tusede.dart';
import 'servicio_firebase_tusede.dart';
import 'servicio_sesion_tusede.dart';

class ServicioVinculoTuSede {
  ServicioVinculoTuSede._();

  // ============================================================
  // BACKEND CENTRAL TUSEDE
  // ============================================================

  static const String _urlVinculacion =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'vincularSesionLegacy';

  static const Duration _timeoutBackend = Duration(seconds: 15);

  // ============================================================
  // LOGIN NORMAL
  // ============================================================
  //
  // Se ejecuta después de que Firebase Legacy de Güemes
  // YA autenticó correctamente al administrador.
  //
  // Primero intentamos utilizar el puente seguro 3F-3.
  //
  // Si todavía no puede utilizarlo, mantenemos como respaldo
  // el mecanismo con credenciales que ya teníamos funcionando.
  //
  // Ningún error TuSede bloquea el acceso Legacy.

  static Future<void> intentarVincular({
    required String email,
    required String password,
  }) async {
    final correo = email.trim().toLowerCase();

    if (correo.isEmpty || password.isEmpty) {
      return;
    }

    // ==========================================================
    // PRIMER INTENTO:
    // PUENTE SEGURO DESDE LA SESIÓN LEGACY
    // ==========================================================

    final vinculadoPorPuente = await _intentarPuenteDesdeSesionLegacy();

    if (vinculadoPorPuente) {
      return;
    }

    // ==========================================================
    // RESPALDO:
    // LOGIN CENTRAL CON LAS MISMAS CREDENCIALES
    // ==========================================================
    //
    // Esto nos sigue sirviendo, entre otros casos,
    // para el superadmin creado originalmente en TuSede.

    await _intentarConCredenciales(email: correo, password: password);
  }

  // ============================================================
  // SESIÓN LEGACY YA EXISTENTE
  // ============================================================
  //
  // Este es el método nuevo de 3F-3.
  //
  // Sirve para administradores que llevan semanas/meses
  // logueados en su teléfono o computadora.
  //
  // NO necesitamos conocer nuevamente su contraseña.

  static Future<void> intentarVincularSesionExistente() async {
    await _intentarPuenteDesdeSesionLegacy();
  }

  // ============================================================
  // PUENTE LEGACY -> TUSEDE
  // ============================================================

  static Future<bool> _intentarPuenteDesdeSesionLegacy() async {
    final usuarioLegacy = FirebaseAuth.instance.currentUser;

    if (usuarioLegacy == null) {
      debugPrint('TuSede Bridge: no existe sesión Legacy.');

      return false;
    }

    final emailLegacy = (usuarioLegacy.email ?? '').trim().toLowerCase();

    if (emailLegacy.isEmpty) {
      debugPrint(
        'TuSede Bridge: la sesión Legacy '
        'no tiene email.',
      );

      return false;
    }

    try {
      // ========================================================
      // 1. ASEGURAR FIREBASE CENTRAL
      // ========================================================

      if (!ServicioFirebaseTuSede.estaInicializado) {
        final iniciado = await ServicioFirebaseTuSede.inicializar();

        if (!iniciado) {
          debugPrint(
            'TuSede Bridge: Firebase Central '
            'no disponible.',
          );

          return false;
        }
      }

      // ========================================================
      // 2. SI YA EXISTE SESIÓN CENTRAL DE LA MISMA PERSONA
      // ========================================================

      final usuarioFirebaseCentral = ServicioSesionTuSede.usuarioFirebaseActual;

      if (usuarioFirebaseCentral != null) {
        final emailCentral = (usuarioFirebaseCentral.email ?? '')
            .trim()
            .toLowerCase();

        if (emailCentral == emailLegacy) {
          final perfilRestaurado = await ServicioSesionTuSede.restaurarSesion();

          if (perfilRestaurado != null) {
            debugPrint(
              'TuSede Bridge: usuario ya vinculado '
              'y con sesión central activa.',
            );

            return true;
          }
        } else {
          // Computadora compartida o sesión central
          // perteneciente a otra persona.
          //
          // La cerramos antes de continuar.

          debugPrint(
            'TuSede Bridge: se detectó una sesión '
            'central perteneciente a otro usuario.',
          );

          await ServicioSesionTuSede.cerrarSesion();
        }
      }

      // ========================================================
      // 3. OBTENER ID TOKEN DE GÜEMES
      // ========================================================
      //
      // Firebase genera un ID token para el usuario autenticado.
      // Lo enviamos al backend para demostrar su identidad.

      final idToken = await usuarioLegacy.getIdToken(true);

      if (idToken == null || idToken.trim().isEmpty) {
        debugPrint(
          'TuSede Bridge: no se pudo obtener '
          'el ID Token Legacy.',
        );

        return false;
      }

      debugPrint(
        'TuSede Bridge: sesión Legacy detectada '
        'para $emailLegacy.',
      );

      // ========================================================
      // 4. LLAMAR BACKEND TUSEDE
      // ========================================================

      final response = await http
          .post(
            Uri.parse(_urlVinculacion),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'clubId': 'guemes'}),
          )
          .timeout(_timeoutBackend);

      // ========================================================
      // 5. LEER RESPUESTA
      // ========================================================

      Map<String, dynamic> data = <String, dynamic>{};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Si Cloud Functions devuelve algo
        // que no sea JSON lo manejamos abajo.
      }

      if (response.statusCode != 200 || data['ok'] != true) {
        final codigo =
            data['codigo']?.toString() ?? 'HTTP_${response.statusCode}';

        final mensaje =
            data['mensaje']?.toString() ?? 'Respuesta no válida del backend.';

        debugPrint('TuSede Bridge: vinculación no realizada.');

        debugPrint('Código: $codigo');

        debugPrint('Motivo: $mensaje');

        debugPrint('El acceso Legacy continúa normalmente.');

        return false;
      }

      // ========================================================
      // 6. CUSTOM TOKEN TUSEDE
      // ========================================================

      final customToken = data['customToken']?.toString().trim() ?? '';

      if (customToken.isEmpty) {
        debugPrint(
          'TuSede Bridge: el backend respondió '
          'sin custom token.',
        );

        return false;
      }

      // ========================================================
      // 7. INICIAR SESIÓN EN FIREBASE CENTRAL
      // ========================================================
      //
      // IMPORTANTE:
      //
      // Esta es la instancia SECUNDARIA.
      // FirebaseAuth.instance sigue siendo Güemes.

      final credential = await ServicioFirebaseTuSede.auth
          .signInWithCustomToken(customToken);

      if (credential.user == null) {
        debugPrint(
          'TuSede Bridge: Firebase aceptó '
          'el custom token pero no devolvió usuario.',
        );

        return false;
      }

      // ========================================================
      // 8. RESTAURAR PERFIL CENTRAL
      // ========================================================
      //
      // El backend ya creó/verificó usuarios/{UID}.

      final usuarioTuSede = await ServicioSesionTuSede.restaurarSesion();

      if (usuarioTuSede == null) {
        debugPrint(
          'TuSede Bridge: se inició Authentication '
          'pero no se pudo restaurar el perfil.',
        );

        return false;
      }

      // ========================================================
      // 9. SEGURIDAD EXTRA:
      // MISMO EMAIL EN AMBAS SESIONES
      // ========================================================

      if (usuarioTuSede.email.trim().toLowerCase() != emailLegacy) {
        debugPrint('TuSede Bridge: conflicto de identidad.');

        await ServicioSesionTuSede.cerrarSesion();

        return false;
      }

      debugPrint('===============================================');

      debugPrint('TUSEDE BRIDGE - VINCULACION CORRECTA');

      debugPrint('Email: ${usuarioTuSede.email}');

      debugPrint('Usuario: ${usuarioTuSede.nombre}');

      debugPrint('Rol: ${usuarioTuSede.rol}');

      debugPrint('Club: ${usuarioTuSede.clubPrincipal}');

      debugPrint('Origen: SESION LEGACY EXISTENTE');

      debugPrint('===============================================');

      return true;
    } catch (e) {
      // ========================================================
      // IMPORTANTÍSIMO
      // ========================================================
      //
      // Cualquier error en el puente TuSede es NO BLOQUEANTE.
      //
      // Güemes Legacy ya había autenticado al usuario.

      debugPrint('TuSede Bridge: error no bloqueante: $e');

      debugPrint(
        'El administrador continúa '
        'utilizando Güemes normalmente.',
      );

      return false;
    }
  }

  // ============================================================
  // RESPALDO CON CREDENCIALES
  // ============================================================

  static Future<void> _intentarConCredenciales({
    required String email,
    required String password,
  }) async {
    // ==========================================================
    // LIMPIAR SESIÓN CENTRAL ANTERIOR
    // ==========================================================

    try {
      final centralActual = ServicioSesionTuSede.usuarioFirebaseActual;

      if (centralActual != null) {
        final emailCentral = (centralActual.email ?? '').trim().toLowerCase();

        if (emailCentral != email.toLowerCase()) {
          await ServicioSesionTuSede.cerrarSesion();
        }
      }
    } catch (_) {}

    // ==========================================================
    // INTENTO CENTRAL
    // ==========================================================

    try {
      final usuario = await ServicioSesionTuSede.iniciarSesion(
        email: email,
        password: password,
      );

      debugPrint('===============================================');

      debugPrint('TUSEDE SHADOW - USUARIO VINCULADO');

      debugPrint('Usuario: ${usuario.nombre}');

      debugPrint('Email: ${usuario.email}');

      debugPrint('Rol: ${usuario.rol}');

      debugPrint(
        'Club principal: '
        '${usuario.clubPrincipal}',
      );

      debugPrint(
        'IMPORTANTE: permisos siguen controlados '
        'por el sistema Legacy.',
      );

      debugPrint('===============================================');
    } on SesionTuSedeException catch (e) {
      debugPrint(
        'TuSede Shadow: usuario todavía '
        'no vinculado.',
      );

      debugPrint('Motivo: ${e.mensaje}');

      debugPrint('El acceso Legacy continúa normalmente.');
    } catch (e) {
      debugPrint(
        'TuSede Shadow: '
        'error no bloqueante: $e',
      );

      debugPrint('El acceso Legacy continúa normalmente.');
    }
  }
}
