/// Transformaciones sin I/O; se aplican dentro de transacciones en la consola.
class LogicaMinuto {
  static Map<String, dynamic> actualizarEvento(
    Map<String, dynamic> partido,
    Map<String, dynamic> evento, {
    bool borrar = false,
  }) {
    final eventos = List<Map<String, dynamic>>.from(
      (partido['eventos'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final indice = eventos.indexWhere(
      (e) => e['timestamp'] == evento['timestamp'],
    );
    if ((borrar && indice < 0) || (!borrar && indice >= 0)) return {};
    final afectado = borrar ? eventos.removeAt(indice) : evento;
    if (!borrar) eventos.add(evento);
    final cambios = <String, dynamic>{'eventos': eventos};
    if (afectado['tipo'] == 'gol') {
      final campo = afectado['equipo'] == 'local'
          ? 'goles_local'
          : 'goles_visita';
      final goles = (partido[campo] as num? ?? 0).toInt() + (borrar ? -1 : 1);
      cambios[campo] = goles < 0 ? 0 : goles;
    }
    return cambios;
  }

  /// Recibe fecha_importacion convertida a DateTime por el adaptador Firestore.
  /// Rechaza resultados ambiguos antes de modificar el formulario.
  static Map<String, Map<String, dynamic>> seleccionarResultados({
    required Iterable<Map<String, dynamic>> historial,
    required String deporteId,
    required String rival,
    required DateTime fecha,
    required Iterable<String> categorias,
  }) {
    String normalizar(String valor) =>
        valor.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    if (normalizar(rival).isEmpty) {
      throw StateError('Ingresá el rival antes de traer resultados.');
    }
    final seleccion = <String, Map<String, dynamic>>{};
    for (final data in historial) {
      final dia = data['fecha_importacion'];
      final categoria = data['categoria'].toString();
      if (data['deporte_id'] != deporteId ||
          data['estado'] != 'FINALIZADO' ||
          normalizar((data['rival'] ?? '').toString()) != normalizar(rival) ||
          dia is! DateTime ||
          dia.year != fecha.year ||
          dia.month != fecha.month ||
          dia.day != fecha.day ||
          !categorias.contains(categoria)) {
        continue;
      }
      if (seleccion.containsKey(categoria)) {
        throw StateError(
          'Hay más de un partido para la categoría $categoria, rival y fecha. '
          'Cargá sus resultados manualmente para evitar mezclar partidos.',
        );
      }
      seleccion[categoria] = data;
    }
    return seleccion;
  }
}
