/// Fechas de calendario de caja en Argentina (UTC-3).
class FechaCaja {
  static DateTime ahoraArgentina([DateTime? instante]) {
    final fecha = (instante ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 3),
    );
    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      fecha.hour,
      fecha.minute,
      fecha.second,
    );
  }

  static DateTime aUtc(DateTime calendario) => DateTime.utc(
    calendario.year,
    calendario.month,
    calendario.day,
    calendario.hour,
    calendario.minute,
    calendario.second,
  ).add(const Duration(hours: 3));
}
