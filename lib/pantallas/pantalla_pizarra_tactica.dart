import 'package:flutter/material.dart';
import '../configuracion/configuracion_app.dart';

class PantallaPizarraTactica extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPizarraTactica({super.key, required this.config});

  @override
  State<PantallaPizarraTactica> createState() => _PantallaPizarraTacticaState();
}

class _PantallaPizarraTacticaState extends State<PantallaPizarraTactica> {
  // --- ESTADO ---
  bool _modoMover = true;
  int _cantidadJugadores = 5; // Por defecto 5 (se puede cambiar)
  
  // Trazos del dibujo
  List<List<Offset>> _trazos = [];
  List<Offset> _trazoActual = [];

  // Posiciones de los jugadores
  List<FichaJugador> _fichas = [];

  @override
  void initState() {
    super.initState();
    // Iniciamos por defecto con 5, pero el usuario puede cambiarlo
    _resetearTablero(5);
  }

  // --- REINICIAR Y CONFIGURAR TABLERO ---
  void _resetearTablero(int cantidad) {
    setState(() {
      _cantidadJugadores = cantidad;
      _trazos.clear();
      _fichas.clear();

      // --- EQUIPO LOCAL (Abajo) ---
      // Arquero
      _fichas.add(FichaJugador(id: 1, x: 0.5, y: 0.9, esLocal: true, dorsal: "1")); 
      
      if (cantidad == 5) {
        // Formación 2-2 (Cuadrado)
        _fichas.add(FichaJugador(id: 2, x: 0.25, y: 0.75, esLocal: true, dorsal: "2"));
        _fichas.add(FichaJugador(id: 3, x: 0.75, y: 0.75, esLocal: true, dorsal: "3"));
        _fichas.add(FichaJugador(id: 4, x: 0.35, y: 0.6, esLocal: true, dorsal: "10"));
        _fichas.add(FichaJugador(id: 5, x: 0.65, y: 0.6, esLocal: true, dorsal: "9"));
      } else {
        // Formación 3-2 (Con un 5 tapón o líbero) o 2-1-2
        _fichas.add(FichaJugador(id: 2, x: 0.2, y: 0.75, esLocal: true, dorsal: "2"));
        _fichas.add(FichaJugador(id: 3, x: 0.8, y: 0.75, esLocal: true, dorsal: "3"));
        _fichas.add(FichaJugador(id: 11, x: 0.5, y: 0.7, esLocal: true, dorsal: "5")); // El jugador extra
        _fichas.add(FichaJugador(id: 4, x: 0.3, y: 0.55, esLocal: true, dorsal: "10"));
        _fichas.add(FichaJugador(id: 5, x: 0.7, y: 0.55, esLocal: true, dorsal: "9"));
      }

      // --- EQUIPO VISITANTE (Arriba) ---
      // Arquero
      _fichas.add(FichaJugador(id: 6, x: 0.5, y: 0.1, esLocal: false, dorsal: "1"));

      if (cantidad == 5) {
        // Formación 2-2 espejo
        _fichas.add(FichaJugador(id: 7, x: 0.25, y: 0.25, esLocal: false, dorsal: "4"));
        _fichas.add(FichaJugador(id: 8, x: 0.75, y: 0.25, esLocal: false, dorsal: "5"));
        _fichas.add(FichaJugador(id: 9, x: 0.35, y: 0.4, esLocal: false, dorsal: "7"));
        _fichas.add(FichaJugador(id: 10, x: 0.65, y: 0.4, esLocal: false, dorsal: "9"));
      } else {
        // Formación 3-2 espejo
        _fichas.add(FichaJugador(id: 7, x: 0.2, y: 0.25, esLocal: false, dorsal: "4"));
        _fichas.add(FichaJugador(id: 8, x: 0.8, y: 0.25, esLocal: false, dorsal: "5"));
        _fichas.add(FichaJugador(id: 12, x: 0.5, y: 0.3, esLocal: false, dorsal: "8")); // El jugador extra
        _fichas.add(FichaJugador(id: 9, x: 0.3, y: 0.45, esLocal: false, dorsal: "7"));
        _fichas.add(FichaJugador(id: 10, x: 0.7, y: 0.45, esLocal: false, dorsal: "9"));
      }
      
      // Pelota
      _fichas.add(FichaJugador(id: 99, x: 0.5, y: 0.5, esLocal: true, dorsal: "", esPelota: true));
    });
  }

  // --- LÓGICA DE DIBUJO ---
  void _empezarTrazo(DragStartDetails details, double ancho, double alto) {
    if (_modoMover) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset local = box.globalToLocal(details.globalPosition);
    final dy = local.dy - 80; 
    
    setState(() {
      _trazoActual = [Offset(local.dx, dy)];
      _trazos.add(_trazoActual);
    });
  }

  void _actualizarTrazo(DragUpdateDetails details) {
    if (_modoMover) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset local = box.globalToLocal(details.globalPosition);
    final dy = local.dy - 80;

    setState(() {
      _trazos.last.add(Offset(local.dx, dy));
    });
  }

  // --- LÓGICA DE MOVIMIENTO DE FICHAS ---
  void _moverFicha(int id, DragUpdateDetails details, double anchoCan, double altoCan) {
    if (!_modoMover) return;
    
    setState(() {
      final index = _fichas.indexWhere((f) => f.id == id);
      if (index != -1) {
        double dx = details.delta.dx / anchoCan;
        double dy = details.delta.dy / altoCan;

        _fichas[index].x += dx;
        _fichas[index].y += dy;

        // Limites de la cancha
        _fichas[index].x = _fichas[index].x.clamp(0.0, 1.0);
        _fichas[index].y = _fichas[index].y.clamp(0.0, 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pizarra ${_cantidadJugadores} vs ${_cantidadJugadores}"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Borrar Dibujos",
            onPressed: () => setState(() => _trazos.clear()),
          ),
          // SELECTOR DE MODO (5 vs 5 ó 6 vs 6)
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings),
            tooltip: "Configuración",
            onSelected: (val) => _resetearTablero(val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 5, child: Text("Fútbol 5 (Futsal)")),
              const PopupMenuItem(value: 6, child: Text("Fútbol 6 (Baby)")),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: "Reiniciar Posiciones",
            onPressed: () => _resetearTablero(_cantidadJugadores),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BARRA DE HERRAMIENTAS
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BotonHerramienta(
                  icono: Icons.pan_tool,
                  texto: "MOVER",
                  activo: _modoMover,
                  onTap: () => setState(() => _modoMover = true),
                  colorActivo: widget.config.colorPrimario,
                ),
                _BotonHerramienta(
                  icono: Icons.edit,
                  texto: "DIBUJAR",
                  activo: !_modoMover,
                  onTap: () => setState(() => _modoMover = false),
                  colorActivo: Colors.red,
                ),
              ],
            ),
          ),

          // 2. LA CANCHA (AREA INTERACTIVA)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double ancho = constraints.maxWidth;
                double alto = constraints.maxHeight;

                return GestureDetector(
                  onPanStart: (d) => _empezarTrazo(d, ancho, alto),
                  onPanUpdate: (d) => _actualizarTrazo(d),
                  child: Stack(
                    children: [
                      // CAPA 1: CANCHA
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.green[800], // Césped
                          border: Border.all(color: Colors.white, width: 5),
                        ),
                        child: CustomPaint(
                          painter: _CanchaPainter(),
                        ),
                      ),

                      // CAPA 2: DIBUJOS (TÁCTICA)
                      CustomPaint(
                        size: Size(ancho, alto),
                        painter: _DibujoPainter(trazos: _trazos),
                      ),

                      // CAPA 3: FICHAS (JUGADORES)
                      ..._fichas.map((ficha) {
                        return Positioned(
                          left: (ficha.x * ancho) - 15, // -15 para centrar (radio 15)
                          top: (ficha.y * alto) - 15,
                          child: GestureDetector(
                            onPanUpdate: (d) => _moverFicha(ficha.id, d, ancho, alto),
                            child: _WidgetFicha(
                              ficha: ficha, 
                              colorLocal: widget.config.colorPrimario,
                            ),
                          ),
                        );
                      }).toList(),

                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- CLASES AUXILIARES ---

class FichaJugador {
  int id;
  double x; // 0.0 a 1.0 (Porcentaje del ancho)
  double y; // 0.0 a 1.0 (Porcentaje del alto)
  bool esLocal;
  String dorsal;
  bool esPelota;

  FichaJugador({
    required this.id, 
    required this.x, 
    required this.y, 
    required this.esLocal, 
    required this.dorsal,
    this.esPelota = false,
  });
}

class _WidgetFicha extends StatelessWidget {
  final FichaJugador ficha;
  final Color colorLocal;

  const _WidgetFicha({required this.ficha, required this.colorLocal});

  @override
  Widget build(BuildContext context) {
    if (ficha.esPelota) {
      return Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2,2))]
        ),
        child: const Icon(Icons.sports_soccer, size: 18, color: Colors.black),
      );
    }

    return Container(
      width: 34, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ficha.esLocal ? colorLocal : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ficha.esLocal ? Colors.white : Colors.black, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2,2))]
      ),
      child: Text(
        ficha.dorsal,
        style: TextStyle(
          color: ficha.esLocal ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14
        ),
      ),
    );
  }
}

class _BotonHerramienta extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final Color colorActivo;

  const _BotonHerramienta({required this.icono, required this.texto, required this.activo, required this.onTap, required this.colorActivo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? colorActivo : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? colorActivo : Colors.grey)
        ),
        child: Row(
          children: [
            Icon(icono, color: activo ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(texto, style: TextStyle(color: activo ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Pintor de líneas tácticas (Rojo transparente)
class _DibujoPainter extends CustomPainter {
  final List<List<Offset>> trazos;
  _DibujoPainter({required this.trazos});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length > 1) {
        Path path = Path();
        path.moveTo(trazo.first.dx, trazo.first.dy);
        for (int i = 1; i < trazo.length; i++) {
          path.lineTo(trazo[i].dx, trazo[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Pintor de la Cancha (Líneas blancas)
class _CanchaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Linea central
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    
    // Circulo central
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, paint);

    // Areas
    // Area Arriba
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width/2, 0), width: size.width * 0.5, height: size.height * 0.15), paint);
    // Area Abajo
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width/2, size.height), width: size.width * 0.5, height: size.height * 0.15), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}