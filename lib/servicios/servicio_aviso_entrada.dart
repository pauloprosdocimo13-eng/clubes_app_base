import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../configuracion/configuracion_app.dart';

class ServicioAvisoEntrada {
  ServicioAvisoEntrada._();

  // Evita que el mismo aviso aparezca varias veces durante una misma
  // ejecución de la app. Al cerrar y volver a abrir la aplicación, estas
  // variables vuelven a su valor inicial y el aviso puede mostrarse de nuevo.
  static bool _mostradoEnEstaSesion = false;
  static bool _mostrando = false;

  static Future<void> mostrarSiCorresponde(
    BuildContext context,
    ConfiguracionApp config, {
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    // Si ya se mostró en esta apertura de la app, no repetimos el diálogo.
    if (_mostradoEnEstaSesion || _mostrando) return;

    await Future.delayed(delay);
    if (!context.mounted) return;

    // Volvemos a controlar por si otra llamada llegó durante el delay.
    if (_mostradoEnEstaSesion || _mostrando) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('aviso_entrada')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final activo = data['activo'] ?? false;
      if (!activo) return;

      if (!context.mounted) return;

      _mostrando = true;

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

      // Se marca como visto únicamente para esta ejecución de la app.
      // No se guarda nada en SharedPreferences ni en el dispositivo.
      _mostradoEnEstaSesion = true;
    } catch (e) {
      debugPrint('Error chequeando aviso de entrada: $e');
    } finally {
      _mostrando = false;
    }
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                          child: CircularProgressIndicator(
                            color: config.colorPrimario,
                          ),
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
                child: Icon(
                  Icons.campaign,
                  size: 50,
                  color: config.colorPrimario,
                ),
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
                  if (titulo.isNotEmpty && mensaje.isNotEmpty)
                    const SizedBox(height: 10),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ENTENDIDO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
