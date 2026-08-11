import 'package:flutter/material.dart';
import 'configuracion/configuracion_app.dart';
import 'pantallas/pantalla_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MiAplicacion extends StatelessWidget {
  final ConfiguracionApp config;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MiAplicacion({super.key, required this.config, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: config.nombreApp,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
      ],
      theme: ThemeData(
        primaryColor: config.colorPrimario,
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.colorPrimario,
          secondary: config.colorSecundario,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: config.colorPrimario,
          foregroundColor: Colors.white,
        ),
      ),
      home: PantallaSplash(config: config),
    );
  }
}
