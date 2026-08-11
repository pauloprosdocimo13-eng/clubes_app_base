import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../configuracion/configuracion_app.dart';

class ServicioAvisoEntrada {
  static const _prefKey = 'ultimo_aviso_entrada_visto';

  static Future<void> mostrarSiCorresponde(
    BuildContext context,
    ConfiguracionApp config, {
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
    if (!context.mounted) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('aviso_entrada')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final activo = data['activo'] ?? false;
      if (!activo) return;

      final avisoId = _generarIdAviso(data);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefKey) == avisoId) return;

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DialogoAvisoEntrada(
          config: config,
          titulo: data['titulo'] ?? 'Aviso Importante',
          mensaje: data['mensaje'] ?? '',
          imagenUrl: data['imagen_url'] ?? '',
        ),
      );

      await prefs.setString(_prefKey, avisoId);
    } catch (e) {
      debugPrint('Error chequeando aviso de entrada: $e');
    }
  }

  static String _generarIdAviso(Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? '';
    final mensaje = data['mensaje'] ?? '';
    final imagen = data['imagen_url'] ?? '';
    final actualizado = data['actualizado_en']?.toString() ?? '';
    return '$titulo|$mensaje|$imagen|$actualizado'.hashCode.toString();
  }
}

class _DialogoAvisoEntrada extends StatelessWidget {
  final ConfiguracionApp config;
  final String titulo;
  final String mensaje;
  final String imagenUrl;

  const _DialogoAvisoEntrada({
    required this.config,
    required this.titulo,
    required this.mensaje,
    required this.imagenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagenUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 350,
                    minHeight: 100,
                    minWidth: double.infinity,
                  ),
                  child: Image.network(
                    imagenUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(color: config.colorPrimario),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Icon(Icons.campaign, size: 50, color: config.colorPrimario),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (titulo.isNotEmpty)
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: config.colorPrimario,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  if (titulo.isNotEmpty && mensaje.isNotEmpty) const SizedBox(height: 10),
                  if (mensaje.isNotEmpty)
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: config.colorPrimario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
