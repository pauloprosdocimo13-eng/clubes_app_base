enum EstadoMigracionAdmin { vinculado, soloLegacy, soloTuSede, revisar }

class AdminInventarioTuSede {
  final String email;

  final bool existeLegacy;
  final String nombreLegacy;
  final String rolLegacy;

  final bool existeTuSede;
  final String nombreTuSede;
  final String rolTuSede;
  final bool activoTuSede;
  final List<String> clubIdsTuSede;

  final bool tieneAccesoClub;

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
  });

  String get nombre {
    if (nombreTuSede.trim().isNotEmpty) {
      return nombreTuSede;
    }

    if (nombreLegacy.trim().isNotEmpty) {
      return nombreLegacy;
    }

    return email;
  }

  EstadoMigracionAdmin get estado {
    if (existeLegacy && existeTuSede && activoTuSede && tieneAccesoClub) {
      return EstadoMigracionAdmin.vinculado;
    }

    if (existeLegacy && !existeTuSede) {
      return EstadoMigracionAdmin.soloLegacy;
    }

    if (!existeLegacy && existeTuSede && activoTuSede && tieneAccesoClub) {
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
}
