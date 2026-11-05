/// Preferencias de cobro por concepto; no conserva importes de precios.
class DescuentosSocio {
  static const opciones = [0, 10, 20, 30, 50, 100];

  static Map<String, int> leer(dynamic valor) {
    if (valor is! Map) return {};
    final resultado = <String, int>{};
    valor.forEach((clave, porcentaje) {
      if (clave is String && porcentaje is num && opciones.contains(porcentaje)) {
        resultado[clave] = porcentaje.toInt();
      }
    });
    return resultado;
  }

  static Map<String, int> paraCobro(dynamic guardados, Iterable<String> actividades) {
    final anteriores = leer(guardados);
    return {for (final actividad in actividades) actividad.trim(): anteriores[actividad.trim()] ?? 0};
  }
}
