import 'package:cloud_firestore/cloud_firestore.dart';

import 'contexto_club.dart';

class FirestoreTuSede {
  FirestoreTuSede._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get clubId => ContextoClub.clubId;

  static DocumentReference<Map<String, dynamic>> get clubActual {
    return _db.collection('clubes').doc(clubId);
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
  // COLECCIONES PRINCIPALES DE TUSEDE
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