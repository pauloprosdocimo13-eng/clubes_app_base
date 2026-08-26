import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'contexto_club.dart';
import 'firestore_tusede.dart';
import 'servicio_sesion_tusede.dart';

class ServicioPruebaDatosMulticlub {
  ServicioPruebaDatosMulticlub._();

  static Future<void> crearSocioPrueba() async {
    final clubId = ContextoClub.clubId;

    // ============================================================
    // BLOQUEO ABSOLUTO DE SEGURIDAD
    // ============================================================

    if (clubId != 'generico') {
      throw Exception(
        '4F: prueba bloqueada. '
        'Solo está permitido escribir en el club generico.',
      );
    }

    // ============================================================
    // EXIGIR SESIÓN CENTRAL
    // ============================================================

    final usuarioFirebase =
        ServicioSesionTuSede.usuarioFirebaseActual;

    if (usuarioFirebase == null) {
      throw Exception(
        '4F: no existe una sesión autenticada en TuSede Central.',
      );
    }

    debugPrint(
      '4F: sesión central detectada: ${usuarioFirebase.email}',
    );

    // ============================================================
    // ESCRITURA DE PRUEBA
    // ============================================================

    await FirestoreTuSede.socios.doc('prueba_001').set({
      'nombre': 'Juan',
      'apellido': 'Prueba',
      'dni': '99999999',
      'nro_socio': 'TEST-001',
      'activo': true,
      'es_prueba': true,
      'club_id': clubId,
      'creado_el': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '===============================================',
    );
    debugPrint(
      '4F-1B OK',
    );
    debugPrint(
      'Socio ficticio creado correctamente',
    );
    debugPrint(
      'Ruta: clubes/$clubId/socios/prueba_001',
    );
    debugPrint(
      'Usuario central: ${usuarioFirebase.email}',
    );
    debugPrint(
      '===============================================',
    );
  }
}