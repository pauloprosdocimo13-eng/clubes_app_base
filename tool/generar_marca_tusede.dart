// Ejecutar: flutter test --no-pub tool/generar_marca_tusede.dart
// Renderiza la marca vectorial; solo escribe recursos de TuSede (Android generico y web).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_native_splash/cli_commands.dart' as splash;
import 'package:clubes_app_base/tusede/diseno/identidad_tusede.dart';

void main() {
  testWidgets('Generar recursos de la marca TuSede', (tester) async {
    await tester.runAsync(() async {
      Future<void> guardar(
        String ruta,
        int dimension, {
        bool transparente = false,
      }) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(dimension / 1024);
        if (!transparente) {
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 1024, 1024),
            Paint()..color = fondoTuSede,
          );
        }
        // Margen seguro para máscaras circulares, cuadradas y Android 12.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(184, 184, 656, 656),
            const Radius.circular(200),
          ),
          Paint()..color = mentaTuSede,
        );
        canvas.translate(312, 312);
        canvas.scale(400 / 22);
        PintorCanchaTuSede(tintaTuSede).paint(canvas, const Size(22, 22));
        final picture = recorder.endRecording();
        final image = await picture.toImage(dimension, dimension);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(ruta);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }

      await guardar('assets/tusede/launcher_icon.png', 1024);
      await guardar('assets/tusede/splash_icon.png', 1152, transparente: true);
      await guardar('web/tusede_logo.png', 512, transparente: true);
      await guardar('web/favicon.png', 48);
      for (final n in [192, 512]) {
        await guardar('web/icons/Icon-$n.png', n);
        await guardar('web/icons/Icon-maskable-$n.png', n);
      }
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        await guardar(
          'android/app/src/generico/res/mipmap-${entry.key}/launcher_icon.png',
          entry.value,
        );
      }
      splash.createSplash(
        path: 'flutter_native_splash-generico.yaml',
        flavor: 'generico',
      );
      for (final carpeta in [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final archivo = File(
          'android/app/src/generico/res/$carpeta/styles.xml',
        );
        archivo.writeAsStringSync(
          archivo.readAsStringSync().replaceAll(
            '?android:colorBackground',
            '#0B1F27',
          ),
        );
      }
    });
  });
}
