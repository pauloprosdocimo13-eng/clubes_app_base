class ClubTuSede {
  final String id;

  final String nombre;

  final String slug;

  final String flavorLegacy;

  final bool activo;

  // ============================================================
  // CONTROL TUSEDE
  // ============================================================

  final bool tusedeBridgeActivo;

  final int versionConfiguracion;

  // ============================================================
  // IDENTIDAD
  // ============================================================

  final String nombreCorto;

  final String logoUrl;

  final String colorPrimarioHex;

  final String colorSecundarioHex;

  final String lema;

  // ============================================================
  // MODULOS
  // ============================================================

  final Map<String, bool> modulos;

  const ClubTuSede({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.flavorLegacy,
    this.activo = true,
    this.tusedeBridgeActivo = false,
    this.versionConfiguracion = 1,
    this.nombreCorto = '',
    this.logoUrl = '',
    this.colorPrimarioHex = '',
    this.colorSecundarioHex = '',
    this.lema = '',
    this.modulos =
        const <String, bool>{},
  });

  // ============================================================
  // FIRESTORE -> MODELO
  // ============================================================

  factory ClubTuSede.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    // ----------------------------------------------------------
    // IDENTIDAD
    // ----------------------------------------------------------

    final identidadRaw =
        data['identidad'];

    Map<String, dynamic> identidad =
        <String, dynamic>{};

    if (identidadRaw is Map) {
      identidad =
          Map<String, dynamic>.from(
        identidadRaw,
      );
    }

    // ----------------------------------------------------------
    // MODULOS
    // ----------------------------------------------------------

    final modulosRaw =
        data['modulos'];

    final modulos =
        <String, bool>{};

    if (modulosRaw is Map) {
      for (final entry
          in modulosRaw.entries) {
        final clave =
            entry.key
                .toString()
                .trim()
                .toLowerCase();

        if (clave.isEmpty) {
          continue;
        }

        modulos[clave] =
            entry.value == true;
      }
    }

    // ----------------------------------------------------------
    // VERSION
    // ----------------------------------------------------------

    int version = 1;

    final versionRaw =
        data['versionConfiguracion'];

    if (versionRaw is int) {
      version = versionRaw;
    } else if (versionRaw is num) {
      version =
          versionRaw.toInt();
    } else {
      version =
          int.tryParse(
            versionRaw
                    ?.toString() ??
                '',
          ) ??
          1;
    }

    return ClubTuSede(
      id: id,

      nombre:
          data['nombre']
                  ?.toString()
                  .trim() ??
              '',

      slug:
          data['slug']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              id,

      flavorLegacy:
          data['flavor_legacy']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              id,

      activo:
          data['activo'] is bool
              ? data['activo'] as bool
              : true,

      tusedeBridgeActivo:
          data['tusedeBridgeActivo'] ==
              true,

      versionConfiguracion:
          version,

      nombreCorto:
          identidad['nombreCorto']
                  ?.toString()
                  .trim() ??
              '',

      logoUrl:
          identidad['logoUrl']
                  ?.toString()
                  .trim() ??
              '',

      colorPrimarioHex:
          identidad['colorPrimario']
                  ?.toString()
                  .trim() ??
              '',

      colorSecundarioHex:
          identidad['colorSecundario']
                  ?.toString()
                  .trim() ??
              '',

      lema:
          identidad['lema']
                  ?.toString()
                  .trim() ??
              '',

      modulos:
          modulos,
    );
  }

  // ============================================================
  // MODELO -> MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'slug': slug,
      'flavor_legacy':
          flavorLegacy,
      'activo': activo,
      'tusedeBridgeActivo':
          tusedeBridgeActivo,
      'versionConfiguracion':
          versionConfiguracion,

      'identidad': {
        'nombreCorto':
            nombreCorto,
        'logoUrl':
            logoUrl,
        'colorPrimario':
            colorPrimarioHex,
        'colorSecundario':
            colorSecundarioHex,
        'lema':
            lema,
      },

      'modulos':
          modulos,
    };
  }

  // ============================================================
  // MODULOS
  // ============================================================

  bool moduloActivo(
    String modulo, {
    bool valorPorDefecto = false,
  }) {
    final clave =
        modulo
            .trim()
            .toLowerCase();

    return modulos[clave] ??
        valorPorDefecto;
  }

  List<String> get modulosActivos {
    final resultado =
        modulos.entries
            .where(
              (entry) =>
                  entry.value,
            )
            .map(
              (entry) =>
                  entry.key,
            )
            .toList();

    resultado.sort();

    return resultado;
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ClubTuSede copyWith({
    String? id,
    String? nombre,
    String? slug,
    String? flavorLegacy,
    bool? activo,
    bool? tusedeBridgeActivo,
    int? versionConfiguracion,
    String? nombreCorto,
    String? logoUrl,
    String? colorPrimarioHex,
    String? colorSecundarioHex,
    String? lema,
    Map<String, bool>? modulos,
  }) {
    return ClubTuSede(
      id:
          id ?? this.id,

      nombre:
          nombre ?? this.nombre,

      slug:
          slug ?? this.slug,

      flavorLegacy:
          flavorLegacy ??
          this.flavorLegacy,

      activo:
          activo ?? this.activo,

      tusedeBridgeActivo:
          tusedeBridgeActivo ??
          this.tusedeBridgeActivo,

      versionConfiguracion:
          versionConfiguracion ??
          this.versionConfiguracion,

      nombreCorto:
          nombreCorto ??
          this.nombreCorto,

      logoUrl:
          logoUrl ??
          this.logoUrl,

      colorPrimarioHex:
          colorPrimarioHex ??
          this.colorPrimarioHex,

      colorSecundarioHex:
          colorSecundarioHex ??
          this.colorSecundarioHex,

      lema:
          lema ?? this.lema,

      modulos:
          modulos ?? this.modulos,
    );
  }

  @override
  String toString() {
    return 'ClubTuSede('
        'id: $id, '
        'nombre: $nombre, '
        'activo: $activo, '
        'version: $versionConfiguracion, '
        'modulos: ${modulosActivos.length}'
        ')';
  }
}