import 'dart:convert';
import 'package:http/http.dart' as http;
import 'servicio_firebase_tusede.dart';

class ServicioPlataformaTuSede {
  static Future<Map<String, dynamic>> ejecutar(
    String accion,
    Map<String, dynamic> datos, {
    bool publico = false,
  }) async {
    final usuario = ServicioFirebaseTuSede.auth.currentUser;
    if (usuario == null && !publico) {
      throw Exception('Necesitás iniciar sesión.');
    }
    final token = publico ? null : await usuario!.getIdToken();
    final respuesta = await http
        .post(
          Uri.parse(
            'https://southamerica-east1-tu-sede-app.cloudfunctions.net/administrarPlataforma',
          ),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'accion': accion, ...datos}),
        )
        .timeout(const Duration(seconds: 60));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(respuesta.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('El servicio de plataforma no está disponible.');
    }
    if (respuesta.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudo completar la operación.');
    }
    return body;
  }
}
