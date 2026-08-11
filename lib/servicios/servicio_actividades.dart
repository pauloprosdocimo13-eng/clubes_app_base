import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActividadClub {
  final String nombre;
  final String horarios;
  final String arancel;
  final String icono;
  final String colorHex;
  final bool esFutbol;

  const ActividadClub({
    required this.nombre,
    required this.horarios,
    required this.arancel,
    this.icono = 'fitness_center',
    this.colorHex = '#607D8B',
    this.esFutbol = false,
  });

  factory ActividadClub.fromMap(Map<String, dynamic> data) {
    return ActividadClub(
      nombre: data['nombre']?.toString() ?? '',
      horarios: data['horarios']?.toString() ?? 'Consultar horarios',
      arancel: data['arancel']?.toString() ?? 'Consultar arancel',
      icono: data['icono']?.toString() ?? 'fitness_center',
      colorHex: data['color']?.toString() ?? '#607D8B',
      esFutbol: data['es_futbol'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'horarios': horarios,
        'arancel': arancel,
        'icono': icono,
        'color': colorHex,
        'es_futbol': esFutbol,
      };

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  IconData get iconData => ServicioActividades.iconoDesdeNombre(icono);
}

class ContactoClub {
  final String titulo;
  final String subtitulo;
  final String url;
  final String icono;
  final String colorHex;

  const ContactoClub({
    required this.titulo,
    required this.subtitulo,
    required this.url,
    this.icono = 'link',
    this.colorHex = '#607D8B',
  });

  factory ContactoClub.fromMap(Map<String, dynamic> data) {
    return ContactoClub(
      titulo: data['titulo']?.toString() ?? '',
      subtitulo: data['subtitulo']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      icono: data['icono']?.toString() ?? 'link',
      colorHex: data['color']?.toString() ?? '#607D8B',
    );
  }

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'subtitulo': subtitulo,
        'url': url,
        'icono': icono,
        'color': colorHex,
      };

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  IconData get iconData => ServicioActividades.iconoDesdeNombre(icono);
}

class ServicioActividades {
  static const actividadesPorDefecto = [
    ActividadClub(
      nombre: 'FÚTBOL',
      horarios: 'Martes, Jueves y Viernes desde las 18 hs.',
      arancel: r'$30.000.-',
      icono: 'sports_soccer',
      colorHex: '#1565C0',
      esFutbol: true,
    ),
    ActividadClub(
      nombre: 'PATÍN ARTÍSTICO',
      horarios: 'Lunes y Miércoles de 17:00 a 21:30 hs',
      arancel: 'Desde \$30.000.-',
      icono: 'ice_skating',
      colorHex: '#D81B60',
    ),
    ActividadClub(
      nombre: 'TAEKWONDO',
      horarios: 'Martes y Jueves de 18:30 a 21:30 hs.',
      arancel: r'$30.000.-',
      icono: 'sports_martial_arts',
      colorHex: '#EF6C00',
    ),
  ];

  static const contactosPorDefecto = [
    ContactoClub(
      titulo: 'WhatsApp Secretaría',
      subtitulo: '11-5814-4690',
      url: 'https://wa.me/5491158144690',
      icono: 'phone',
      colorHex: '#43A047',
    ),
    ContactoClub(
      titulo: 'Instagram',
      subtitulo: '@martinguemesclub',
      url: 'https://www.instagram.com/martinguemesclub',
      icono: 'camera_alt',
      colorHex: '#EC407A',
    ),
    ContactoClub(
      titulo: 'Facebook',
      subtitulo: 'Club Martín Güemes',
      url: 'https://www.facebook.com/martinguemesclub',
      icono: 'facebook',
      colorHex: '#1E88E5',
    ),
  ];

  static IconData iconoDesdeNombre(String nombre) {
    switch (nombre) {
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'ice_skating':
        return Icons.ice_skating;
      case 'sports_martial_arts':
        return Icons.sports_martial_arts;
      case 'speaker':
        return Icons.speaker;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'sports_mma':
        return Icons.sports_mma;
      case 'palette':
        return Icons.palette;
      case 'elderly':
        return Icons.elderly;
      case 'psychology':
        return Icons.psychology;
      case 'music_note':
        return Icons.music_note;
      case 'directions_run':
        return Icons.directions_run;
      case 'local_florist':
        return Icons.local_florist;
      case 'cut':
        return Icons.cut;
      case 'phone':
        return Icons.phone;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      case 'play_arrow':
        return Icons.play_arrow;
      default:
        return Icons.star;
    }
  }

  static List<String> nombresIconosDisponibles() => [
        'sports_soccer',
        'ice_skating',
        'sports_martial_arts',
        'speaker',
        'fitness_center',
        'self_improvement',
        'sports_mma',
        'palette',
        'elderly',
        'psychology',
        'music_note',
        'directions_run',
        'local_florist',
        'cut',
        'phone',
        'camera_alt',
        'facebook',
        'play_arrow',
        'star',
      ];

  static Future<List<ActividadClub>> cargarActividades() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('actividades')
          .get();

      if (doc.exists && doc.data() != null) {
        final items = doc.data()!['items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          return items
              .map((e) => ActividadClub.fromMap(Map<String, dynamic>.from(e as Map)))
              .where((a) => a.nombre.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error cargando actividades: $e');
    }
    return actividadesPorDefecto;
  }

  static Future<List<ContactoClub>> cargarContactos() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('contacto')
          .get();

      if (doc.exists && doc.data() != null) {
        final items = doc.data()!['items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          return items
              .map((e) => ContactoClub.fromMap(Map<String, dynamic>.from(e as Map)))
              .where((c) => c.titulo.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error cargando contactos: $e');
    }
    return contactosPorDefecto;
  }

  static Future<void> guardarActividades(List<ActividadClub> actividades) async {
    await FirebaseFirestore.instance.collection('configuracion').doc('actividades').set({
      'items': actividades.map((a) => a.toMap()).toList(),
      'actualizado_en': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> guardarContactos(List<ContactoClub> contactos) async {
    await FirebaseFirestore.instance.collection('configuracion').doc('contacto').set({
      'items': contactos.map((c) => c.toMap()).toList(),
      'actualizado_en': FieldValue.serverTimestamp(),
    });
  }
}
