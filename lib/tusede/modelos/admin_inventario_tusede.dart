enum EstadoMigracionAdmin { vinculado, soloLegacy, soloTuSede, revisar }

class AdminInventarioTuSede {
  final String email;

  // ============================================================
  // LEGACY
  // ============================================================

  final bool existeLegacy;
  final String nombreLegacy;
  final String rolLegacy;

  // ============================================================
  // TUSEDE
  // ============================================================

  final bool existeTuSede;
  final String nombreTuSede;
  final String rolTuSede;
  final bool activoTuSede;
  final List<String> clubIdsTuSede;
  final bool tieneAccesoClub;

  // ============================================================
  // VALIDACIÓN DE ROLES
  // ============================================================

  final String rolSugeridoTuSede;

  final bool rolTuSedeValido;

  final bool rolCompatibleConLegacy;

  // ============================================================
  // PREPARACIÓN DE MIGRACIÓN
  // ============================================================

  final bool migracionPreparada;

  final bool autorizadoMigracion;

  final String rolPreparadoTuSede;

  final String estadoPreparacion;

  const AdminInventarioTuSede({
    required this.email,

    required this.existeLegacy,
    required this.nombreLegacy,
    required this.rolLegacy,

    required this.existeTuSede,
    required this.nombreTuSede,
    required this.rolTuSede,
    required this.activoTuSede,
    required this.clubIdsTuSede,
    required this.tieneAccesoClub,

    required this.rolSugeridoTuSede,
    required this.rolTuSedeValido,
    required this.rolCompatibleConLegacy,

    required this.migracionPreparada,
    required this.autorizadoMigracion,
    required this.rolPreparadoTuSede,
    required this.estadoPreparacion,
  });

  // ============================================================
  // NOMBRE
  // ============================================================

  String get nombre {
    if (nombreTuSede.trim().isNotEmpty) {
      return nombreTuSede;
    }

    if (nombreLegacy.trim().isNotEmpty) {
      return nombreLegacy;
    }

    return email;
  }

  // ============================================================
  // PREPARACIÓN
  // ============================================================

  bool get preparacionValida {
    if (!migracionPreparada) {
      return false;
    }

    if (!autorizadoMigracion) {
      return false;
    }

    if (rolSugeridoTuSede.isEmpty) {
      return false;
    }

    return rolPreparadoTuSede == rolSugeridoTuSede;
  }

  bool get puedePrepararse {
    return existeLegacy &&
        !existeTuSede &&
        rolSugeridoTuSede.isNotEmpty &&
        !migracionPreparada;
  }

  // ============================================================
  // ESTADO
  // ============================================================

  EstadoMigracionAdmin get estado {
    // ----------------------------------------------------------
    // EXISTE EN AMBOS
    // ----------------------------------------------------------

    if (existeLegacy && existeTuSede) {
      if (!activoTuSede) {
        return EstadoMigracionAdmin.revisar;
      }

      if (!tieneAccesoClub) {
        return EstadoMigracionAdmin.revisar;
      }

      if (!rolTuSedeValido) {
        return EstadoMigracionAdmin.revisar;
      }

      if (!rolCompatibleConLegacy) {
        return EstadoMigracionAdmin.revisar;
      }

      return EstadoMigracionAdmin.vinculado;
    }

    // ----------------------------------------------------------
    // SOLO LEGACY
    // ----------------------------------------------------------

    if (existeLegacy && !existeTuSede) {
      if (rolSugeridoTuSede.isEmpty) {
        return EstadoMigracionAdmin.revisar;
      }

      if (migracionPreparada && !preparacionValida) {
        return EstadoMigracionAdmin.revisar;
      }

      return EstadoMigracionAdmin.soloLegacy;
    }

    // ----------------------------------------------------------
    // SOLO TUSEDE
    // ----------------------------------------------------------

    if (!existeLegacy && existeTuSede) {
      if (!activoTuSede) {
        return EstadoMigracionAdmin.revisar;
      }

      if (!tieneAccesoClub) {
        return EstadoMigracionAdmin.revisar;
      }

      if (!rolTuSedeValido) {
        return EstadoMigracionAdmin.revisar;
      }

      return EstadoMigracionAdmin.soloTuSede;
    }

    return EstadoMigracionAdmin.revisar;
  }

  // ============================================================
  // MOTIVO REVISIÓN
  // ============================================================

  String get motivoRevision {
    if (existeLegacy && !existeTuSede && rolSugeridoTuSede.isEmpty) {
      return 'No existe un rol TuSede equivalente '
          'al rol Legacy "$rolLegacy".';
    }

    if (migracionPreparada && !autorizadoMigracion) {
      return 'La migración está preparada '
          'pero no se encuentra autorizada.';
    }

    if (migracionPreparada && rolPreparadoTuSede != rolSugeridoTuSede) {
      return 'La autorización fue preparada con '
          'el rol "$rolPreparadoTuSede", pero '
          'el rol sugerido es "$rolSugeridoTuSede".';
    }

    if (existeTuSede && !activoTuSede) {
      return 'El usuario existe en TuSede '
          'pero está desactivado.';
    }

    if (existeTuSede && !tieneAccesoClub) {
      return 'El usuario existe en TuSede '
          'pero no tiene acceso al club actual.';
    }

    if (existeTuSede && !rolTuSedeValido) {
      return 'El rol "$rolTuSede" no existe '
          'en TuSede o está desactivado.';
    }

    if (existeLegacy && existeTuSede && !rolCompatibleConLegacy) {
      return 'Los roles Legacy y TuSede '
          'no son compatibles.';
    }

    return '';
  }
}
