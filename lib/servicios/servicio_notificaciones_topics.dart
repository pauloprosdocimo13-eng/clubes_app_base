import '../configuracion/configuracion_app.dart';

class ServicioNotificacionesTopics {
  static String topicGeneral(ConfiguracionApp config) {
    if (config.nombreSabor == 'generico') return 'general';
    return '${config.prefijoColeccion}_general';
  }

  static String topicPartidos(ConfiguracionApp config) {
    if (config.nombreSabor == 'generico') return 'general_partidos';
    return '${config.prefijoColeccion}_partidos';
  }
}
