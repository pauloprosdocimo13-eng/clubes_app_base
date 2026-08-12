import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/admin_inventario_tusede.dart';
import 'contexto_club.dart';
import 'contexto_usuario_tusede.dart';
import 'servicio_firebase_tusede.dart';
import 'servicio_sesion_tusede.dart';

class InventarioAdminsTuSedeException implements Exception {
  final String mensaje;

  const InventarioAdminsTuSedeException(this.mensaje);

  @override
  String toString() {
    return mensaje;
  }
}

class ServicioInventarioAdminsTuSede {
  ServicioInventarioAdminsTuSede._();

  static Future<List<AdminInventarioTuSede>> cargar() async {
    // ==========================================================
    // SEGURIDAD
    // ==========================================================

    var usuarioCentral = ContextoUsuarioTuSede.usuarioActualNullable;

    if (usuarioCentral == null) {
      usuarioCentral = await ServicioSesionTuSede.restaurarSesion();
    }

    if (usuarioCentral == null) {
      throw const InventarioAdminsTuSedeException(
        'No existe una sesión activa de TuSede.',
      );
    }

    if (!usuarioCentral.esSuperAdmin) {
      throw const InventarioAdminsTuSedeException(
        'Esta herramienta está disponible '
        'solamente para el superadministrador '
        'de TuSede.',
      );
    }

    final clubId = ContextoClub.clubId;

    // ==========================================================
    // 1. USUARIOS LEGACY DEL CLUB
    // ==========================================================

    final legacySnapshot = await FirebaseFirestore.instance
        .collection('permisos_admin')
        .get();

    final Map<String, Map<String, dynamic>> usuariosLegacy = {};

    for (final doc in legacySnapshot.docs) {
      final data = doc.data();

      String email = doc.id.trim().toLowerCase();

      if (email.isEmpty) {
        email = data['email']?.toString().trim().toLowerCase() ?? '';
      }

      if (email.isEmpty) {
        continue;
      }

      usuariosLegacy[email] = {
        'nombre': data['nombre']?.toString() ?? '',
        'rol': data['rol']?.toString() ?? '',
      };
    }

    // ==========================================================
    // 2. USUARIOS CENTRALES TUSEDE
    // ==========================================================

    final centralSnapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .get();

    final Map<String, Map<String, dynamic>> usuariosCentral = {};

    for (final doc in centralSnapshot.docs) {
      final data = doc.data();

      final email = data['email']?.toString().trim().toLowerCase() ?? '';

      if (email.isEmpty) {
        continue;
      }

      final clubesRaw = data['clubIds'];

      final List<String> clubes = clubesRaw is List
          ? clubesRaw
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList()
          : <String>[];

      final rol = data['rol']?.toString().trim().toLowerCase() ?? '';

      final clubPrincipal =
          data['clubPrincipal']?.toString().trim().toLowerCase() ?? '';

      final bool esSuperAdmin = rol == 'superadmin';

      final bool tieneAccesoClub =
          esSuperAdmin || clubes.contains(clubId) || clubPrincipal == clubId;

      // Para este inventario solamente nos interesan
      // usuarios relacionados con el club actual.
      if (!tieneAccesoClub) {
        continue;
      }

      usuariosCentral[email] = {
        'uid': doc.id,
        'nombre': data['nombre']?.toString() ?? '',
        'rol': rol,
        'activo': data['activo'] == true,
        'clubIds': clubes,
        'tieneAccesoClub': tieneAccesoClub,
      };
    }

    // ==========================================================
    // 3. UNIFICAR AMBAS FUENTES
    // ==========================================================

    final emails = <String>{...usuariosLegacy.keys, ...usuariosCentral.keys};

    final List<AdminInventarioTuSede> resultado = [];

    for (final email in emails) {
      final legacy = usuariosLegacy[email];
      final central = usuariosCentral[email];

      resultado.add(
        AdminInventarioTuSede(
          email: email,

          existeLegacy: legacy != null,
          nombreLegacy: legacy?['nombre']?.toString() ?? '',
          rolLegacy: legacy?['rol']?.toString() ?? '',

          existeTuSede: central != null,
          nombreTuSede: central?['nombre']?.toString() ?? '',
          rolTuSede: central?['rol']?.toString() ?? '',
          activoTuSede: central?['activo'] == true,
          clubIdsTuSede: central?['clubIds'] as List<String>? ?? <String>[],

          tieneAccesoClub: central?['tieneAccesoClub'] == true,
        ),
      );
    }

    // ==========================================================
    // 4. ORDEN
    // ==========================================================
    //
    // Primero mostramos lo que requiere atención.

    int prioridad(AdminInventarioTuSede admin) {
      switch (admin.estado) {
        case EstadoMigracionAdmin.soloLegacy:
          return 0;

        case EstadoMigracionAdmin.revisar:
          return 1;

        case EstadoMigracionAdmin.soloTuSede:
          return 2;

        case EstadoMigracionAdmin.vinculado:
          return 3;
      }
    }

    resultado.sort((a, b) {
      final comparacion = prioridad(a).compareTo(prioridad(b));

      if (comparacion != 0) {
        return comparacion;
      }

      return a.email.compareTo(b.email);
    });

    return resultado;
  }
}
