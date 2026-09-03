import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../servicios/servicio_firebase.dart';
import 'contexto_club.dart';
import 'servicio_datos_club.dart';

class PortalSocioException implements Exception {
  final String mensaje;

  const PortalSocioException(this.mensaje);

  @override
  String toString() => mensaje;
}

class SocioPortalEncontrado {
  final String id;
  final Map<String, dynamic> datos;
  final Map<String, dynamic>? datosPortal;

  const SocioPortalEncontrado({
    required this.id,
    required this.datos,
    this.datosPortal,
  });
}

/// Capa de datos del Portal/Carnet de socios.
///
/// HORIZONTE / generico:
/// - NO lee Firestore directamente.
/// - consume una Cloud Function pública controlada.
/// - recibe únicamente los datos mínimos del carnet.
///
/// GÜEMES y demás Legacy:
/// - conservan ServicioFirebase() sin cambios.
class ServicioPortalSocio {
  static const String _urlCarnetPublico =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'buscarCarnetPublico';

  final Map<String, dynamic>? datosPrecargados;

  ServicioPortalSocio({
    this.datosPrecargados,
  });

  bool get usaTuSedeCentral => ServicioDatosClub.usaTuSedeCentral;

  String get origenDescripcion => usaTuSedeCentral
      ? 'TuSede Central · Portal público protegido'
      : ServicioDatosClub.origenDescripcion;

  Future<SocioPortalEncontrado?> buscarSocioPorDni(String dni) async {
    final dniLimpio = dni.replaceAll(RegExp(r'[^0-9]'), '');

    if (dniLimpio.isEmpty) {
      return null;
    }

    // Legacy no cambia.
    if (!usaTuSedeCentral) {
      final query = await ServicioDatosClub.socios
          .where('dni', isEqualTo: dniLimpio)
          .limit(5)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();

        if (data['eliminado'] == true) {
          continue;
        }

        return SocioPortalEncontrado(
          id: doc.id,
          datos: Map<String, dynamic>.from(data),
        );
      }

      return null;
    }

    // TuSede Central: el cliente NO accede a clubes/{clubId}/socios.
    late http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(_urlCarnetPublico),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'clubId': ContextoClub.clubId,
              'dni': dniLimpio,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const PortalSocioException(
        'No pudimos conectar con el Portal de Socios. '
        'Revisá tu conexión e intentá nuevamente.',
      );
    }

    Map<String, dynamic> payload = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Se maneja abajo con un mensaje genérico.
    }

    final mensaje = (payload['mensaje'] ?? '').toString().trim();

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 429) {
      throw PortalSocioException(
        mensaje.isNotEmpty
            ? mensaje
            : 'Se realizaron demasiados intentos. '
                'Esperá unos minutos y volvé a probar.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw PortalSocioException(
        mensaje.isNotEmpty
            ? mensaje
            : 'No pudimos cargar el carnet en este momento.',
      );
    }

    final socioRaw = payload['socio'];
    final socioId = (payload['socioId'] ?? '').toString();

    if (socioRaw is! Map || socioId.isEmpty) {
      throw const PortalSocioException(
        'El Portal devolvió una respuesta incompleta.',
      );
    }

    final socio = Map<String, dynamic>.from(socioRaw);

    return SocioPortalEncontrado(
      id: socioId,
      datos: socio,
      datosPortal: payload,
    );
  }

  Future<Map<String, double>> obtenerPreciosCuotas() async {
    if (!usaTuSedeCentral) {
      return ServicioFirebase().obtenerPreciosCuotas();
    }

    final payload = _payloadCentral();
    final raw = payload['precios'];

    if (raw is! Map) {
      return <String, double>{};
    }

    final resultado = <String, double>{};

    raw.forEach((key, value) {
      if (value is num) {
        resultado[key.toString()] = value.toDouble();
      } else {
        final parsed = double.tryParse(value.toString());
        if (parsed != null) {
          resultado[key.toString()] = parsed;
        }
      }
    });

    return resultado;
  }

  Future<Map<String, dynamic>> obtenerConfigPagos() async {
    if (!usaTuSedeCentral) {
      return ServicioFirebase().obtenerConfigPagos();
    }

    final payload = _payloadCentral();
    final raw = payload['pagos'];

    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> obtenerGrupoFamiliar(
    String familiaId,
  ) async {
    if (!usaTuSedeCentral) {
      return ServicioFirebase().obtenerGrupoFamiliar(familiaId);
    }

    final payload = _payloadCentral();
    final raw = payload['familia'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<String> obtenerTelefonoWsp(
    Map<String, dynamic> configPagos,
  ) async {
    if (!usaTuSedeCentral) {
      return ServicioFirebase().obtenerTelefonoWsp(configPagos);
    }

    final telefono = (configPagos['telefono_wsp'] ?? '')
        .toString()
        .trim();

    if (telefono.isNotEmpty) {
      return telefono;
    }

    return '5491100000000';
  }

  Map<String, dynamic> _payloadCentral() {
    final payload = datosPrecargados;

    if (payload == null || payload['ok'] != true) {
      throw const PortalSocioException(
        'Faltan datos seguros del Portal. '
        'Volvé a ingresar tu DNI.',
      );
    }

    return payload;
  }
}
