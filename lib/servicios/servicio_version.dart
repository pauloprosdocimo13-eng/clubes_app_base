import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ServicioVersion {
  static bool esVersionMenor(String actual, String minima) {
    final vActual = actual.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final vMinima = minima.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final a = i < vActual.length ? vActual[i] : 0;
      final m = i < vMinima.length ? vMinima[i] : 0;
      if (a < m) return true;
      if (a > m) return false;
    }
    return false;
  }

  static Future<bool> requiereActualizacion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('versiones')
          .get();

      if (!doc.exists || doc.data() == null) return false;

      final versionMinima = doc.data()!['minima_android']?.toString() ?? '1.0.0';
      final packageInfo = await PackageInfo.fromPlatform();
      return esVersionMenor(packageInfo.version, versionMinima);
    } catch (e) {
      debugPrint('Error verificando versión: $e');
      return false;
    }
  }

  static Future<String> urlPlayStore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('versiones')
          .get();
      return doc.data()?['url_playstore']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> mostrarBloqueoSiCorresponde(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('versiones')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final versionMinima = doc.data()!['minima_android']?.toString() ?? '1.0.0';
      final urlPlayStore = doc.data()!['url_playstore']?.toString() ?? '';
      final packageInfo = await PackageInfo.fromPlatform();

      if (!esVersionMenor(packageInfo.version, versionMinima)) return;
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.system_update, color: Colors.blue, size: 30),
                SizedBox(width: 10),
                Text('Actualización Requerida'),
              ],
            ),
            content: const Text(
              'Lanzamos una nueva versión con mejoras y nuevas secciones.\n\n'
              'Por favor, actualizá la app para seguir utilizándola.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (urlPlayStore.isNotEmpty) {
                      final uri = Uri.parse(urlPlayStore);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    'IR A LA PLAY STORE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error en bloqueo de versión: $e');
    }
  }
}
