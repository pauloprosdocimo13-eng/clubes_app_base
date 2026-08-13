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
    // 1. CATÁLOGO DE ROLES
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
        'No existe el catálogo de roles '
        'de TuSede.',
      );
    }

    // ==========================================================
    // 2. LEGACY
    // ==========================================================

    final legacySnapshot = await FirebaseFirestore.instance
        .collection('permisos_admin')
        .get();

    final Map<String, Map<String, dynamic>> legacy = {};

    for (final doc in legacySnapshot.docs) {
      final data = doc.data();

      String email = doc.id.trim().toLowerCase();

      if (email.isEmpty) {
        email = data['email']?.toString().trim().toLowerCase() ?? '';
      }

      if (email.isEmpty) {
        continue;
      }

      legacy[email] = {
        'nombre': data['nombre']?.toString() ?? '',
        'rol': data['rol']?.toString().trim().toLowerCase() ?? '',
      };
    }

    // ==========================================================
    // 3. USUARIOS TUSEDE
    // ==========================================================

    final centralSnapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .get();

    final Map<String, Map<String, dynamic>> central = {};

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

      final principal =
          data['clubPrincipal']?.toString().trim().toLowerCase() ?? '';

      final esSuperAdmin = rol == 'superadmin';

      final tieneAcceso =
          esSuperAdmin || clubes.contains(clubId) || principal == clubId;

      if (!tieneAcceso) {
        continue;
      }

      central[email] = {
        'uid': doc.id,
        'nombre': data['nombre']?.toString() ?? '',
        'rol': rol,
        'activo': data['activo'] == true,
        'clubIds': clubes,
        'tieneAccesoClub': tieneAcceso,
      };
    }

    // ==========================================================
    // 4. MIGRACIONES PREPARADAS
    // ==========================================================

    final migracionesSnapshot = await ServicioFirebaseTuSede.firestore
        .collection('migraciones_admin')
        .doc(clubId)
        .collection('usuarios')
        .get();

    final Map<String, Map<String, dynamic>> migraciones = {};

    for (final doc in migracionesSnapshot.docs) {
      final data = doc.data();

      final email = data['email']?.toString().trim().toLowerCase() ?? '';

      if (email.isEmpty) {
        continue;
      }

      migraciones[email] = {
        'autorizado': data['autorizado'] == true,
        'estado': data['estado']?.toString().trim().toLowerCase() ?? '',
        'rolTuSede': data['rolTuSede']?.toString().trim().toLowerCase() ?? '',
      };
    }

    // ==========================================================
    // 5. UNIFICAR
    // ==========================================================

    final emails = <String>{
      ...legacy.keys,
      ...central.keys,
      ...migraciones.keys,
    };

    final resultado = <AdminInventarioTuSede>[];

    for (final email in emails) {
      final legacyData = legacy[email];

      final centralData = central[email];

      final migracionData = migraciones[email];

      final rolLegacy =
          legacyData?['rol']?.toString().trim().toLowerCase() ?? '';

      final rolTuSede =
          centralData?['rol']?.toString().trim().toLowerCase() ?? '';

      final rolSugerido = _buscarRolSugerido(rolesCentral, rolLegacy);

      final datosRolCentral = rolTuSede.isEmpty
          ? null
          : rolesCentral[rolTuSede];

      final rolTuSedeValido =
          datosRolCentral != null && datosRolCentral['activo'] == true;

      bool rolCompatible = true;

      if (legacyData != null && centralData != null) {
        if (!rolTuSedeValido) {
          rolCompatible = false;
        } else {
          final equivalente =
              datosRolCentral!['legacyEquivalente']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

          rolCompatible = equivalente == rolLegacy;
        }
      }

      resultado.add(
        AdminInventarioTuSede(
          email: email,

          existeLegacy: legacyData != null,
          nombreLegacy: legacyData?['nombre']?.toString() ?? '',
          rolLegacy: rolLegacy,

          existeTuSede: centralData != null,
          nombreTuSede: centralData?['nombre']?.toString() ?? '',
          rolTuSede: rolTuSede,
          activoTuSede: centralData?['activo'] == true,
          clubIdsTuSede: centralData?['clubIds'] as List<String>? ?? <String>[],
          tieneAccesoClub: centralData?['tieneAccesoClub'] == true,

          rolSugeridoTuSede: rolSugerido,
          rolTuSedeValido: rolTuSedeValido,
          rolCompatibleConLegacy: rolCompatible,

          migracionPreparada: migracionData != null,

          autorizadoMigracion: migracionData?['autorizado'] == true,

          rolPreparadoTuSede: migracionData?['rolTuSede']?.toString() ?? '',

          estadoPreparacion: migracionData?['estado']?.toString() ?? '',
        ),
      );
    }

    // ==========================================================
    // ORDEN
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
  // ROL EQUIVALENTE
  // ============================================================

  static String _buscarRolSugerido(
    Map<String, Map<String, dynamic>> roles,
    String rolLegacy,
  ) {
    if (rolLegacy.isEmpty) {
      return '';
    }

    final candidatos = roles.entries.where((entry) {
      final data = entry.value;

      final activo = data['activo'] == true;

      final alcance = data['alcance']?.toString().trim().toLowerCase() ?? '';

      final equivalente =
          data['legacyEquivalente']?.toString().trim().toLowerCase() ?? '';

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
