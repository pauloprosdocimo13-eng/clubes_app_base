import '../configuracion/configuracion_app.dart';

class ServicioNotificacionesTopics {
  static String _sanitizar(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  /// En clubes Legacy conservamos exactamente el esquema histórico.
  ///
  /// En el flavor `generico`, usado hoy para Club Horizonte / TuSede,
  /// el topic queda aislado por club para evitar cruces de notificaciones
  /// entre futuros clientes.
  static String topicGeneral(ConfiguracionApp config) {
    if (config.nombreSabor == 'generico') {
      final clubId = _sanitizar(config.clubIdTuSede);
      return 'tusede_${clubId}_general';
    }

    return '${config.prefijoColeccion}_general';
  }

  static String topicPartidos(ConfiguracionApp config) {
    if (config.nombreSabor == 'generico') {
      final clubId = _sanitizar(config.clubIdTuSede);
      return 'tusede_${clubId}_partidos';
    }

    return '${config.prefijoColeccion}_partidos';
  }
}
