import '../../configuracion/configuracion_app.dart';
import '../modelos/club_tusede.dart';

class ContextoClub {
  static ClubTuSede? _clubActual;

  ContextoClub._();

  // ============================================================
  // ESTADO
  // ============================================================

  static bool get estaInicializado {
    return _clubActual != null;
  }

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

  // ============================================================
  // DATOS DEL CLUB ACTUAL
  // ============================================================

  static String get clubId {
    return clubActual.id;
  }

  static String get nombreClub {
    return clubActual.nombre;
  }

  static String get flavorLegacy {
    return clubActual.flavorLegacy;
  }

  // ============================================================
  // INICIALIZACIÓN DESDE LA APP LEGACY
  // ============================================================

  static void inicializarDesdeConfiguracion(
    ConfiguracionApp configuracion,
  ) {
    final flavorLegacy =
        configuracion.nombreSabor
            .trim()
            .toLowerCase();

    // IMPORTANTE:
    //
    // Ya NO utilizamos nombreSabor para determinar
    // automáticamente el club central.
    //
    // TuSede tiene su identificador propio.

    final clubId =
        _normalizarIdClub(
      configuracion.clubIdTuSede,
    );

    _clubActual = ClubTuSede(
      id: clubId,

      nombre:
          configuracion.nombreApp,

      slug: clubId,

      flavorLegacy:
          flavorLegacy,

      activo: true,
    );
  }

  // ============================================================
  // REEMPLAZAR CON INFORMACIÓN CENTRAL
  // ============================================================
  //
  // Durante el bootstrap primero conocemos el club por la
  // configuración local.
  //
  // Luego FirestoreTuSede carga clubes/{clubId} y reemplaza
  // este objeto por los datos centrales reales.

  static void cambiarClub(
    ClubTuSede club,
  ) {
    _clubActual = club;
  }

  // ============================================================
  // LIMPIAR
  // ============================================================

  static void limpiar() {
    _clubActual = null;
  }

  // ============================================================
  // NORMALIZACIÓN
  // ============================================================

  static String _normalizarIdClub(
    String valor,
  ) {
    var resultado =
        valor.trim().toLowerCase();

    resultado = resultado
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(
          RegExp(
            r'[^a-z0-9_-]',
          ),
          '_',
        )
        .replaceAll(
          RegExp(r'_+'),
          '_',
        );

    resultado =
        resultado.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    if (resultado.isEmpty) {
      throw ArgumentError(
        'No se pudo generar un clubId '
        'válido para TuSede.',
      );
    }

    return resultado;
  }
}