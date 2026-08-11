class ClubTuSede {
  final String id;
  final String nombre;
  final String slug;
  final String flavorLegacy;
  final bool activo;

  const ClubTuSede({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.flavorLegacy,
    this.activo = true,
  });

  factory ClubTuSede.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ClubTuSede(
      id: id,
      nombre: data['nombre']?.toString() ?? '',
      slug: data['slug']?.toString() ?? id,
      flavorLegacy: data['flavor_legacy']?.toString() ?? id,
      activo: data['activo'] is bool ? data['activo'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'slug': slug,
      'flavor_legacy': flavorLegacy,
      'activo': activo,
    };
  }

  ClubTuSede copyWith({
    String? id,
    String? nombre,
    String? slug,
    String? flavorLegacy,
    bool? activo,
  }) {
    return ClubTuSede(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      slug: slug ?? this.slug,
      flavorLegacy: flavorLegacy ?? this.flavorLegacy,
      activo: activo ?? this.activo,
    );
  }

  @override
  String toString() {
    return 'ClubTuSede(id: $id, nombre: $nombre, slug: $slug, activo: $activo)';
  }
}