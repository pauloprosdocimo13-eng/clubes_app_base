import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'contexto_club.dart';

/// Lectura pública controlada de Noticias y Avisos de TuSede Central.
///
/// Para los clubes centrales NO abre Firestore al público.
/// Los datos se obtienen mediante la Cloud Function `contenidoPublico`.
class ServicioContenidoPublico {
  ServicioContenidoPublico._();

  static const String _endpoint =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/contenidoPublico';

  static Future<List<Map<String, dynamic>>> cargarNoticias() async {
    final respuesta = await _post({
      'accion': 'noticias',
      'clubId': ContextoClub.clubId,
    });

    return _listaDesdeRespuesta(respuesta, 'noticias');
  }

  static Future<List<Map<String, dynamic>>> cargarAvisos(
    String deporteId,
  ) async {
    final respuesta = await _post({
      'accion': 'avisos',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
    });

    return _listaDesdeRespuesta(respuesta, 'avisos');
  }

  static Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    Map<String, dynamic> data = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      throw Exception(
        'El servidor devolvió una respuesta no válida.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['mensaje'] ?? 'No se pudo cargar el contenido.').toString(),
      );
    }

    if (data['ok'] != true) {
      throw Exception(
        (data['mensaje'] ?? 'No se pudo cargar el contenido.').toString(),
      );
    }

    return data;
  }

  static List<Map<String, dynamic>> _listaDesdeRespuesta(
    Map<String, dynamic> respuesta,
    String clave,
  ) {
    final raw = respuesta[clave];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    final resultado = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final mapa = Map<String, dynamic>.from(item);

      final fechaMs = mapa.remove('fecha_ms');
      if (fechaMs is num) {
        mapa['fecha'] = Timestamp.fromMillisecondsSinceEpoch(
          fechaMs.toInt(),
        );
      }

      resultado.add(mapa);
    }

    return resultado;
  }
}
