import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../tusede/servicios/contexto_usuario_tusede.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../tusede/servicios/servicio_sesion_tusede.dart';

class AdminPermisos {
  static const String admin = 'admin';
  static const String tesoreria = 'tesoreria';
  static const String administracion = 'administracion';
  static const String deportes = 'deportes';
  static const String institucional = 'institucional';

  static final Map<String, List<String>> _accesos = {
    tesoreria: [
      'Caja y Finanzas',
      'Padrón Socios',
      'Escanear Ingreso',
      'Config. Precios',
      'Configurar Pagos',
      'Tienda Oficial',
      'Gestionar Rifas',
    ],
    administracion: [
      'Caja y Finanzas',
      'Padrón Socios',
      'Escanear Ingreso',
      'Agenda / Reservas',
      'Publicar Noticia',
      'Configurar Pop-up',
      'Configurar Espacios',
      'Tienda Oficial',
      'Gestionar Rifas',
      'Configuración Club',
    ],
    deportes: [
      'Tomar Asistencia',
      'Consola en VIVO',
      'Configurar Streaming',
      'Publicar Noticia',
    ],
    institucional: [
      'Publicar Noticia',
      'Votación Figura',
      'Agenda / Reservas',
      'Tienda Oficial',
    ],
  };

  // ============================================================
  // MATRIZ DE PERMISOS
  // ============================================================

  static Future<void> inicializarMatriz() async {
    try {
      final doc = await ServicioDatosClub.configuracionDoc(
        'permisos_roles',
      ).get();

      if (!doc.exists || doc.data() == null) {
        return;
      }

      final data = doc.data()!;

      data.forEach((rol, modulos) {
        if (modulos is List) {
          _accesos[rol] = modulos
              .map((modulo) => modulo.toString())
              .where((modulo) => modulo.trim().isNotEmpty)
              .toList();
        }
      });
    } catch (e) {
      debugPrint('Error cargando matriz de permisos: $e');
    }
  }

  // ============================================================
  // ROL ACTUAL
  // ============================================================

  static Future<String> obtenerRol() async {
    if (ServicioDatosClub.usaTuSedeCentral) {
      return _obtenerRolCentral();
    }

    return _obtenerRolLegacy();
  }

  static Future<String> _obtenerRolCentral() async {
    try {
      var usuario = ContextoUsuarioTuSede.usuarioActualNullable;

      usuario ??= await ServicioSesionTuSede.restaurarSesion();

      if (usuario == null) {
        return '';
      }

      final rol = usuario.rol.trim().toLowerCase();

      // El panel actual reconoce "admin" como acceso total.
      // Los roles administrativos equivalentes de TuSede
      // se normalizan al mismo comportamiento visual.
      if (rol == 'superadmin' || rol == 'admin_club') {
        return admin;
      }

      return rol;
    } catch (e) {
      debugPrint('Error obteniendo rol TuSede: $e');

      return '';
    }
  }

  static Future<String> _obtenerRolLegacy() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return '';
    }

    final email = user.email?.trim();

    if (email == null || email.isEmpty) {
      return '';
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(email)
          .get();

      if (doc.exists) {
        return (doc.data()?['rol'] ?? '').toString();
      }

      return '';
    } catch (e) {
      debugPrint('Error obteniendo rol Legacy: $e');

      return '';
    }
  }

  // ============================================================
  // VISIBILIDAD
  // ============================================================

  static bool puedeVer(String rolUsuario, String tituloMenu) {
    if (rolUsuario == admin) {
      return true;
    }

    if (rolUsuario.isEmpty) {
      return false;
    }

    final permitidos = _accesos[rolUsuario] ?? const <String>[];

    return permitidos.contains(tituloMenu);
  }
}
