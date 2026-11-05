import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class EntretenimientoPublicoGuemes {
  static bool get aplica =>
      ContextoClub.clubId == 'guemes' && !ServicioDatosClub.usaTuSedeCentral;
  static Future<Map<String, dynamic>> solicitar(
    Map<String, dynamic> body,
  ) async {
    final r = await http
        .post(
          Uri.parse(
            'https://southamerica-east1-club-guemes-2.cloudfunctions.net/entretenimientoGuemes',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final raw = jsonDecode(r.body);
    if (raw is! Map) throw Exception('Respuesta inválida. Intentá nuevamente.');
    if (r.statusCode != 200 || raw['ok'] != true) {
      throw Exception(raw['mensaje'] ?? 'No se pudo completar la operación.');
    }
    return Map<String, dynamic>.from(raw);
  }

  static Stream<Map<String, dynamic>> rifas({String? id}) async* {
    while (true) {
      yield await solicitar({
        'accion': 'rifas',
        if (id != null) 'sorteoId': id,
      });
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  static Future<String> token() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString('prode_token_seguro');
    if (guardado != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(guardado))
      return guardado;
    final random = Random.secure();
    final nuevo = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('prode_token_seguro', nuevo);
    return nuevo;
  }
}
