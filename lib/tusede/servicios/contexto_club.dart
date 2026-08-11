import '../../configuracion/configuracion_app.dart';
import '../modelos/club_tusede.dart';

class ContextoClub {
  static ClubTuSede? _clubActual;

  ContextoClub._();

  static bool get estaInicializado => _clubActual != null;

  static ClubTuSede get clubActual {
    final club = _clubActual;

    if (club == null) {
      throw StateError(
        'ContextoClub todavía no fue inicializado. '
        'Debe inicializarse antes de utilizar datos de TuSede.',
      );
    }

    return club;
  }

  static String get clubId => clubActual.id;

  static String get nombreClub => clubActual.nombre;

  static void inicializarDesdeConfiguracion(
    ConfiguracionApp configuracion,
  ) {
    final flavor = configuracion.nombreSabor.trim().toLowerCase();

    _clubActual = ClubTuSede(
      id: _normalizarIdClub(flavor),
      nombre: configuracion.nombreApp,
      slug: _normalizarIdClub(flavor),
      flavorLegacy: flavor,
      activo: true,
    );
  }

  static void cambiarClub(ClubTuSede club) {
    _clubActual = club;
  }

  static void limpiar() {
    _clubActual = null;
  }

  static String _normalizarIdClub(String valor) {
    var resultado = valor.trim().toLowerCase();

    resultado = resultado
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    resultado = resultado.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    if (resultado.isEmpty) {
      throw ArgumentError(
        'No se pudo generar un clubId válido.',
      );
    }

    return resultado;
  }
}