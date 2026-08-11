import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

class PantallaMinutoAMinuto extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaMinutoAMinuto({super.key, required this.config, required this.deporteId});

  @override
  State<PantallaMinutoAMinuto> createState() => _PantallaMinutoAMinutoState();
}

class _PantallaMinutoAMinutoState extends State<PantallaMinutoAMinuto> {
  Timer? _timer;
  String _tiempoTranscurrido = "00:00";
  Timestamp? _inicioTiempo;
  Timestamp? _horaInicioReal;
  String _estado = "";
  bool _titilar = true; // Para el efecto de "titileo" del reloj en vivo

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _actualizarReloj();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _actualizarReloj() {
    if (_inicioTiempo == null || (_estado != '1T' && _estado != '2T')) {
      if (mounted && !_titilar) setState(() => _titilar = true); // Fijo si no corre
      return;
    }

    final now = DateTime.now();
    final inicio = _inicioTiempo!.toDate();
    final difference = now.difference(inicio);

    final minutos = difference.inMinutes;
    final segundos = difference.inSeconds % 60;

    if (mounted) {
      setState(() {
        _tiempoTranscurrido = "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
        _titilar = !_titilar; // Alterna verdadero/falso cada segundo
      });
    }
  }

  String _textoEstadoLargo(String abrev) {
    if (abrev == '1T') return "1er Tiempo";
    if (abrev == '2T') return "2do Tiempo";
    if (abrev == 'ENTRETIEMPO') return "Entretiempo";
    return abrev;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fijo un fondo super oscuro, estilo "Modo Noche" para toda la pantalla
      backgroundColor: const Color(0xFF121212), 
      appBar: AppBar(
        title: const Text("VIVO", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.transparent, // Barra transparente para integrarse al diseño
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true, // Hace que el contenido suba hasta arriba de todo
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: CircularProgressIndicator(color: widget.config.colorPrimario),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          if (!(data['activo'] ?? false)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "La transmisión ha finalizado. Ve al historial para ver el resultado final.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          _estado = data['estado'] ?? '1T';
          if (data['inicio_tiempo'] != null) _inicioTiempo = data['inicio_tiempo'];
          if (data['inicio_partido_real'] != null) _horaInicioReal = data['inicio_partido_real'];

          final rival = data['rival'] ?? 'Rival';
          final escudoRival = data['escudo_rival'];
          final golesL = data['goles_local'] ?? 0;
          final golesV = data['goles_visita'] ?? 0;
          final categoria = data['categoria'] ?? '';
          final eventos = List.from(data['eventos'] ?? []).reversed.toList();

          String horaInicioTexto = "";
          if (_horaInicioReal != null) {
            final date = _horaInicioReal!.toDate();
            horaInicioTexto = "${date.hour}:${date.minute.toString().padLeft(2, '0')}hs";
          }

          return Column(
            children: [
              // --- HEADER ESTILO PANTALLA ESTADIO ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 90, bottom: 30, left: 10, right: 10),
                decoration: BoxDecoration(
                  // Un degradado que usa tu color primario fundiéndose a negro
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.config.colorPrimario.withOpacity(0.4),
                      const Color(0xFF121212),
                    ],
                  ),
                  border: const Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: Column(
                  children: [
                    Text(
                      "CATEGORÍA $categoria".toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        letterSpacing: 4,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (horaInicioTexto.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Inicio: $horaInicioTexto",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LOCAL
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.config.colorPrimario.withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                                child: Image.asset(widget.config.rutaLogo, height: 70),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.config.nombreApp.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        
                        // TABLERO
                        Column(
                          children: [
                            Text(
                              "$golesL - $golesV",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier', // Estilo numérico digital/clásico
                              ),
                            ),
                            const SizedBox(height: 5),
                            // RELOJ NEÓN
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getColorEstado(_estado).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _getColorEstado(_estado).withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_estado == '1T' || _estado == '2T') ...[
                                    AnimatedOpacity(
                                      opacity: _titilar ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 300),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getColorEstado(_estado),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: _getColorEstado(_estado), blurRadius: 5)
                                          ]
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    (_estado == '1T' || _estado == '2T')
                                        ? "${_textoEstadoLargo(_estado)} | $_tiempoTranscurrido"
                                        : _textoEstadoLargo(_estado),
                                    style: TextStyle(
                                      color: _getColorEstado(_estado),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // VISITA
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: escudoRival != null && escudoRival.isNotEmpty
                                    ? Image.network(escudoRival, height: 70)
                                    : const Icon(Icons.shield, color: Colors.white24, size: 70),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                rival.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- TIMELINE DE EVENTOS ---
              Expanded(
                child: eventos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports, size: 60, color: Colors.white10),
                            const SizedBox(height: 15),
                            const Text(
                              "ESPERANDO EVENTOS...",
                              style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        itemCount: eventos.length,
                        itemBuilder: (context, index) {
                          final evt = eventos[index];
                          final esLocal = evt['equipo'] == 'local';
                          
                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                // Tarjeta Local
                                Expanded(
                                  child: esLocal ? _construirTarjetaEvento(evt, true) : const SizedBox(),
                                ),
                                
                                // Línea Central Luminosa
                                SizedBox(
                                  width: 50,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(width: 2, color: Colors.white10),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E24),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: esLocal ? widget.config.colorPrimario : Colors.white24, 
                                            width: 2
                                          ),
                                          boxShadow: esLocal ? [
                                            BoxShadow(color: widget.config.colorPrimario.withOpacity(0.3), blurRadius: 8)
                                          ] : [],
                                        ),
                                        child: _iconoEventoOscuro(evt['tipo']),
                                      ),
                                    ],
                                  ),
                                ),

                                // Tarjeta Visita
                                Expanded(
                                  child: !esLocal ? _construirTarjetaEvento(evt, false) : const SizedBox(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- TARJETAS DE EVENTOS MODERNAS ---
  Widget _construirTarjetaEvento(Map<String, dynamic> evt, bool esLocal) {
    final tipo = evt['tipo'];
    final minuto = evt['minuto'] ?? "0'";
    final detalle = evt['detalle'] ?? '';

    return Container(
      margin: EdgeInsets.only(
        top: 15, bottom: 15,
        left: esLocal ? 15 : 0, 
        right: esLocal ? 0 : 15,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24), // Gris oscuro azulado para las tarjetas
        borderRadius: BorderRadius.circular(15),
        border: Border(
          // Una barra de color al costado para identificar rápido al equipo
          left: esLocal ? BorderSide(color: widget.config.colorPrimario, width: 4) : BorderSide.none,
          right: !esLocal ? const BorderSide(color: Colors.white24, width: 4) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: esLocal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: esLocal ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(
                minuto,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: esLocal ? widget.config.colorPrimario : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _textoEvento(tipo).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.white54,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            textAlign: esLocal ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    if (estado == 'SUSPENDIDO') return Colors.redAccent;
    if (estado == 'ENTRETIEMPO') return Colors.orangeAccent;
    return const Color(0xFF00FF66); // Verde Neón súper brillante para "VIVO"
  }

  Widget _iconoEventoOscuro(String tipo) {
    if (tipo == 'gol') return const Icon(Icons.sports_soccer, color: Colors.white, size: 18);
    if (tipo == 'amarilla') return const Icon(Icons.style, color: Colors.amberAccent, size: 18);
    if (tipo == 'roja') return const Icon(Icons.style, color: Colors.redAccent, size: 18);
    return const Icon(Icons.info_outline, color: Colors.white38, size: 18);
  }

  String _textoEvento(String tipo) {
    if (tipo == 'gol') return "GOL";
    if (tipo == 'amarilla') return "Amarilla";
    if (tipo == 'roja') return "Roja";
    return "Evento";
  }
}