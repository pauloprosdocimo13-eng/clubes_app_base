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

  /// Rol de TuSede que corresponde al rol Legacy actual.
  ///
  /// Ejemplo:
  /// tesoreria Legacy -> tesoreria TuSede.
  final String rolSugeridoTuSede;

  /// Indica que el rol central existe en la colección /roles
  /// y se encuentra activo.
  final bool rolTuSedeValido;

  /// Indica que el rol central tiene como legacyEquivalente
  /// el mismo rol que actualmente utiliza Güemes.
  final bool rolCompatibleConLegacy;

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
  });

  // ============================================================
  // NOMBRE PARA MOSTRAR
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
  // ESTADO DE MIGRACIÓN
  // ============================================================

  EstadoMigracionAdmin get estado {
    // ----------------------------------------------------------
    // EXISTE EN AMBOS SISTEMAS
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
      // Si ni siquiera encontramos un rol equivalente
      // no conviene migrar todavía.
      if (rolSugeridoTuSede.isEmpty) {
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

  bool get estaVinculado {
    return estado == EstadoMigracionAdmin.vinculado;
  }

  bool get pendienteMigracion {
    return estado == EstadoMigracionAdmin.soloLegacy;
  }

  // ============================================================
  // MOTIVO PARA REVISAR
  // ============================================================

  String get motivoRevision {
    if (existeLegacy && !existeTuSede && rolSugeridoTuSede.isEmpty) {
      return 'No existe en TuSede un rol equivalente '
          'al rol Legacy "$rolLegacy".';
    }

    if (existeTuSede && !activoTuSede) {
      return 'El usuario existe en TuSede pero está desactivado.';
    }

    if (existeTuSede && !tieneAccesoClub) {
      return 'El usuario existe en TuSede pero no tiene '
          'acceso al club actual.';
    }

    if (existeTuSede && !rolTuSedeValido) {
      return 'El rol "$rolTuSede" no existe en el catálogo '
          'de roles de TuSede o está desactivado.';
    }

    if (existeLegacy && existeTuSede && !rolCompatibleConLegacy) {
      final sugerido = rolSugeridoTuSede.isEmpty
          ? 'sin equivalente'
          : rolSugeridoTuSede;

      return 'Los roles no coinciden. '
          'Legacy: "$rolLegacy". '
          'TuSede: "$rolTuSede". '
          'Sugerido: "$sugerido".';
    }

    return '';
  }
}
