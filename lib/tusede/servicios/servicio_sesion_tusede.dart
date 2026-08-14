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
  // SINCRONIZACIÓN CON LEGACY
  // ============================================================

  static void _activarSincronizacionConLegacy() {
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
      // ========================================================
      // 1. AUTHENTICATION CENTRAL
      // ========================================================

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

      // ========================================================
      // 2. PERFIL TUSEDE
      // ========================================================

      var usuario = await _buscarPerfilUsuario(firebaseUser.uid);

      // ========================================================
      // 3. AUTOALTA DESDE MIGRACIÓN PREPARADA
      // ========================================================

      if (usuario == null) {
        debugPrint(
          'TuSede: Authentication válido pero '
          'todavía no existe perfil central.',
        );

        usuario = await _crearPerfilDesdeMigracion(firebaseUser);

        debugPrint('===============================================');

        debugPrint('PERFIL TUSEDE CREADO AUTOMÁTICAMENTE');

        debugPrint('Usuario: ${usuario.nombre}');

        debugPrint('Email: ${usuario.email}');

        debugPrint('Rol: ${usuario.rol}');

        debugPrint('Club: ${usuario.clubPrincipal}');

        debugPrint('===============================================');
      }

      // ========================================================
      // 4. VALIDAR PERFIL
      // ========================================================

      _validarUsuario(usuario);

      ContextoUsuarioTuSede.establecerUsuario(usuario);

      _activarSincronizacionConLegacy();

      debugPrint('===============================================');

      debugPrint('SESION TUSEDE INICIADA CORRECTAMENTE');

      debugPrint('Usuario: ${usuario.nombre}');

      debugPrint('Rol: ${usuario.rol}');

      debugPrint('Club principal: ${usuario.clubPrincipal}');

      debugPrint(
        'Clubes permitidos: '
        '${usuario.clubIds.join(', ')}',
      );

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
  // BUSCAR PERFIL
  // ============================================================

  static Future<UsuarioTuSede?> _buscarPerfilUsuario(String uid) async {
    final snapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return UsuarioTuSede.fromMap(snapshot.id, data);
  }

  // ============================================================
  // CREAR PERFIL DESDE AUTORIZACIÓN
  // ============================================================

  static Future<UsuarioTuSede> _crearPerfilDesdeMigracion(
    User firebaseUser,
  ) async {
    final email = firebaseUser.email?.trim().toLowerCase();

    if (email == null || email.isEmpty) {
      throw const SesionTuSedeException(
        'La cuenta autenticada no tiene email.',
      );
    }

    final clubId = ContextoClub.clubId.trim().toLowerCase();

    // Coincide con el formato utilizado
    // durante 3F-1:
    //
    // diego@guemes.com
    // ->
    // diego%40guemes.com

    final idMigracion = Uri.encodeComponent(email);

    final referenciaMigracion = ServicioFirebaseTuSede.firestore
        .collection('migraciones_admin')
        .doc(clubId)
        .collection('usuarios')
        .doc(idMigracion);

    final snapshotMigracion = await referenciaMigracion.get();

    if (!snapshotMigracion.exists) {
      throw const SesionTuSedeException(
        'La cuenta existe en Authentication '
        'pero todavía no tiene una migración '
        'autorizada en TuSede.',
      );
    }

    final migracion = snapshotMigracion.data();

    if (migracion == null) {
      throw const SesionTuSedeException(
        'La autorización de migración está vacía.',
      );
    }

    final emailPreparado =
        migracion['email']?.toString().trim().toLowerCase() ?? '';

    final clubPreparado =
        migracion['clubId']?.toString().trim().toLowerCase() ?? '';

    final rol = migracion['rolTuSede']?.toString().trim().toLowerCase() ?? '';

    final nombre = migracion['nombre']?.toString().trim() ?? '';

    final autorizado = migracion['autorizado'] == true;

    final estado = migracion['estado']?.toString().trim().toLowerCase() ?? '';

    if (!autorizado) {
      throw const SesionTuSedeException(
        'La migración de esta cuenta '
        'no está autorizada.',
      );
    }

    if (estado != 'preparado') {
      throw SesionTuSedeException(
        'La migración se encuentra '
        'en estado "$estado".',
      );
    }

    if (emailPreparado != email) {
      throw const SesionTuSedeException(
        'El email de la migración '
        'no coincide con Authentication.',
      );
    }

    if (clubPreparado != clubId) {
      throw const SesionTuSedeException(
        'La migración pertenece '
        'a otro club.',
      );
    }

    if (rol.isEmpty) {
      throw const SesionTuSedeException(
        'La migración no tiene '
        'un rol TuSede asignado.',
      );
    }

    final nombreFinal = nombre.isEmpty ? email : nombre;

    final datosUsuario = <String, dynamic>{
      'nombre': nombreFinal,
      'email': email,
      'rol': rol,
      'clubPrincipal': clubId,
      'clubIds': <String>[clubId],
      'activo': true,
    };

    final referenciaUsuario = ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .doc(firebaseUser.uid);

    await referenciaUsuario.set(datosUsuario);

    return UsuarioTuSede.fromMap(firebaseUser.uid, datosUsuario);
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
      final usuario = await _buscarPerfilUsuario(firebaseUser.uid);

      // Si Authentication existe pero el perfil
      // todavía no fue creado, esperamos al próximo
      // login completo con contraseña.
      //
      // No creamos perfiles durante restauración
      // porque acá no tenemos necesidad de hacerlo.

      if (usuario == null) {
        await cerrarSesion();

        return null;
      }

      _validarUsuario(usuario);

      ContextoUsuarioTuSede.establecerUsuario(usuario);

      _activarSincronizacionConLegacy();

      debugPrint(
        'Sesión TuSede restaurada: '
        '${usuario.nombre} '
        '(${usuario.rol})',
      );

      return usuario;
    } catch (e) {
      await cerrarSesion();

      debugPrint(
        'No se pudo restaurar '
        'la sesión TuSede: $e',
      );

      return null;
    }
  }

  // ============================================================
  // VALIDACIONES
  // ============================================================

  static void _validarUsuario(UsuarioTuSede usuario) {
    if (!usuario.activo) {
      throw const SesionTuSedeException(
        'Tu usuario TuSede '
        'se encuentra desactivado.',
      );
    }

    final clubIdActual = ContextoClub.clubId;

    if (!usuario.tieneAccesoAClub(clubIdActual)) {
      throw SesionTuSedeException(
        'Tu usuario no tiene acceso '
        'al club "$clubIdActual".',
      );
    }
  }

  // ============================================================
  // CERRAR SESIÓN
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
  // MENSAJES AUTH
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
        return 'El correo ingresado '
            'no es válido.';

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
