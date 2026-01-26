import 'package:flutter/material.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_seleccion.dart'; // IMPORTANTE: Importamos la pantalla que tiene las tiras de fútbol

class PantallaSeleccionActividad extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaSeleccionActividad({super.key, required this.config});

  // --- NAVEGACIÓN ---

  void _irAFutbol(BuildContext context) {
    // NAVEGACIÓN CLAVE: Vamos a la pantalla 'PantallaSeleccion' (la que ya tenías)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaSeleccion(config: config)),
    );
  }

  void _irAProximamente(BuildContext context, String actividad) {
    // Muestra un aviso temporal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("La sección de $actividad estará disponible muy pronto."),
        backgroundColor: config.colorPrimario,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. CABECERA INSTITUCIONAL
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: config.colorPrimario,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40)
              ),
              boxShadow: [
                BoxShadow(
                  color: config.colorPrimario.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 10)
                )
              ],
            ),
            child: Column(
              children: [
                // Logo del Club
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage(config.rutaLogo),
                ),
                const SizedBox(height: 15),
                // Nombre del Club
                Text(
                  config.nombreApp.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(15)
                  ),
                  child: const Text(
                    "Seleccioná tu actividad",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // 2. LISTA DE BOTONES (FIJOS)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                
                // --- BOTÓN 1: FÚTBOL (Lleva a PantallaSeleccion) ---
                _TarjetaActividad(
                  titulo: "FÚTBOL",
                  subtitulo: "Tiras, Fixture, Socios y Alquileres",
                  icono: Icons.sports_soccer,
                  colorIcono: Colors.blue[800]!,
                  fondoColor: Colors.blue[50]!,
                  alPresionar: () => _irAFutbol(context),
                ),
                
                const SizedBox(height: 20),

                // --- BOTÓN 2: PATÍN (Próximamente) ---
                _TarjetaActividad(
                  titulo: "PATÍN ARTÍSTICO",
                  subtitulo: "Novedades y Galería",
                  icono: Icons.ice_skating, 
                  colorIcono: Colors.pink[600]!,
                  fondoColor: Colors.pink[50]!,
                  alPresionar: () => _irAProximamente(context, "Patín Artístico"),
                ),

                const SizedBox(height: 20),

                // --- BOTÓN 3: TAEKWONDO (Próximamente) ---
                _TarjetaActividad(
                  titulo: "TAEKWONDO",
                  subtitulo: "Información y Eventos",
                  icono: Icons.sports_martial_arts,
                  colorIcono: Colors.orange[800]!,
                  fondoColor: Colors.orange[50]!,
                  alPresionar: () => _irAProximamente(context, "Taekwondo"),
                ),

              ],
            ),
          ),
          
          // PIE DE PÁGINA
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Más actividades próximamente...",
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
        ],
      ),
    );
  }
}

// Widget auxiliar para diseño de tarjeta
class _TarjetaActividad extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color colorIcono;
  final Color fondoColor;
  final VoidCallback alPresionar;

  const _TarjetaActividad({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.colorIcono,
    required this.fondoColor,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: alPresionar,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, fondoColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: colorIcono.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Icon(icono, color: colorIcono, size: 35),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    const SizedBox(height: 5),
                    Text(subtitulo, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}