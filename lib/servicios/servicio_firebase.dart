import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tusede/servicios/servicio_configuracion_publica.dart';

class ServicioFirebase {
  // Instancia única de la base de datos
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // =========================================================================
  // --- MÉTODOS ORIGINALES ---
  // =========================================================================

  // Método para obtener noticias
  Stream<QuerySnapshot> obtenerNoticias() {
    return _db
        .collection('noticias')
        .where('visible', isEqualTo: true) // Solo las visibles
        .orderBy('fecha', descending: true) // Las más nuevas primero
        .snapshots();
  }

  // =========================================================================
  // --- MÉTODOS REFACTORIZADOS PARA EL DASHBOARD DE SOCIOS ---
  // =========================================================================

  // 1. Obtener lista de precios de cuotas sociales por actividad
  Future<Map<String, double>> obtenerPreciosCuotas() async {
    Map<String, double> precios = {};
    try {
      final doc = await _db.collection('configuracion').doc('precios').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final mapPrecios = data['precios_cuotas'] ?? {};
        mapPrecios.forEach((k, v) {
          if (v is num) precios[k] = v.toDouble();
          if (v is String) precios[k] = double.tryParse(v) ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Error en obtenerPreciosCuotas: $e");
    }
    return precios;
  }

  // 2. Obtener configuración general de pagos (Alias, CBU, etc.)
  Future<Map<String, dynamic>> obtenerConfigPagos() async {
    try {
      final doc = await _db.collection('configuracion').doc('pagos').get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      debugPrint("Error en obtenerConfigPagos: $e");
    }
    return {};
  }

  // 3. Obtener teléfono de WhatsApp para reservas/pagos
  Future<String> obtenerTelefonoWsp(Map<String, dynamic> configPagos) async {
    try {
      final doc = await _db.collection('configuracion').doc('reservas').get();
      if (doc.exists) {
        final dataRes = doc.data() ?? {};
        return dataRes['telefono_wsp'] ??
            configPagos['telefono_wsp'] ??
            '5491100000000';
      }
    } catch (e) {
      debugPrint("Error en obtenerTelefonoWsp: $e");
    }
    return configPagos['telefono_wsp'] ?? '5491100000000';
  }

  // 4. Obtener datos del grupo familiar vinculado por familia_id
  Future<List<Map<String, dynamic>>> obtenerGrupoFamiliar(
    String familiaId,
  ) async {
    List<Map<String, dynamic>> familia = [];
    try {
      final query = await _db
          .collection('socios')
          .where('familia_id', isEqualTo: familiaId)
          .get();
      for (var doc in query.docs) {
        familia.add(doc.data());
      }
    } catch (e) {
      debugPrint("Error en obtenerGrupoFamiliar: $e");
    }
    return familia;
  }

  // =========================================================================
  // --- NUEVO MÉTODO PROTEGIDO PARA EL SPLASH SCREEN ---
  // =========================================================================

  Future<bool> consultarModoMultiActividad() {
    return ServicioConfiguracionPublica().consultarModoMultiActividad();
  }
}
