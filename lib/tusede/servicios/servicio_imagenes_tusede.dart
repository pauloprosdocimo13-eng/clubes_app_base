import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'contexto_club.dart';
import 'servicio_firebase_tusede.dart';

class ImagenTuSedeException implements Exception {
  final String mensaje;

  const ImagenTuSedeException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Sube imágenes de TuSede Central a través de un backend autenticado.
///
/// El cliente NO escribe directamente en Firebase Storage.
/// La Cloud Function valida:
/// - sesión central,
/// - usuario activo,
/// - club permitido,
/// - tamaño,
/// - extensión,
/// - carpeta.
///
/// Güemes y los flavors Legacy NO usan este servicio.
class ServicioImagenesTuSede {
  ServicioImagenesTuSede._();

  static const String _endpoint =
      'https://southamerica-east1-tu-sede-app.cloudfunctions.net/'
      'subirImagenTuSede';

  static const int _maxBytes = 4 * 1024 * 1024;

  static Future<String> subirImagen({
    required Uint8List bytes,
    required String carpeta,
    required String extension,
    String? nombreBase,
  }) async {
    if (bytes.isEmpty) {
      throw const ImagenTuSedeException(
        'La imagen seleccionada está vacía.',
      );
    }

    if (bytes.length > _maxBytes) {
      throw const ImagenTuSedeException(
        'La imagen es demasiado grande. '
        'El máximo permitido es 4 MB.',
      );
    }

    final user = ServicioFirebaseTuSede.auth.currentUser;

    if (user == null) {
      throw const ImagenTuSedeException(
        'Necesitás una sesión de administrador TuSede '
        'para subir imágenes.',
      );
    }

    final token = await user.getIdToken(true);

    if (token == null || token.isEmpty) {
      throw const ImagenTuSedeException(
        'No se pudo validar la sesión TuSede.',
      );
    }

    final ext = _normalizarExtension(extension);

    late http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'clubId': ContextoClub.clubId,
              'carpeta': carpeta,
              'extension': ext,
              'nombreBase': nombreBase ?? '',
              'imagenBase64': base64Encode(bytes),
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ImagenTuSedeException(
        'No pudimos conectar con el servidor de imágenes TuSede.',
      );
    }

    Map<String, dynamic> payload = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      throw const ImagenTuSedeException(
        'El servidor de imágenes devolvió una respuesta no válida.',
      );
    }

    final mensaje = (payload['mensaje'] ?? '').toString().trim();

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw ImagenTuSedeException(
        mensaje.isNotEmpty
            ? mensaje
            : 'No se pudo subir la imagen.',
      );
    }

    final url = (payload['url'] ?? '').toString().trim();

    if (url.isEmpty) {
      throw const ImagenTuSedeException(
        'La imagen se subió pero el servidor no devolvió su URL.',
      );
    }

    return url;
  }

  static String _normalizarExtension(String valor) {
    final ext = valor.trim().toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
