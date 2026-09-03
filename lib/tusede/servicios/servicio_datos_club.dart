import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'contexto_club.dart';
import 'firestore_tusede.dart';
import 'servicio_firebase_tusede.dart';

/// Decide de dónde salen los datos operativos de cada club.
///
/// ETAPA 4F-2:
/// - generico / Horizonte -> TuSede Central.
/// - Güemes y los demás flavors Legacy -> Firebase actual del club.
///
/// La lista es deliberadamente explícita para no cambiar producción
/// de ningún club por accidente.
class ServicioDatosClub {
  ServicioDatosClub._();

  static const Set<String> _clubesConDatosCentrales = <String>{
    'generico',
  };

  static bool get usaTuSedeCentral {
    return _clubesConDatosCentrales.contains(ContextoClub.clubId);
  }

  static String get origenDescripcion {
    return usaTuSedeCentral ? 'TuSede Central' : 'Firebase Legacy';
  }

  static FirebaseFirestore get firestore {
    if (usaTuSedeCentral) {
      return ServicioFirebaseTuSede.firestore;
    }

    return FirebaseFirestore.instance;
  }

  static User? get usuarioAuthActual {
    if (usaTuSedeCentral) {
      return ServicioFirebaseTuSede.auth.currentUser;
    }

    return FirebaseAuth.instance.currentUser;
  }

  static void validarAccesoOperativo() {
    if (!usaTuSedeCentral) {
      return;
    }

    if (ServicioFirebaseTuSede.auth.currentUser == null) {
      throw StateError(
        'TuSede Central requiere una sesión autenticada para acceder '
        'a los datos operativos de ${ContextoClub.nombreClub}.',
      );
    }
  }

  static CollectionReference<Map<String, dynamic>> get socios {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.socios;
    }

    return FirebaseFirestore.instance.collection('socios');
  }

  static CollectionReference<Map<String, dynamic>> get auditoriaSocios {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.coleccion('auditoria_socios');
    }

    return FirebaseFirestore.instance.collection('auditoria_socios');
  }

  static CollectionReference<Map<String, dynamic>> get movimientos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.movimientos;
    }

    return FirebaseFirestore.instance.collection('movimientos');
  }


  static CollectionReference<Map<String, dynamic>> get movimientosEliminados {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.coleccion('movimientos_eliminados');
    }

    return FirebaseFirestore.instance.collection('movimientos_eliminados');
  }

  /// Configuración operativa del club.
  ///
  /// Horizonte / generico:
  ///   clubes/generico/configuracion/{documento}
  ///
  /// Clubes Legacy:
  ///   configuracion/{documento}
  static CollectionReference<Map<String, dynamic>> get configuracion {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.configuracion;
    }

    return FirebaseFirestore.instance.collection('configuracion');
  }

  static DocumentReference<Map<String, dynamic>> configuracionDoc(
    String documentoId,
  ) {
    return configuracion.doc(documentoId);
  }

  static DocumentReference<Map<String, dynamic>> get precios {
    return configuracionDoc('precios');
  }

  static DocumentReference<Map<String, dynamic>> get pagosConfiguracion {
    return configuracionDoc('pagos');
  }

  static DocumentReference<Map<String, dynamic>> get categoriasFinanzasConfiguracion {
    return configuracionDoc('categorias_finanzas');
  }

  static DocumentReference<Map<String, dynamic>> get seguridadConfiguracion {
    return configuracionDoc('seguridad');
  }

  /// En TuSede Central los egresos no usan una contraseña compartida guardada
  /// en Firestore. Se valida el perfil central del usuario autenticado.
  ///
  /// Por ahora pueden registrar egresos:
  /// - superadmin
  /// - admin
  /// - tesoreria
  ///
  /// En clubes Legacy no cambia nada: la pantalla conserva el mecanismo
  /// histórico de clave administrativa.
  static Future<bool> usuarioCentralPuedeGestionarFinanzas() async {
    if (!usaTuSedeCentral) {
      return false;
    }

    validarAccesoOperativo();

    final user = ServicioFirebaseTuSede.auth.currentUser;
    if (user == null) {
      return false;
    }

    final snapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return false;
    }

    final data = snapshot.data()!;
    if (data['activo'] != true) {
      return false;
    }

    final rol = (data['rol'] ?? '').toString();
    const rolesAutorizados = <String>{
      'superadmin',
      'admin',
      'tesoreria',
    };

    if (!rolesAutorizados.contains(rol)) {
      return false;
    }

    if (rol == 'superadmin') {
      return true;
    }

    final clubIdsRaw = data['clubIds'];
    final clubIds = clubIdsRaw is List
        ? clubIdsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return clubIds.contains(ContextoClub.clubId);
  }
}
