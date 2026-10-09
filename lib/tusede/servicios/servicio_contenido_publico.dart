import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'contexto_club.dart';

/// Lectura pública controlada de contenido de TuSede Central.
///
/// Los clubes centrales NO leen Firestore directamente desde las
/// pantallas públicas. Los datos se obtienen mediante la Cloud Function
/// `contenidoPublico`.
///
/// Incluye:
/// - Configuración pública
/// - Deportes / tiras
/// - Noticias
/// - Avisos
/// - Galería
/// - Tienda
/// - Planteles / jugadores
/// - Resultados
/// - Minuto a minuto
/// - Historial del minuto a minuto
class DatosTiendaPublica {
  final List<Map<String, dynamic>> productos;
  final String telefonoVentas;

  const DatosTiendaPublica({
    required this.productos,
    required this.telefonoVentas,
  });
}

class DatosConfiguracionPublica {
  final List<Map<String, dynamic>> menuDeportes;
  final Map<String, bool> modulosActivos;
  final bool activarMultiActividad;
  final Map<String, String> enlaces;
  final bool streamEnVivo;
  final String streamUrl;

  const DatosConfiguracionPublica({
    required this.menuDeportes,
    required this.modulosActivos,
    required this.activarMultiActividad,
    required this.enlaces,
    required this.streamEnVivo,
    required this.streamUrl,
  });

  bool moduloActivo(String modulo, {bool valorPorDefecto = false}) {
    return modulosActivos[modulo] ?? valorPorDefecto;
  }

  Map<String, dynamic>? deportePorId(String deporteId) {
    for (final deporte in menuDeportes) {
      if ((deporte['id'] ?? '').toString() == deporteId) {
        return deporte;
      }
    }

    return null;
  }

  List<String> categoriasDe(String deporteId) {
    final deporte = deportePorId(deporteId);

    if (deporte == null) {
      return <String>[];
    }

    final raw = deporte['categorias'];

    if (raw is! List) {
      return <String>[];
    }

    return raw
        .map((categoria) => categoria.toString().trim())
        .where((categoria) => categoria.isNotEmpty)
        .toList();
  }
}

class ServicioContenidoPublico {
  ServicioContenidoPublico._();

  static const String _endpoint =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'contenidoPublico';

  // ============================================================
  // CONFIGURACIÓN PÚBLICA
  // ============================================================

  static Future<DatosConfiguracionPublica> cargarConfiguracion() async {
    final respuesta = await _post({
      'accion': 'configuracion',
      'clubId': ContextoClub.clubId,
    });

    final menuRaw = respuesta['menu_deportes'];

    final menuDeportes = <Map<String, dynamic>>[];

    if (menuRaw is List) {
      for (final item in menuRaw) {
        if (item is Map) {
          menuDeportes.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final modulosActivos = <String, bool>{};

    final modulosRaw = respuesta['modulos_activos'];

    if (modulosRaw is Map) {
      modulosRaw.forEach((clave, valor) {
        modulosActivos[clave.toString()] = valor == true;
      });
    }

    final enlaces = <String, String>{};

    final enlacesRaw = respuesta['enlaces'];

    if (enlacesRaw is Map) {
      enlacesRaw.forEach((clave, valor) {
        final url = valor.toString().trim();

        if (url.isNotEmpty) {
          enlaces[clave.toString()] = url;
        }
      });
    }

    bool streamEnVivo = false;
    String streamUrl = '';

    final streamRaw = respuesta['stream'];

    if (streamRaw is Map) {
      streamEnVivo = streamRaw['en_vivo'] == true;

      streamUrl = (streamRaw['url'] ?? '').toString().trim();
    }

    return DatosConfiguracionPublica(
      menuDeportes: menuDeportes,
      modulosActivos: modulosActivos,
      activarMultiActividad: respuesta['activar_multi_actividad'] == true,
      enlaces: enlaces,
      streamEnVivo: streamEnVivo,
      streamUrl: streamUrl,
    );
  }

  /// Lista cerrada de documentos públicos; nunca devuelve configuración privada.
  static Future<Map<String, dynamic>> cargarConfiguracionArranque(
    String documento,
  ) async {
    final respuesta = await _post({
      'accion': 'arranque',
      'clubId': ContextoClub.clubId,
      'documento': documento,
    });
    final datos = respuesta['datos'];
    if (datos is! Map) {
      throw Exception('Configuración de arranque no válida.');
    }
    return Map<String, dynamic>.from(datos);
  }

  static Future<List<Map<String, dynamic>>> cargarPublicidad() async {
    final datos = await cargarConfiguracionArranque('publicidad');
    return _listaDesdeRespuesta(datos, 'items');
  }

  // ============================================================
  // NOTICIAS
  // ============================================================

  static Future<List<Map<String, dynamic>>> cargarNoticias() async {
    final respuesta = await _post({
      'accion': 'noticias',
      'clubId': ContextoClub.clubId,
    });

    return _listaDesdeRespuesta(respuesta, 'noticias');
  }

  // ============================================================
  // AVISOS
  // ============================================================

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

  // ============================================================
  // GALERÍA
  // ============================================================

  static Future<List<Map<String, dynamic>>> cargarGaleria(
    String deporteId,
  ) async {
    final respuesta = await _post({
      'accion': 'galeria',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
    });

    return _listaDesdeRespuesta(respuesta, 'galeria');
  }

  // ============================================================
  // TIENDA
  // ============================================================

  static Future<DatosTiendaPublica> cargarTienda() async {
    final respuesta = await _post({
      'accion': 'productos',
      'clubId': ContextoClub.clubId,
    });

    return DatosTiendaPublica(
      productos: _listaDesdeRespuesta(respuesta, 'productos'),
      telefonoVentas: (respuesta['telefono_ventas'] ?? '').toString().trim(),
    );
  }

  // ============================================================
  // PLANTELES PÚBLICOS
  // ============================================================

  static Future<List<Map<String, dynamic>>> cargarJugadores(
    String deporteId,
  ) async {
    final respuesta = await _post({
      'accion': 'jugadores',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
    });

    return _listaDesdeRespuesta(respuesta, 'jugadores');
  }

  // ============================================================
  // RESULTADOS PÚBLICOS
  // ============================================================

  static Future<List<Map<String, dynamic>>> cargarResultados(
    String deporteId, {
    String torneo = '',
  }) async {
    final respuesta = await _post({
      'accion': 'resultados',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
      'torneo': torneo,
    });

    return _listaDesdeRespuesta(respuesta, 'partidos');
  }

  // ============================================================
  // MINUTO A MINUTO PÚBLICO
  // ============================================================

  static Future<Map<String, dynamic>?> cargarVivo(String deporteId) async {
    final respuesta = await _post({
      'accion': 'vivo',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
    });

    final raw = respuesta['vivo'];

    if (raw is! Map) {
      return null;
    }

    final vivo = Map<String, dynamic>.from(raw);

    _convertirTimestamp(
      vivo,
      origen: 'inicio_tiempo_ms',
      destino: 'inicio_tiempo',
    );

    _convertirTimestamp(
      vivo,
      origen: 'inicio_partido_real_ms',
      destino: 'inicio_partido_real',
    );

    return vivo;
  }

  // ============================================================
  // HISTORIAL PÚBLICO DEL MINUTO A MINUTO
  // ============================================================

  static Future<List<Map<String, dynamic>>> cargarHistorial(
    String deporteId,
  ) async {
    final respuesta = await _post({
      'accion': 'historial',
      'clubId': ContextoClub.clubId,
      'deporteId': deporteId,
    });

    return _listaDesdeRespuesta(respuesta, 'historial');
  }

  // ============================================================
  // HTTP
  // ============================================================

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {'Content-Type': 'application/json'},
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
      throw Exception('El servidor devolvió una respuesta no válida.');
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

  // ============================================================
  // CONVERSIÓN DE LISTAS
  // ============================================================

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
      if (item is! Map) {
        continue;
      }

      final mapa = Map<String, dynamic>.from(item);

      final fechaMs = mapa.remove('fecha_ms');

      if (fechaMs is num && fechaMs > 0) {
        mapa['fecha'] = Timestamp.fromMillisecondsSinceEpoch(fechaMs.toInt());
      }

      resultado.add(mapa);
    }

    return resultado;
  }

  // ============================================================
  // TIMESTAMPS
  // ============================================================

  static void _convertirTimestamp(
    Map<String, dynamic> mapa, {
    required String origen,
    required String destino,
  }) {
    final valor = mapa.remove(origen);

    if (valor is num && valor > 0) {
      mapa[destino] = Timestamp.fromMillisecondsSinceEpoch(valor.toInt());
    }
  }
}
