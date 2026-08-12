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

    final clubId = ContextoClub.clubId.trim().toLowerCase();

    // ==========================================================
    // 1. CATÁLOGO CENTRAL DE ROLES
    // ==========================================================

    final rolesSnapshot = await ServicioFirebaseTuSede.firestore
        .collection('roles')
        .get();

    final Map<String, Map<String, dynamic>> rolesCentral = {};

    for (final doc in rolesSnapshot.docs) {
      final data = doc.data();

      rolesCentral[doc.id.trim().toLowerCase()] = {
        'nombre': data['nombre']?.toString() ?? '',
        'alcance': data['alcance']?.toString().trim().toLowerCase() ?? '',
        'legacyEquivalente':
            data['legacyEquivalente']?.toString().trim().toLowerCase() ?? '',
        'activo': data['activo'] == true,
        'orden': data['orden'] is num ? data['orden'] : 999,
      };
    }

    if (rolesCentral.isEmpty) {
      throw const InventarioAdminsTuSedeException(
        'No se encontró el catálogo central '
        'de roles de TuSede.',
      );
    }

    // ==========================================================
    // 2. USUARIOS LEGACY
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
        'rol': data['rol']?.toString().trim().toLowerCase() ?? '',
      };
    }

    // ==========================================================
    // 3. USUARIOS CENTRALES TUSEDE
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

      // Para este inventario solamente
      // mostramos usuarios relacionados
      // con el club actual.
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
    // 4. UNIFICAR EMAILS
    // ==========================================================

    final emails = <String>{...usuariosLegacy.keys, ...usuariosCentral.keys};

    final List<AdminInventarioTuSede> resultado = [];

    for (final email in emails) {
      final legacy = usuariosLegacy[email];

      final central = usuariosCentral[email];

      final rolLegacy = legacy?['rol']?.toString().trim().toLowerCase() ?? '';

      final rolTuSede = central?['rol']?.toString().trim().toLowerCase() ?? '';

      // ========================================================
      // ROL SUGERIDO PARA MIGRACIÓN
      // ========================================================

      final rolSugerido = _buscarRolSugerido(rolesCentral, rolLegacy);

      // ========================================================
      // VALIDAR ROL CENTRAL EXISTENTE
      // ========================================================

      final datosRolCentral = rolTuSede.isEmpty
          ? null
          : rolesCentral[rolTuSede];

      final bool rolTuSedeValido =
          datosRolCentral != null && datosRolCentral['activo'] == true;

      bool rolCompatibleConLegacy = true;

      if (legacy != null && central != null) {
        if (!rolTuSedeValido) {
          rolCompatibleConLegacy = false;
        } else {
          final equivalente =
              datosRolCentral!['legacyEquivalente']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

          rolCompatibleConLegacy = equivalente == rolLegacy;
        }
      }

      resultado.add(
        AdminInventarioTuSede(
          email: email,

          // Legacy
          existeLegacy: legacy != null,
          nombreLegacy: legacy?['nombre']?.toString() ?? '',
          rolLegacy: rolLegacy,

          // TuSede
          existeTuSede: central != null,
          nombreTuSede: central?['nombre']?.toString() ?? '',
          rolTuSede: rolTuSede,
          activoTuSede: central?['activo'] == true,
          clubIdsTuSede: central?['clubIds'] as List<String>? ?? <String>[],
          tieneAccesoClub: central?['tieneAccesoClub'] == true,

          // Validación
          rolSugeridoTuSede: rolSugerido,
          rolTuSedeValido: rolTuSedeValido,
          rolCompatibleConLegacy: rolCompatibleConLegacy,
        ),
      );
    }

    // ==========================================================
    // 5. ORDENAR
    // ==========================================================

    int prioridad(AdminInventarioTuSede admin) {
      switch (admin.estado) {
        case EstadoMigracionAdmin.revisar:
          return 0;

        case EstadoMigracionAdmin.soloLegacy:
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

  // ============================================================
  // BUSCAR ROL CENTRAL EQUIVALENTE
  // ============================================================

  static String _buscarRolSugerido(
    Map<String, Map<String, dynamic>> roles,
    String rolLegacy,
  ) {
    if (rolLegacy.trim().isEmpty) {
      return '';
    }

    final candidatos = roles.entries.where((entry) {
      final data = entry.value;

      final activo = data['activo'] == true;

      final alcance = data['alcance']?.toString().trim().toLowerCase() ?? '';

      final equivalente =
          data['legacyEquivalente']?.toString().trim().toLowerCase() ?? '';

      // IMPORTANTE:
      //
      // Cuando migramos administradores comunes
      // buscamos únicamente roles con alcance CLUB.
      //
      // De esta forma:
      //
      // Legacy ADMIN -> TuSede ADMIN
      //
      // y NO:
      //
      // Legacy ADMIN -> SUPERADMIN.
      return activo && alcance == 'club' && equivalente == rolLegacy;
    }).toList();

    if (candidatos.isEmpty) {
      return '';
    }

    candidatos.sort((a, b) {
      final ordenA = a.value['orden'] is num ? a.value['orden'] as num : 999;

      final ordenB = b.value['orden'] is num ? b.value['orden'] as num : 999;

      return ordenA.compareTo(ordenB);
    });

    return candidatos.first.key;
  }
}
