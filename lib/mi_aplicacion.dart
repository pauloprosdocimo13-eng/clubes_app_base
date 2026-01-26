import 'package:flutter/material.dart';
import 'configuracion/configuracion_app.dart';
import 'pantallas/pantalla_inicio.dart'; // ¡Ahora sí coincide con tu carpeta!
import 'pantallas/pantalla_seleccion.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pantallas/pantalla_splash.dart';

class MiAplicacion extends StatelessWidget {
  final ConfiguracionApp config;

  const MiAplicacion({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.nombreApp,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'), // Español Argentina
      ],
      theme: ThemeData(
        primaryColor: config.colorPrimario,
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.colorPrimario,
          secondary: config.colorSecundario,
        ),
        useMaterial3: true,
      ),
      home: PantallaSplash(config: config),
    );
  }
}