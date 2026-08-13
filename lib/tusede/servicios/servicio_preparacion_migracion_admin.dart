import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/admin_inventario_tusede.dart';
import 'contexto_club.dart';
import 'contexto_usuario_tusede.dart';
import 'servicio_firebase_tusede.dart';
import 'servicio_sesion_tusede.dart';

class PreparacionMigracionAdminException implements Exception {
  final String mensaje;

  const PreparacionMigracionAdminException(this.mensaje);

  @override
  String toString() {
    return mensaje;
  }
}

class ServicioPreparacionMigracionAdmin {
  ServicioPreparacionMigracionAdmin._();

  // ============================================================
  // PREPARAR MIGRACIÓN
  // ============================================================

  static Future<void> preparar(AdminInventarioTuSede admin) async {
    // ==========================================================
    // 1. VERIFICAR SUPERADMIN
    // ==========================================================

    var usuario = ContextoUsuarioTuSede.usuarioActualNullable;

    if (usuario == null) {
      usuario = await ServicioSesionTuSede.restaurarSesion();
    }

    if (usuario == null) {
      throw const PreparacionMigracionAdminException(
        'No existe una sesión activa de TuSede.',
      );
    }

    if (!usuario.esSuperAdmin) {
      throw const PreparacionMigracionAdminException(
        'Solamente el superadministrador de TuSede '
        'puede preparar migraciones.',
      );
    }

    // ==========================================================
    // 2. VALIDAR ADMINISTRADOR
    // ==========================================================

    if (!admin.existeLegacy) {
      throw const PreparacionMigracionAdminException(
        'Este usuario no existe en el sistema Legacy.',
      );
    }

    if (admin.existeTuSede) {
      throw const PreparacionMigracionAdminException(
        'Este usuario ya existe en TuSede.',
      );
    }

    if (admin.rolSugeridoTuSede.trim().isEmpty) {
      throw const PreparacionMigracionAdminException(
        'No existe un rol TuSede equivalente '
        'para este administrador.',
      );
    }

    final clubId = ContextoClub.clubId.trim().toLowerCase();

    final email = admin.email.trim().toLowerCase();

    final rolLegacy = admin.rolLegacy.trim().toLowerCase();

    final rolTuSede = admin.rolSugeridoTuSede.trim().toLowerCase();

    // ==========================================================
    // 3. VALIDAR CATÁLOGO DE ROLES
    // ==========================================================

    final rolSnapshot = await ServicioFirebaseTuSede.firestore
        .collection('roles')
        .doc(rolTuSede)
        .get();

    if (!rolSnapshot.exists) {
      throw PreparacionMigracionAdminException(
        'El rol "$rolTuSede" no existe '
        'en el catálogo central.',
      );
    }

    final datosRol = rolSnapshot.data();

    if (datosRol == null) {
      throw const PreparacionMigracionAdminException(
        'El documento del rol está vacío.',
      );
    }

    final activo = datosRol['activo'] == true;

    final alcance = datosRol['alcance']?.toString().trim().toLowerCase() ?? '';

    final equivalente =
        datosRol['legacyEquivalente']?.toString().trim().toLowerCase() ?? '';

    if (!activo) {
      throw PreparacionMigracionAdminException(
        'El rol "$rolTuSede" está desactivado.',
      );
    }

    if (alcance != 'club') {
      throw PreparacionMigracionAdminException(
        'El rol "$rolTuSede" no es un rol de club.',
      );
    }

    if (equivalente != rolLegacy) {
      throw PreparacionMigracionAdminException(
        'El rol "$rolTuSede" no corresponde '
        'al rol Legacy "$rolLegacy".',
      );
    }

    // ==========================================================
    // 4. CREAR AUTORIZACIÓN
    // ==========================================================
    //
    // Usamos encodeComponent para evitar caracteres especiales
    // problemáticos en el ID del documento.

    final idDocumento = Uri.encodeComponent(email);

    final referencia = ServicioFirebaseTuSede.firestore
        .collection('migraciones_admin')
        .doc(clubId)
        .collection('usuarios')
        .doc(idDocumento);

    await referencia.set({
      'email': email,
      'nombre': admin.nombre,
      'clubId': clubId,

      'rolLegacy': rolLegacy,
      'rolTuSede': rolTuSede,

      'autorizado': true,
      'estado': 'preparado',

      'origen': 'legacy',
      'version': 1,

      'preparadoPor': usuario.uid,

      'fechaPreparacion': FieldValue.serverTimestamp(),

      'actualizadoEl': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
