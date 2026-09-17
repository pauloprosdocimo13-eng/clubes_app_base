import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'pantallas/pantalla_avisos.dart';
import 'pantallas/pantalla_noticias.dart';
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
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No se pudo iniciar TuSede Central.'),
          ),
        ),
      ),
    );
    return;
  }

  final club = await FirestoreTuSede.cargarClubActual();

  if (club == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No existe clubes/generico.'),
          ),
        ),
      ),
    );
    return;
  }

  // La prueba pública debe funcionar sin sesión administrativa.
  await ServicioFirebaseTuSede.auth.signOut();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _PruebaContenidoPublico(config: config),
    ),
  );
}

class _PruebaContenidoPublico extends StatelessWidget {
  final ConfiguracionApp config;

  const _PruebaContenidoPublico({
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Contenido Público · '
            '${ContextoClub.nombreCorto}',
          ),
          backgroundColor: ContextoClub.colorPrimario,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.newspaper),
                text: 'Noticias',
              ),
              Tab(
                icon: Icon(Icons.notifications_active),
                text: 'Avisos',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PantallaNoticias(config: config),
            PantallaAvisos(
              config: config,
              deporteId: 'general',
            ),
          ],
        ),
      ),
    );
  }
}
