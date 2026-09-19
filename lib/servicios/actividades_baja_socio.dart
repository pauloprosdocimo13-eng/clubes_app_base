import 'package:cloud_firestore/cloud_firestore.dart';

/// Compatibilidad con actividades múltiples y el campo Legacy `actividad`.
List<String> actividadesSocio(Map<String, dynamic> datos) {
  final valor = datos['actividades'];
  final valores = valor is List ? valor : [datos['actividad'] ?? ''];
  final actividades = <String>{};
  for (final valor in valores) {
    actividades.addAll(
      valor.toString().split(RegExp(r'[,+]')).map((a) => a.trim()),
    );
  }
  actividades.removeWhere((a) => a.isEmpty || a.toLowerCase() == 'ninguna');
  return actividades.toList();
}

List<String> actividadesAntesBaja(Map<String, dynamic> datos) =>
    datos['actividades_antes_baja'] is List
    ? actividadesSocio({'actividades': datos['actividades_antes_baja']})
    : actividadesSocio(datos);

String mesCuota(DateTime fecha) =>
    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

DateTime? _fecha(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) {
    return DateTime.tryParse(valor.length == 7 ? '$valor-01' : valor);
  }
  return null;
}

List<Map<String, dynamic>> historialBajas(Map<String, dynamic> datos) {
  final raw = datos['historial_actividades_baja'];
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
}

/// Solo incorpora la baja actual de registros antiguos que todavía no tienen
/// historial. No inventa períodos de bajas anteriores que no estén registrados.
List<Map<String, dynamic>> _historialParaRestaurar(
  Map<String, dynamic> datos,
  DateTime ahora,
) {
  final historial = historialBajas(datos);
  if (historial.isEmpty || historial.last['mes_restauracion'] != null) {
    historial.add({
      'mes_baja': mesCuota(_fecha(datos['eliminado_en']) ?? ahora),
      'actividades': actividadesAntesBaja(datos),
    });
  }
  return historial;
}

Map<String, dynamic> cambiosActividadesBaja(
  Map<String, dynamic> datos, {
  DateTime? fecha,
}) {
  final ahora = fecha ?? DateTime.now();
  final historial = historialBajas(datos);
  historial.add({
    'mes_baja': mesCuota(ahora),
    'actividades': actividadesSocio(datos),
  });
  return {
    'actividades_antes_baja': actividadesSocio(datos),
    'historial_actividades_baja': historial,
    // Guarda un punto de partida estable incluso cuando nunca hubo pagos.
    'primer_mes_cobro': mesCuota(primerMesPendiente(datos, ahora)),
    'actividades': <String>[],
    'actividad': 'Cuota Social',
  };
}

Map<String, dynamic> cambiosActividadesRestauracion(
  Map<String, dynamic> datos, {
  required bool reinscribir,
  DateTime? fecha,
}) {
  final ahora = fecha ?? DateTime.now();
  final historial = _historialParaRestaurar(datos, ahora);
  historial.last['mes_restauracion'] = mesCuota(ahora);
  final anteriores = actividadesAntesBaja(datos);
  final actividades = reinscribir ? anteriores : <String>[];
  return {
    'actividades_antes_baja': anteriores,
    'historial_actividades_baja': historial,
    'primer_mes_cobro': mesCuota(
      primerMesPendiente({
        ...datos,
        'historial_actividades_baja': historial,
      }, ahora),
    ),
    'actividades': actividades,
    'actividad': actividades.isEmpty ? 'Cuota Social' : actividades.join(', '),
  };
}

DateTime primerMesPendiente(Map<String, dynamic> datos, DateTime ahora) {
  final ultimo = _fecha(datos['ultimo_mes_pago']);
  if (ultimo != null) return DateTime(ultimo.year, ultimo.month + 1);
  final historial = historialBajas(datos);
  final inicio =
      _fecha(datos['primer_mes_cobro']) ??
      _fecha(datos['fecha_alta']) ??
      (historial.isNotEmpty ? _fecha(historial.first['mes_baja']) : null) ??
      ahora;
  return DateTime(inicio.year, inicio.month);
}

List<String> _conCuotaSiVacio(List<String> actividades) =>
    actividades.isEmpty ? ['Cuota Social'] : actividades;

/// El mes de baja ya devengado conserva sus actividades. Desde el mes
/// siguiente hasta la restauración solo se devenga Cuota Social. El historial
/// preserva también los deportes adeudados si se restaura sin reinscribir.
List<String> actividadesParaMes(Map<String, dynamic> datos, DateTime fecha) {
  final mes = mesCuota(fecha);
  var historial = historialBajas(datos);
  if (datos['eliminado'] == true && historial.isEmpty) {
    historial = _historialParaRestaurar(datos, fecha);
  }
  for (final baja in historial) {
    final mesBaja = baja['mes_baja'] as String;
    if (mes.compareTo(mesBaja) <= 0) {
      return _conCuotaSiVacio(actividadesSocio(baja));
    }
    final restauracion = baja['mes_restauracion'] as String?;
    if (restauracion == null || mes.compareTo(restauracion) < 0) {
      return ['Cuota Social'];
    }
  }
  final actuales = _conCuotaSiVacio(actividadesSocio(datos));
  // Después de una baja la Cuota Social continúa, haya o no reinscripción.
  if (historial.isNotEmpty &&
      !actuales.any((a) => a.toLowerCase() == 'cuota social')) {
    return ['Cuota Social', ...actuales];
  }
  return actuales;
}

/// Una cuota por actividad y mes, sin duplicar meses de baja/restauración.
Map<String, int> mesesPorActividad(
  Map<String, dynamic> datos,
  DateTime inicio,
  int cantidad,
) {
  final resultado = <String, int>{};
  for (var i = 0; i < cantidad; i++) {
    for (final actividad in actividadesParaMes(
      datos,
      DateTime(inicio.year, inicio.month + i),
    )) {
      resultado.update(actividad, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return resultado;
}

List<String> conceptosCobroSocio(Map<String, dynamic> datos) => {
  ..._conCuotaSiVacio(actividadesSocio(datos)),
  if (historialBajas(datos).isNotEmpty) 'Cuota Social',
  for (final baja in historialBajas(datos))
    ..._conCuotaSiVacio(actividadesSocio(baja)),
}.toList();

List<String> mesesDeActividad(
  Map<String, dynamic> datos,
  String actividad,
  DateTime inicio,
  int cantidad,
) => [
  for (var i = 0; i < cantidad; i++)
    if (actividadesParaMes(
      datos,
      DateTime(inicio.year, inicio.month + i),
    ).contains(actividad))
      mesCuota(DateTime(inicio.year, inicio.month + i)),
];
