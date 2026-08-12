import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../modelos/usuario_tusede.dart';
import 'contexto_club.dart';
import 'contexto_usuario_tusede.dart';
import 'servicio_firebase_tusede.dart';

class SesionTuSedeException implements Exception {
  final String mensaje;

  const SesionTuSedeException(this.mensaje);

  @override
  String toString() {
    return mensaje;
  }
}

class ServicioSesionTuSede {
  ServicioSesionTuSede._();

  static StreamSubscription<User?>? _suscripcionSesionLegacy;

  static bool _cerrandoSesionPorSincronizacion = false;

  static FirebaseAuth get _auth {
    return ServicioFirebaseTuSede.auth;
  }

  // ============================================================
  // USUARIO FIREBASE TUSEDE
  // ============================================================

  static User? get usuarioFirebaseActual {
    if (!ServicioFirebaseTuSede.estaInicializado) {
      return null;
    }

    return _auth.currentUser;
  }

  static bool get haySesionFirebase {
    return usuarioFirebaseActual != null;
  }

  // ============================================================
  // SINCRONIZACIÓN CON FIREBASE LEGACY
  // ============================================================

  /// Durante la migración, el Firebase actual del club continúa
  /// siendo la autoridad para ingresar al panel.
  ///
  /// Si ese usuario cierra sesión, TuSede debe cerrar también
  /// su sesión secundaria para no dejar una cuenta central
  /// abierta en una computadora compartida.
  static void _activarSincronizacionConLegacy() {
    // Evitamos crear varios listeners.
    if (_suscripcionSesionLegacy != null) {
      return;
    }

    _suscripcionSesionLegacy = FirebaseAuth.instance.authStateChanges().listen((
      usuarioLegacy,
    ) async {
      if (usuarioLegacy != null) {
        return;
      }

      if (_cerrandoSesionPorSincronizacion) {
        return;
      }

      if (!ServicioFirebaseTuSede.estaInicializado) {
        ContextoUsuarioTuSede.limpiar();
        return;
      }

      final usuarioCentral = _auth.currentUser;

      if (usuarioCentral == null) {
        ContextoUsuarioTuSede.limpiar();
        return;
      }

      _cerrandoSesionPorSincronizacion = true;

      try {
        debugPrint(
          'TuSede Shadow: se detectó cierre '
          'de sesión Legacy.',
        );

        await _auth.signOut();

        ContextoUsuarioTuSede.limpiar();

        debugPrint(
          'TuSede Shadow: sesión central '
          'cerrada automáticamente.',
        );
      } catch (e) {
        debugPrint(
          'TuSede Shadow: error cerrando '
          'sesión central: $e',
        );
      } finally {
        _cerrandoSesionPorSincronizacion = false;
      }
    });
  }

  // ============================================================
  // INICIAR SESIÓN
  // ============================================================

  static Future<UsuarioTuSede> iniciarSesion({
    required String email,
    required String password,
  }) async {
    if (!ServicioFirebaseTuSede.estaInicializado) {
      final iniciado = await ServicioFirebaseTuSede.inicializar();

      if (!iniciado) {
        throw const SesionTuSedeException(
          'TuSede Central no está disponible '
          'en esta plataforma.',
        );
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const SesionTuSedeException(
          'Firebase autenticó la cuenta pero no '
          'devolvió información del usuario.',
        );
      }

      final usuario = await _cargarPerfilUsuario(firebaseUser.uid);

      _validarUsuario(usuario);

      ContextoUsuarioTuSede.establecerUsuario(usuario);

      // A partir de este momento ambas sesiones quedan
      // sincronizadas para el cierre.
      _activarSincronizacionConLegacy();

      debugPrint('===============================================');

      debugPrint('SESION TUSEDE INICIADA CORRECTAMENTE');

      debugPrint('Usuario: ${usuario.nombre}');

      debugPrint('Rol: ${usuario.rol}');

      debugPrint('Club principal: ${usuario.clubPrincipal}');

      debugPrint('Clubes permitidos: ${usuario.clubIds.join(', ')}');

      debugPrint('Superadmin: ${usuario.esSuperAdmin}');

      debugPrint('===============================================');

      return usuario;
    } on FirebaseAuthException catch (e) {
      throw SesionTuSedeException(_mensajeFirebaseAuth(e));
    } on SesionTuSedeException {
      rethrow;
    } catch (e) {
      throw SesionTuSedeException('No se pudo iniciar sesión en TuSede: $e');
    }
  }

  // ============================================================
  // RESTAURAR SESIÓN
  // ============================================================

  static Future<UsuarioTuSede?> restaurarSesion() async {
    if (!ServicioFirebaseTuSede.estaInicializado) {
      return null;
    }

    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      ContextoUsuarioTuSede.limpiar();
      return null;
    }

    try {
      final usuario = await _cargarPerfilUsuario(firebaseUser.uid);

      _validarUsuario(usuario);

      ContextoUsuarioTuSede.establecerUsuario(usuario);

      _activarSincronizacionConLegacy();

      debugPrint(
        'Sesión TuSede restaurada: '
        '${usuario.nombre} (${usuario.rol})',
      );

      return usuario;
    } catch (e) {
      await cerrarSesion();

      debugPrint('No se pudo restaurar la sesión TuSede: $e');

      return null;
    }
  }

  // ============================================================
  // CARGAR PERFIL
  // ============================================================

  static Future<UsuarioTuSede> _cargarPerfilUsuario(String uid) async {
    final snapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      throw const SesionTuSedeException(
        'La cuenta existe en Authentication, '
        'pero no tiene un perfil creado en TuSede.',
      );
    }

    final data = snapshot.data();

    if (data == null) {
      throw const SesionTuSedeException(
        'El perfil TuSede del usuario está vacío.',
      );
    }

    return UsuarioTuSede.fromMap(snapshot.id, data);
  }

  // ============================================================
  // VALIDACIONES
  // ============================================================

  static void _validarUsuario(UsuarioTuSede usuario) {
    if (!usuario.activo) {
      throw const SesionTuSedeException(
        'Tu usuario TuSede se encuentra desactivado.',
      );
    }

    final clubIdActual = ContextoClub.clubId;

    if (!usuario.tieneAccesoAClub(clubIdActual)) {
      throw SesionTuSedeException(
        'Tu usuario no tiene acceso al club '
        '"$clubIdActual".',
      );
    }
  }

  // ============================================================
  // CERRAR SESIÓN TUSEDE
  // ============================================================

  static Future<void> cerrarSesion() async {
    if (ServicioFirebaseTuSede.estaInicializado) {
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('Error cerrando sesión TuSede: $e');
      }
    }

    ContextoUsuarioTuSede.limpiar();

    debugPrint('Sesión TuSede cerrada.');
  }

  // ============================================================
  // MENSAJES DE AUTH
  // ============================================================

  static String _mensajeFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe un usuario TuSede '
            'con ese correo.';

      case 'wrong-password':
        return 'La contraseña de TuSede '
            'es incorrecta.';

      case 'invalid-credential':
        return 'El usuario o la contraseña '
            'de TuSede son incorrectos.';

      case 'invalid-email':
        return 'El correo ingresado no es válido.';

      case 'user-disabled':
        return 'Este usuario fue deshabilitado '
            'en Authentication.';

      case 'too-many-requests':
        return 'Hubo demasiados intentos. '
            'Esperá unos minutos y volvé a probar.';

      default:
        return e.message ?? 'Error de autenticación TuSede.';
    }
  }
}
