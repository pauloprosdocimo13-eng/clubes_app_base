import 'package:cloud_firestore/cloud_firestore.dart';

class ServicioFirebase {
  // Instancia de la base de datos
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Método para obtener noticias
  Stream<QuerySnapshot> obtenerNoticias() {
    return _db
        .collection('noticias')
        .where('visible', isEqualTo: true) // Solo las visibles
        .orderBy('fecha', descending: true) // Las más nuevas primero
        .snapshots();
  }
}