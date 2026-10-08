import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../pantallas/pantalla_inicio.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class SelectorTiraBottomSheet {
  static bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  static Future<List<Map<String, dynamic>>> _cargarDeportes() async {
    if (_usaCentral) {
      final configuracion =
          await ServicioContenidoPublico.cargarConfiguracion();

      return List<Map<String, dynamic>>.from(configuracion.menuDeportes);
    }

    final doc = await FirebaseFirestore.instance
        .collection('configuracion')
        .doc('general')
        .get();

    final lista = <Map<String, dynamic>>[];

    final raw = doc.data()?['menu_deportes'];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          lista.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return lista;
  }

  static Future<void> mostrar(
    BuildContext context, {
    required ConfiguracionApp config,
    required String deporteIdActual,
  }) async {
    try {
      final lista = await _cargarDeportes();

      if (!context.mounted) {
        return;
      }

      if (lista.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay categorías configuradas')),
        );

        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ContenidoSelector(
          config: config,
          deportes: lista,
          deporteIdActual: deporteIdActual,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar categorías: $e')),
        );
      }
    }
  }
}

class _ContenidoSelector extends StatelessWidget {
  final ConfiguracionApp config;
  final List<Map<String, dynamic>> deportes;
  final String deporteIdActual;

  const _ContenidoSelector({
    required this.config,
    required this.deportes,
    required this.deporteIdActual,
  });

  IconData _iconoDeporte(String id) {
    final normalizado = id.toLowerCase();

    if (normalizado.contains('baby')) {
      return Icons.sports_soccer;
    }

    if (normalizado.contains('futsal')) {
      return Icons.sports_handball;
    }

    if (normalizado.contains('futbol') || normalizado.contains('fútbol')) {
      return Icons.sports_soccer;
    }

    if (normalizado.contains('patin') || normalizado.contains('patín')) {
      return Icons.sports_gymnastics;
    }

    if (normalizado.contains('boxeo')) {
      return Icons.sports_mma;
    }

    if (normalizado.contains('taekwondo')) {
      return Icons.sports_martial_arts;
    }

    return Icons.star;
  }

  void _seleccionar(BuildContext context, Map<String, dynamic> deporte) {
    final id = (deporte['id'] ?? '').toString().trim();

    final titulo = (deporte['titulo'] ?? id).toString().trim();

    if (id.isEmpty) {
      return;
    }

    if (id == deporteIdActual) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaInicio(
          config: config,
          deporteId: id,
          deporteTitulo: titulo.isEmpty ? id : titulo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: config.colorPrimario),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cambiar categoría',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Elegí otra tira sin salir del menú principal',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: deportes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final deporte = deportes[index];

                final id = (deporte['id'] ?? '').toString();

                final titulo = (deporte['titulo'] ?? id).toString();

                final seleccionado = id == deporteIdActual;

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: seleccionado
                          ? config.colorPrimario
                          : Colors.grey[200]!,
                      width: seleccionado ? 2 : 1,
                    ),
                  ),
                  tileColor: seleccionado
                      ? config.colorPrimario.withValues(alpha: 0.08)
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: config.colorPrimario.withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(_iconoDeporte(id), color: config.colorPrimario),
                  ),
                  title: Text(
                    titulo.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: seleccionado
                          ? config.colorPrimario
                          : Colors.black87,
                    ),
                  ),
                  trailing: seleccionado
                      ? Icon(Icons.check_circle, color: config.colorPrimario)
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _seleccionar(context, deporte);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
