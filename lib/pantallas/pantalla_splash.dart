import 'package:flutter/material.dart';
import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../servicios/servicio_firebase.dart';
import 'pantalla_seleccion.dart'; 
import 'pantalla_seleccion_actividad.dart'; 

class PantallaSplash extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaSplash({super.key, required this.config});

  @override
  State<PantallaSplash> createState() => _PantallaSplashState();
}

class _PantallaSplashState extends State<PantallaSplash> {
  double _opacidad = 0.0;

  @override
  void initState() {
    super.initState();
    
    // 1. Iniciamos la animación visual (Estética)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _opacidad = 1.0;
        });
      }
    });

    // 2. Iniciamos la lógica de decisión protegida
    _decidirNavegacion();
  }

  Future<void> _decidirNavegacion() async {
    bool activarMultiActividad = false;

    // Ejecutamos en paralelo los 3 segundos estéticos mínimos del Splash
    // y la consulta protegida con timeout a nuestro servicio.
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      ServicioFirebase().consultarModoMultiActividad().then((resultado) {
        activarMultiActividad = resultado;
      }),
    ]);

    if (!mounted) return;

    if (activarMultiActividad) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PantallaSeleccionActividad(config: widget.config)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PantallaSeleccion(config: widget.config)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ETAPA 4E-1C - IDENTIDAD DINAMICA EN SPLASH
    // ============================================================
    final String nombreClub = ContextoClub.nombreClub.trim().isNotEmpty
        ? ContextoClub.nombreClub.trim()
        : widget.config.nombreApp;
    final String lemaClub = ContextoClub.lema.trim();
    final Color colorPrimario = ContextoClub.colorPrimario;
    final Color colorSecundario = ContextoClub.colorSecundario;

    final Color colorFondoInferior = Color.alphaBlend(
      Colors.black.withAlpha(150),
      colorSecundario,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Fondo institucional limpio y premium
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorPrimario,
              colorFondoInferior,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: _opacidad,
              curve: Curves.easeOut,
              child: Column(
                children: [
                  // Logo del Club con sombra profunda
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Image.asset(widget.config.rutaLogo),
                  ),
                  const SizedBox(height: 35),
                  
                  // Nombre del Club
                  Text(
                    nombreClub.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtítulo de autoridad
                  const Text(
                    "SISTEMA OFICIAL",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                  ),
                  if (lemaClub.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        lemaClub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 70),
            
            // INDICADOR DE CARGA
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}