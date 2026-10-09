import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'servicio_contenido_publico.dart';
import 'servicio_datos_club.dart';

/// Configuración de arranque sin acceder a Legacy para un club Central.
class ServicioConfiguracionPublica {
  final Future<Map<String, dynamic>> Function(String) _leerLegacy;
  final Future<Map<String, dynamic>> Function(String) _leerCentral;

  ServicioConfiguracionPublica({
    Future<Map<String, dynamic>> Function(String)? leerLegacy,
    Future<Map<String, dynamic>> Function(String)? leerCentral,
  }) : _leerLegacy = leerLegacy ?? _cargarLegacy,
       _leerCentral =
           leerCentral ?? ServicioContenidoPublico.cargarConfiguracionArranque;

  static Future<Map<String, dynamic>> _cargarLegacy(String documento) async {
    final doc = await FirebaseFirestore.instance
        .collection('configuracion')
        .doc(documento)
        .get();
    return doc.data() ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cargarDocumento(String documento) {
    return ServicioDatosClub.usaTuSedeCentral
        ? _leerCentral(documento)
        : _leerLegacy(documento);
  }

  Future<bool> consultarModoMultiActividad({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      if (ServicioDatosClub.usaTuSedeCentral) {
        // Este campo ya está disponible en la función pública desplegada.
        final datos = await ServicioContenidoPublico.cargarConfiguracion()
            .timeout(timeout);
        return datos.activarMultiActividad;
      }
      final datos = await cargarDocumento('general').timeout(timeout);
      return datos['activar_multi_actividad'] == true;
    } catch (e) {
      debugPrint('No se pudo consultar el modo de arranque: $e');
      return false;
    }
  }
}
