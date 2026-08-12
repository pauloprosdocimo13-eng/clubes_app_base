import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/club_tusede.dart';
import 'contexto_club.dart';
import 'servicio_firebase_tusede.dart';

class FirestoreTuSede {
  FirestoreTuSede._();

  /// Base central de TuSede.
  ///
  /// Esta NO es la misma base Firebase que actualmente utiliza Güemes.
  static FirebaseFirestore get _db {
    return ServicioFirebaseTuSede.firestore;
  }

  static String get clubId => ContextoClub.clubId;

  /// Documento principal del club dentro de la plataforma TuSede.
  ///
  /// Ejemplo:
  /// clubes/guemes
  static DocumentReference<Map<String, dynamic>> get clubActual {
    return _db.collection('clubes').doc(clubId);
  }

  /// Lee la información general del club desde TuSede Central.
  static Future<ClubTuSede?> cargarClubActual() async {
    final snapshot = await clubActual.get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    final club = ClubTuSede.fromMap(
      snapshot.id,
      data,
    );

    ContextoClub.cambiarClub(club);

    return club;
  }

  static CollectionReference<Map<String, dynamic>> coleccion(
    String nombreColeccion,
  ) {
    return clubActual.collection(nombreColeccion);
  }

  static DocumentReference<Map<String, dynamic>> documento(
    String nombreColeccion,
    String documentoId,
  ) {
    return coleccion(nombreColeccion).doc(documentoId);
  }

  // ==========================================================
  // COLECCIONES MULTICLUB DE TUSEDE
  // ==========================================================

  static CollectionReference<Map<String, dynamic>> get socios {
    return coleccion('socios');
  }

  static CollectionReference<Map<String, dynamic>> get movimientos {
    return coleccion('movimientos');
  }

  static CollectionReference<Map<String, dynamic>> get noticias {
    return coleccion('noticias');
  }

  static CollectionReference<Map<String, dynamic>> get avisos {
    return coleccion('avisos');
  }

  static CollectionReference<Map<String, dynamic>> get partidos {
    return coleccion('partidos');
  }

  static CollectionReference<Map<String, dynamic>> get jugadores {
    return coleccion('jugadores');
  }

  static CollectionReference<Map<String, dynamic>> get actividades {
    return coleccion('actividades');
  }

  static CollectionReference<Map<String, dynamic>> get configuracion {
    return coleccion('configuracion');
  }

  static CollectionReference<Map<String, dynamic>> get pagos {
    return coleccion('pagos');
  }

  static CollectionReference<Map<String, dynamic>> get asistencias {
    return coleccion('asistencias');
  }

  static CollectionReference<Map<String, dynamic>> get espacios {
    return coleccion('espacios');
  }

  static CollectionReference<Map<String, dynamic>> get reservas {
    return coleccion('reservas');
  }

  static CollectionReference<Map<String, dynamic>> get productos {
    return coleccion('productos');
  }

  static CollectionReference<Map<String, dynamic>> get sorteos {
    return coleccion('sorteos');
  }
}