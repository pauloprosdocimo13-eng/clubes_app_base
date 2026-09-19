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

  static const Set<String> _clubesConDatosCentrales = <String>{'generico'};

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
    if (!usaTuSedeCentral) return;

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

  static CollectionReference<Map<String, dynamic>> get asistencias {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.asistencias;
    }
    return FirebaseFirestore.instance.collection('asistencias');
  }

  /// Noticias administradas por el club.
  static CollectionReference<Map<String, dynamic>> get noticias {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.noticias;
    }
    return FirebaseFirestore.instance.collection('noticias');
  }

  /// Avisos administrados por el club.
  static CollectionReference<Map<String, dynamic>> get avisos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.avisos;
    }
    return FirebaseFirestore.instance.collection('avisos');
  }

  /// Galería administrada por el club.
  static CollectionReference<Map<String, dynamic>> get galeria {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.galeria;
    }
    return FirebaseFirestore.instance.collection('galeria');
  }

  /// Jugadores / integrantes de los planteles.
  ///
  /// Horizonte / generico: clubes/generico/jugadores
  /// Legacy: jugadores
  static CollectionReference<Map<String, dynamic>> get jugadores {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.jugadores;
    }
    return FirebaseFirestore.instance.collection('jugadores');
  }

  /// Partidos administrados por el club.
  ///
  /// Horizonte / generico: clubes/generico/partidos
  /// Legacy: partidos
  static CollectionReference<Map<String, dynamic>> get partidos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.partidos;
    }
    return FirebaseFirestore.instance.collection('partidos');
  }

  /// Historial consultado al importar resultados desde el vivo.
  static CollectionReference<Map<String, dynamic>> get historialPartidos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.coleccion('historial_partidos');
    }
    return FirebaseFirestore.instance.collection('historial_partidos');
  }

  /// Productos de la Tienda Oficial administrados por el club.
  static CollectionReference<Map<String, dynamic>> get productos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.productos;
    }
    return FirebaseFirestore.instance.collection('tienda');
  }

  static CollectionReference<Map<String, dynamic>> get espacios {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.espacios;
    }
    return FirebaseFirestore.instance.collection('espacios');
  }

  static CollectionReference<Map<String, dynamic>> get reservas {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.reservas;
    }
    return FirebaseFirestore.instance.collection('reservas');
  }

  static CollectionReference<Map<String, dynamic>> get vencimientos {
    if (usaTuSedeCentral) {
      validarAccesoOperativo();
      return FirestoreTuSede.coleccion('vencimientos');
    }
    return FirebaseFirestore.instance.collection('vencimientos');
  }

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

  static DocumentReference<Map<String, dynamic>>
  get categoriasFinanzasConfiguracion {
    return configuracionDoc('categorias_finanzas');
  }

  static DocumentReference<Map<String, dynamic>> get seguridadConfiguracion {
    return configuracionDoc('seguridad');
  }

  static DocumentReference<Map<String, dynamic>> get reservasConfiguracion {
    return configuracionDoc('reservas');
  }

  static Future<bool> usuarioCentralPuedeGestionarFinanzas() async {
    if (!usaTuSedeCentral) return false;

    validarAccesoOperativo();

    final user = ServicioFirebaseTuSede.auth.currentUser;
    if (user == null) return false;

    final snapshot = await ServicioFirebaseTuSede.firestore
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (!snapshot.exists || snapshot.data() == null) return false;

    final data = snapshot.data()!;
    if (data['activo'] != true) return false;

    final rol = (data['rol'] ?? '').toString();
    const rolesAutorizados = <String>{'superadmin', 'admin', 'tesoreria'};

    if (!rolesAutorizados.contains(rol)) return false;
    if (rol == 'superadmin') return true;

    final clubIdsRaw = data['clubIds'];
    final clubIds = clubIdsRaw is List
        ? clubIdsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return clubIds.contains(ContextoClub.clubId);
  }
}
