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
  Timestamp? _horaInicioReal; // NUEVO
  String _estado = "";

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
    if (_inicioTiempo == null || (_estado != '1T' && _estado != '2T')) return;

    final now = DateTime.now();
    final inicio = _inicioTiempo!.toDate();
    final difference = now.difference(inicio);

    final minutos = difference.inMinutes;
    final segundos = difference.inSeconds % 60;

    if (mounted) {
      setState(() {
        _tiempoTranscurrido = "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
      });
    }
  }

  // Helper para mostrar "1er Tiempo" en vez de "1T"
  String _textoEstadoLargo(String abrev) {
    if (abrev == '1T') return "1er Tiempo";
    if (abrev == '2T') return "2do Tiempo";
    if (abrev == 'ENTRETIEMPO') return "Entretiempo";
    return abrev;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("En VIVO"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Cargando transmisión..."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // Si no está activo, el usuario debería haber ido al historial, pero por seguridad mostramos esto:
          if (!(data['activo'] ?? false)) {
            return const Center(child: Text("La transmisión ha finalizado. Ve al historial para ver el resultado."));
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

          // Formato hora inicio
          String horaInicioTexto = "";
          if (_horaInicioReal != null) {
            final date = _horaInicioReal!.toDate();
            horaInicioTexto = "${date.hour}:${date.minute.toString().padLeft(2, '0')}hs";
          }

          return Column(
            children: [
              // --- ENCABEZADO MARCADOR ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                color: Colors.black,
                child: Column(
                  children: [
                    Text("CATEGORÍA $categoria", style: const TextStyle(color: Colors.white54, letterSpacing: 2)),
                    if (horaInicioTexto.isNotEmpty)
                      Text("Inicio: $horaInicioTexto", style: const TextStyle(color: Colors.grey, fontSize: 12)),

                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(children: [
                          Image.asset(widget.config.rutaLogo, height: 60),
                          const SizedBox(height: 5),
                          Text(widget.config.nombreApp, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                        Text("$golesL - $golesV", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                        Column(children: [
                          escudoRival != null && escudoRival.isNotEmpty
                              ? Image.network(escudoRival, height: 60)
                              : const Icon(Icons.shield, color: Colors.grey, size: 60),
                          const SizedBox(height: 5),
                          Text(rival, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // RELOJ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                          color: _getColorEstado(_estado),
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        (_estado == '1T' || _estado == '2T')
                            ? "${_textoEstadoLargo(_estado)}  |  $_tiempoTranscurrido"
                            : _textoEstadoLargo(_estado),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // --- LISTA DE EVENTOS ---
              Expanded(
                child: eventos.isEmpty
                    ? const Center(child: Text("Comienza el partido...", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evt = eventos[index];
                    final esLocal = evt['equipo'] == 'local';
                    final tipo = evt['tipo'];
                    final minuto = evt['minuto'] ?? "0'";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: esLocal ? MainAxisAlignment.start : MainAxisAlignment.end,
                        children: [
                          if (esLocal) ...[_iconoEvento(tipo), const SizedBox(width: 10)],
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: esLocal ? widget.config.colorPrimario.withOpacity(0.1) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: esLocal ? widget.config.colorPrimario : Colors.grey),
                            ),
                            child: Column(
                              crossAxisAlignment: esLocal ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text("$minuto - ${_textoEvento(tipo)}", style: TextStyle(fontWeight: FontWeight.bold, color: esLocal ? widget.config.colorPrimario : Colors.black)),
                                Text("${evt['detalle']}"),
                              ],
                            ),
                          ),
                          if (!esLocal) ...[const SizedBox(width: 10), _iconoEvento(tipo)],
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

  Color _getColorEstado(String estado) {
    if (estado == 'SUSPENDIDO') return Colors.red;
    if (estado == 'ENTRETIEMPO') return Colors.orange;
    return Colors.greenAccent;
  }

  Widget _iconoEvento(String tipo) {
    if (tipo == 'gol') return const Icon(Icons.sports_soccer, color: Colors.black);
    if (tipo == 'amarilla') return const Icon(Icons.style, color: Colors.yellow);
    if (tipo == 'roja') return const Icon(Icons.style, color: Colors.red);
    return const Icon(Icons.info);
  }

  String _textoEvento(String tipo) {
    if (tipo == 'gol') return "GOL";
    if (tipo == 'amarilla') return "Amarilla";
    if (tipo == 'roja') return "Roja";
    return "Evento";
  }
}