import '../lib/tusede/servicios/logica_minuto.dart';

void main() {
  var pruebas = 0;
  void verificar(bool condicion, String nombre) {
    if (!condicion) throw StateError('Falló: $nombre');
    pruebas++;
  }

  final gol = <String, dynamic>{
    'timestamp': 'evento-1',
    'tipo': 'gol',
    'equipo': 'local',
  };
  final inicial = <String, dynamic>{
    'eventos': <Map<String, dynamic>>[],
    'goles_local': 0,
    'goles_visita': 0,
  };
  final cambios = LogicaMinuto.actualizarEvento(inicial, gol);
  final partido = {...inicial, ...cambios};
  verificar(
    partido['goles_local'] == 1 && (partido['eventos'] as List).length == 1,
    'gol aumenta marcador y eventos',
  );
  verificar((inicial['eventos'] as List).isEmpty, 'no modifica el original');
  verificar(
    LogicaMinuto.actualizarEvento(partido, gol).isEmpty,
    'reintento no duplica gol',
  );
  final borrado = {
    ...partido,
    ...LogicaMinuto.actualizarEvento(partido, gol, borrar: true),
  };
  verificar(
    borrado['goles_local'] == 0 && (borrado['eventos'] as List).isEmpty,
    'anula gol',
  );
  verificar(
    LogicaMinuto.actualizarEvento(borrado, gol, borrar: true).isEmpty,
    'segunda anulación no descuenta',
  );
  final tarjeta = {...gol, 'timestamp': 'evento-2', 'tipo': 'roja'};
  verificar(
    !LogicaMinuto.actualizarEvento(partido, tarjeta).containsKey('goles_local'),
    'tarjeta no altera marcador',
  );
  final visita = {...gol, 'timestamp': 'evento-3', 'equipo': 'visita'};
  verificar(
    LogicaMinuto.actualizarEvento(partido, visita)['goles_visita'] == 1,
    'gol rival se cuenta separado',
  );
  verificar(
    LogicaMinuto.actualizarEvento(
          {...partido, 'goles_local': 0},
          gol,
          borrar: true,
        )['goles_local'] ==
        0,
    'no produce goles negativos',
  );
  final fecha = DateTime(2026, 9, 19);
  final valido = <String, dynamic>{
    'deporte_id': 'baby',
    'categoria': '2013',
    'rival': 'Rival Prueba',
    'estado': 'FINALIZADO',
    'fecha_importacion': fecha,
    'goles_local': 2,
  };
  Map<String, Map<String, dynamic>> seleccionar(
    List<Map<String, dynamic>> historial,
  ) => LogicaMinuto.seleccionarResultados(
    historial: historial,
    deporteId: 'baby',
    rival: ' RIVAL   PRUEBA ',
    fecha: fecha,
    categorias: ['2013', '2014'],
  );
  final elegidos = seleccionar([
    valido,
    {...valido, 'deporte_id': 'futsal'},
    {...valido, 'rival': 'Otro rival'},
    {...valido, 'estado': 'SUSPENDIDO'},
    {...valido, 'fecha_importacion': DateTime(2026, 9, 18)},
    {...valido, 'fecha_importacion': null},
    {...valido, 'categoria': '2010'},
  ]);
  verificar(
    elegidos.length == 1 && elegidos['2013']!['goles_local'] == 2,
    'filtra deporte, rival, fecha, estado y categoría',
  );
  verificar(
    seleccionar([
      {...valido, 'rival': 'Otro'},
    ]).isEmpty,
    'no inventa coincidencias',
  );
  var rechazoDuplicado = false;
  try {
    seleccionar([
      valido,
      {...valido},
    ]);
  } on StateError {
    rechazoDuplicado = true;
  }
  verificar(rechazoDuplicado, 'rechaza categoría ambigua');
  verificar(
    seleccionar([
          valido,
          {...valido, 'categoria': '2014'},
        ]).length ==
        2,
    'admite varias categorías distintas',
  );
  var rechazoVacio = false;
  try {
    LogicaMinuto.seleccionarResultados(
      historial: [valido],
      deporteId: 'baby',
      rival: '  ',
      fecha: fecha,
      categorias: ['2013'],
    );
  } on StateError {
    rechazoVacio = true;
  }
  verificar(rechazoVacio, 'requiere rival');
  print('$pruebas verificaciones de minuto a minuto correctas.');
}
