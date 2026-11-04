import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ServicioAccesosClub {
  static const canal = MethodChannel('tusede/club_shortcuts');
  static bool get esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool idValido(String? id) =>
      id != null && RegExp(r'^[a-z0-9][a-z0-9_-]{1,39}$').hasMatch(id);

  static Future<void> escuchar(void Function(String?) abrir) async {
    if (!esAndroid) return;
    void entregar(dynamic data) {
      if (data is! Map) return;
      final id = data['clubId'];
      abrir(id is String && idValido(id) ? id : null);
    }

    canal.setMethodCallHandler((call) async {
      if (call.method == 'launch') entregar(call.arguments);
    });
    try {
      entregar(await canal.invokeMethod<dynamic>('start'));
    } on MissingPluginException {
      /* Versiones anteriores del APK. */
    } on PlatformException {
      /* El catálogo sigue disponible. */
    }
  }

  static void dejarDeEscuchar() {
    if (esAndroid) canal.setMethodCallHandler(null);
  }

  static Future<bool> disponible() async {
    if (!esAndroid) return false;
    try {
      return await canal.invokeMethod<bool>('supported') == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String> agregar(Map<String, dynamic> club) async {
    if (!esAndroid || !idValido(club['id']?.toString()))
      return 'Este dispositivo no permite agregar el acceso directo.';
    final r = await canal.invokeMapMethod<String, dynamic>('pin', {
      'clubId': club['id'],
      'nombre': club['nombre'],
      'logoUrl': (club['identidad'] as Map?)?['logoUrl']?.toString() ?? '',
    });
    if (r?['estado'] == 'actualizado')
      return 'El acceso directo de este club ya existía y fue actualizado.';
    if (r?['estado'] != 'solicitado')
      return 'El teléfono no pudo solicitar el acceso directo.';
    return 'Confirmá en el teléfono para agregar el acceso directo.${r?['conEscudo'] == false ? ' Se usó el ícono de TuSede porque no se pudo cargar el escudo.' : ''}';
  }
}
