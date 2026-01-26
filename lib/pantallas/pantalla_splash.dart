import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para consultar
import '../configuracion/configuracion_app.dart';
import 'pantalla_seleccion.dart'; // Camino A: Solo Fútbol (Clásico)
import 'pantalla_seleccion_actividad.dart'; // Camino B: Multi-Actividad

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

    // 2. Iniciamos la lógica de decisión
    _decidirNavegacion();
  }

  Future<void> _decidirNavegacion() async {
    bool activarMultiActividad = false;

    // Hacemos dos cosas a la vez:
    // A. Esperar 3 segundos para que se vea el logo.
    // B. Consultar a Firebase qué modo usar.
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      _consultarModoApp().then((resultado) => activarMultiActividad = resultado),
    ]);

    if (!mounted) return;

    // 3. Redirigimos según el resultado
    if (activarMultiActividad) {
      // MODO MULTI-ACTIVIDAD (Güemes) -> Pantalla 3 Botones
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PantallaSeleccionActividad(config: widget.config)),
      );
    } else {
      // MODO SOLO FÚTBOL (Otros Clubes) -> Pantalla Tiras Clásica
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PantallaSeleccion(config: widget.config)),
      );
    }
  }

  // Función auxiliar para leer Firebase sin romper la app si falla
  Future<bool> _consultarModoApp() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists && doc.data() != null) {
        // Buscamos el campo 'activar_multi_actividad'
        // Si no existe, devolvemos false (por seguridad)
        return doc.data()!['activar_multi_actividad'] ?? false;
      }
    } catch (e) {
      print("Error consultando configuración en Splash: $e");
    }
    return false; // Ante la duda, vamos al clásico
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // Mantenemos tu diseño exacto
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              widget.config.colorPrimario,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO ANIMADO
            AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: _opacidad,
              curve: Curves.easeOut,
              child: Column(
                children: [
                  // Logo del Club
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Image.asset(widget.config.rutaLogo),
                  ),
                  const SizedBox(height: 20),
                  // Nombre del Club
                  Text(
                    widget.config.nombreApp.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            // INDICADOR DE CARGA
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 20),
            const Text(
              "Iniciando...",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}