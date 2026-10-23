import 'package:flutter/material.dart';
import 'tusede/diseno/identidad_tusede.dart';
import 'tusede/servicios/servicio_firebase_tusede.dart';
import 'tusede/pantallas/pantalla_catalogo_tusede.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServicioFirebaseTuSede.inicializar();
  runApp(
    MaterialApp(
      title: 'TuSede',
      debugShowCheckedModeBanner: false,
      theme: temaTuSede(),
      home: const PantallaCatalogoTuSede(),
    ),
  );
}
