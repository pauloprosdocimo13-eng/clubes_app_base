import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'pantallas/pruebas/pantalla_prueba_finanzas_4f.dart';
import 'tusede/servicios/contexto_club.dart';
import 'tusede/servicios/firestore_tusede.dart';
import 'tusede/servicios/servicio_firebase_tusede.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const sabor = 'generico';
  final config = RegistroFlavors.configDe(sabor);

  await Firebase.initializeApp(
    options: RegistroFlavors.firebaseOptionsDe(sabor),
  );

  ConfiguracionApp.actual = config;
  ContextoClub.inicializarDesdeConfiguracion(config);

  final inicializado = await ServicioFirebaseTuSede.inicializar();
  if (!inicializado) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('No se pudo iniciar TuSede Central.')),
      ),
    ));
    return;
  }

  final club = await FirestoreTuSede.cargarClubActual();
  if (club == null) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('No existe clubes/generico.')),
      ),
    ));
    return;
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PantallaPruebaFinanzas4F(config: config),
    ),
  );
}
