import 'package:flutter/material.dart';
import 'tusede/servicios/servicio_firebase_tusede.dart';
import 'tusede/pantallas/pantalla_catalogo_tusede.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServicioFirebaseTuSede.inicializar();
  runApp(
    MaterialApp(
      title: 'TuSede',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      home: const PantallaCatalogoTuSede(),
    ),
  );
}
