import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPermisos {
  static const String admin = 'admin';
  static const String tesoreria = 'tesoreria';
  static const String administracion = 'administracion';
  static const String deportes = 'deportes';
  static const String institucional = 'institucional';

  // Dejamos de usar "final" para poder sobreescribir esta variable con lo de Firebase
  static Map<String, List<String>> _accesos = {
    tesoreria: [
      'Caja y Finanzas',
      'Padrón Socios',
      'Escanear Ingreso',
      'Config. Precios',
      'Configurar Pagos',
      'Tienda Oficial',
      'Gestionar Rifas',
    ],
    administracion: [
      'Caja y Finanzas',
      'Padrón Socios',
      'Escanear Ingreso',
      'Agenda / Reservas',
      'Publicar Noticia',
      'Configurar Pop-up',
      'Configurar Espacios',
      'Tienda Oficial',
      'Gestionar Rifas',
      'Configuración Club',
    ],
    deportes: [
      'Tomar Asistencia',
      'Consola en VIVO',
      'Configurar Streaming',
      'Publicar Noticia',
    ],
    institucional: [
      'Publicar Noticia',
      'Votación Figura',
      'Agenda / Reservas',
      'Tienda Oficial',
    ],
  };

  // --- NUEVA FUNCIÓN: Descarga los permisos desde Firebase ---
  static Future<void> inicializarMatriz() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('permisos_roles')
          .get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data()!;
        data.forEach((rol, modulos) {
          _accesos[rol] = List<String>.from(modulos);
        });
      }
    } catch (e) {
      print("Error cargando matriz de permisos: $e");
    }
  }

  static Future<String> obtenerRol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(user.email)
          .get();

      if (doc.exists) {
        return doc.data()?['rol'] ?? '';
      }

      return '';
    } catch (e) {
      print("Error obteniendo rol: $e");
      return '';
    }
  }

  static bool puedeVer(String rolUsuario, String tituloMenu) {
    if (rolUsuario == admin) return true; // El admin ve todo siempre
    if (rolUsuario.isEmpty) return false;

    final permitidos = _accesos[rolUsuario] ?? [];
    return permitidos.contains(tituloMenu);
  }
}
