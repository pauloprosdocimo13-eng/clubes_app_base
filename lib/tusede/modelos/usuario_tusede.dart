class UsuarioTuSede {
  final String uid;
  final String nombre;
  final String email;
  final String rol;
  final String clubPrincipal;
  final List<String> clubIds;
  final bool activo;

  const UsuarioTuSede({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.clubPrincipal,
    required this.clubIds,
    required this.activo,
  });

  factory UsuarioTuSede.fromMap(String uid, Map<String, dynamic> data) {
    final clubesRaw = data['clubIds'];

    final List<String> clubes = clubesRaw is List
        ? clubesRaw
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList()
        : <String>[];

    return UsuarioTuSede(
      uid: uid,
      nombre: data['nombre']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      rol: data['rol']?.toString() ?? '',
      clubPrincipal: data['clubPrincipal']?.toString() ?? '',
      clubIds: clubes,
      activo: data['activo'] == true,
    );
  }

  bool get esSuperAdmin {
    return rol.toLowerCase() == 'superadmin';
  }

  bool get esAdminClub {
    return rol.toLowerCase() == 'admin_club';
  }

  bool tieneAccesoAClub(String clubId) {
    if (!activo) {
      return false;
    }

    if (esSuperAdmin) {
      return true;
    }

    return clubIds.contains(clubId);
  }

  UsuarioTuSede copyWith({
    String? uid,
    String? nombre,
    String? email,
    String? rol,
    String? clubPrincipal,
    List<String>? clubIds,
    bool? activo,
  }) {
    return UsuarioTuSede(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      clubPrincipal: clubPrincipal ?? this.clubPrincipal,
      clubIds: clubIds ?? this.clubIds,
      activo: activo ?? this.activo,
    );
  }

  @override
  String toString() {
    return 'UsuarioTuSede('
        'uid: $uid, '
        'nombre: $nombre, '
        'rol: $rol, '
        'clubPrincipal: $clubPrincipal, '
        'clubIds: $clubIds, '
        'activo: $activo'
        ')';
  }
}
