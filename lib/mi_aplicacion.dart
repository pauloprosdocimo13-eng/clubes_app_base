import 'package:flutter/material.dart';
import 'configuracion/configuracion_app.dart';
import 'tusede/servicios/contexto_club.dart';
import 'pantallas/pantalla_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MiAplicacion extends StatelessWidget {
  final ConfiguracionApp config;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MiAplicacion({super.key, required this.config, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ETAPA 4E-1B - IDENTIDAD GLOBAL TUSEDE
    // ============================================================
    // ContextoClub ya fue cargado antes de runApp().
    // Sus colores tienen fallback automático a ConfiguracionApp.
    final String nombreClub = ContextoClub.nombreClub.trim().isNotEmpty
        ? ContextoClub.nombreClub.trim()
        : config.nombreApp;
    final Color colorPrimario = ContextoClub.colorPrimario;
    final Color colorSecundario = ContextoClub.colorSecundario;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: nombreClub,
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
        primaryColor: colorPrimario,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrimario,
          secondary: colorSecundario,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
        ),
      ),
      home: PantallaSplash(config: config),
    );
  }
}
