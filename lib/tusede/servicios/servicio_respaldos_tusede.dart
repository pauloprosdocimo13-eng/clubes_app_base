import 'dart:convert';
import 'package:http/http.dart' as http;
import 'servicio_firebase_tusede.dart';

class ServicioRespaldosTuSede {
  static Future<Map<String, dynamic>> ejecutar(
    String accion,
    Map<String, dynamic> datos,
  ) async {
    final usuario = ServicioFirebaseTuSede.auth.currentUser;
    if (usuario == null) throw Exception('Iniciá sesión nuevamente.');
    final token = await usuario.getIdToken();
    final r = await http
        .post(
          Uri.parse(
            'https://southamerica-east1-tu-sede-app.cloudfunctions.net/administrarRespaldos',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'accion': accion, ...datos}),
        )
        .timeout(const Duration(seconds: 310));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'No se recibió una respuesta válida. Actualizá el listado antes de reintentar.',
      );
    }
    if (r.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se completó la operación.');
    }
    return body;
  }
}
