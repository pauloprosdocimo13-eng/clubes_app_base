import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'contexto_club.dart';
import 'servicio_datos_club.dart';

class ReservaPublicaException implements Exception {
  final String mensaje;

  const ReservaPublicaException(this.mensaje);

  @override
  String toString() => mensaje;
}

class EspacioPublico {
  final String id;
  final String titulo;
  final String descripcion;
  final String precio;
  final String fotoUrl;

  const EspacioPublico({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.precio,
    required this.fotoUrl,
  });

  factory EspacioPublico.fromMap(Map<String, dynamic> map) {
    return EspacioPublico(
      id: (map['id'] ?? '').toString(),
      titulo: (map['titulo'] ?? 'Espacio').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      precio: (map['precio'] ?? '').toString(),
      fotoUrl: (map['foto_url'] ?? '').toString(),
    );
  }
}

class PortadaReservasPublica {
  final String telefonoWsp;
  final List<EspacioPublico> espacios;

  const PortadaReservasPublica({
    required this.telefonoWsp,
    required this.espacios,
  });
}

/// Acceso público a Espacios/Reservas.
///
/// Horizonte/generico:
/// - usa Cloud Function.
/// - NO lee ni escribe las subcolecciones centrales desde Flutter.
///
/// Güemes/Legacy:
/// - conserva el comportamiento histórico actual.
class ServicioReservasPublicas {
  static const String _url =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'reservasPublicas';

  bool get usaTuSedeCentral => ServicioDatosClub.usaTuSedeCentral;

  Future<PortadaReservasPublica> cargarPortada() async {
    if (!usaTuSedeCentral) {
      final config = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('reservas')
          .get();

      final telefono = config.exists
          ? (config.data()?['telefono_wsp'] ?? '').toString()
          : '';

      final query =
          await FirebaseFirestore.instance.collection('espacios').get();

      final espacios = query.docs
          .where((doc) => doc.data()['activo'] != false)
          .map(
            (doc) => EspacioPublico.fromMap({
              'id': doc.id,
              ...doc.data(),
            }),
          )
          .toList();

      return PortadaReservasPublica(
        telefonoWsp: telefono,
        espacios: espacios,
      );
    }

    final payload = await _post({
      'accion': 'listar',
      'clubId': ContextoClub.clubId,
    });

    final raw = payload['espacios'];
    final espacios = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (item) => EspacioPublico.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <EspacioPublico>[];

    return PortadaReservasPublica(
      telefonoWsp: (payload['telefono_wsp'] ?? '').toString(),
      espacios: espacios,
    );
  }

  Future<Map<String, String>> cargarDisponibilidad({
    required String espacioId,
    required String fecha,
  }) async {
    if (!usaTuSedeCentral) {
      final query = await FirebaseFirestore.instance
          .collection('reservas')
          .where('espacio_id', isEqualTo: espacioId)
          .where('fecha', isEqualTo: fecha)
          .get();

      final resultado = <String, String>{};
      final ahora = DateTime.now();

      for (final doc in query.docs) {
        final data = doc.data();
        final hora = (data['hora'] ?? '').toString();
        final estado = (data['estado'] ?? 'confirmada').toString();

        if (hora.isEmpty) continue;

        if (estado == 'confirmada') {
          resultado[hora] = 'confirmada';
        } else if (estado == 'pendiente') {
          final creado = data['creado_el'];

          if (creado is Timestamp) {
            final minutos =
                ahora.difference(creado.toDate()).inMinutes;

            if (minutos < 30) {
              resultado[hora] = 'pendiente';
            }
          } else {
            resultado[hora] = 'pendiente';
          }
        }
      }

      return resultado;
    }

    final payload = await _post({
      'accion': 'disponibilidad',
      'clubId': ContextoClub.clubId,
      'espacioId': espacioId,
      'fecha': fecha,
    });

    final raw = payload['horarios'];
    final resultado = <String, String>{};

    if (raw is Map) {
      raw.forEach((key, value) {
        resultado[key.toString()] = value.toString();
      });
    }

    return resultado;
  }

  Future<void> reservarTurno({
    required String espacioId,
    required String espacioNombre,
    required String fecha,
    required String hora,
  }) async {
    if (!usaTuSedeCentral) {
      final check = await FirebaseFirestore.instance
          .collection('reservas')
          .where('espacio_id', isEqualTo: espacioId)
          .where('fecha', isEqualTo: fecha)
          .where('hora', isEqualTo: hora)
          .get();

      bool ocupado = false;
      final ahora = DateTime.now();

      for (final doc in check.docs) {
        final data = doc.data();
        final estado = (data['estado'] ?? 'confirmada').toString();

        if (estado == 'confirmada') {
          ocupado = true;
          break;
        }

        if (estado == 'pendiente') {
          final creado = data['creado_el'];

          if (creado is Timestamp) {
            if (ahora.difference(creado.toDate()).inMinutes < 30) {
              ocupado = true;
              break;
            }
          } else {
            ocupado = true;
            break;
          }
        }
      }

      if (ocupado) {
        throw const ReservaPublicaException(
          '¡Uy! Alguien acaba de reservar este horario.',
        );
      }

      await FirebaseFirestore.instance.collection('reservas').add({
        'espacio_id': espacioId,
        'fecha': fecha,
        'hora': hora,
        'estado': 'pendiente',
        'creado_el': FieldValue.serverTimestamp(),
        'espacio_nombre': espacioNombre,
      });

      return;
    }

    await _post({
      'accion': 'reservar',
      'clubId': ContextoClub.clubId,
      'espacioId': espacioId,
      'espacioNombre': espacioNombre,
      'fecha': fecha,
      'hora': hora,
    });
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body,
  ) async {
    late http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(_url),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ReservaPublicaException(
        'No pudimos conectar con Reservas. '
        'Revisá tu conexión e intentá nuevamente.',
      );
    }

    Map<String, dynamic> payload = {};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final mensaje = (payload['mensaje'] ?? '').toString().trim();

    if (response.statusCode == 409) {
      throw ReservaPublicaException(
        mensaje.isNotEmpty
            ? mensaje
            : 'Ese horario acaba de ocuparse.',
      );
    }

    if (response.statusCode == 429) {
      throw ReservaPublicaException(
        mensaje.isNotEmpty
            ? mensaje
            : 'Se realizaron demasiados intentos.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw ReservaPublicaException(
        mensaje.isNotEmpty
            ? mensaje
            : 'No pudimos completar la operación.',
      );
    }

    return payload;
  }
}
