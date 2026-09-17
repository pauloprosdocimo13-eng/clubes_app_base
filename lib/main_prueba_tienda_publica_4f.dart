import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'pantallas/pantalla_tienda.dart';
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

  final centralOk =
      await ServicioFirebaseTuSede.inicializar();

  if (centralOk) {
    await FirestoreTuSede.cargarClubActual();
  }

  runApp(
    _PruebaTiendaPublicaApp(
      config: config,
      centralOk: centralOk,
    ),
  );
}

class _PruebaTiendaPublicaApp
    extends StatelessWidget {
  final ConfiguracionApp config;
  final bool centralOk;

  const _PruebaTiendaPublicaApp({
    required this.config,
    required this.centralOk,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '4F-2K Tienda Pública',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.colorPrimario,
        ),
      ),
      home: centralOk
          ? PantallaTienda(config: config)
          : const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudo inicializar '
                    'TuSede Central.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}
