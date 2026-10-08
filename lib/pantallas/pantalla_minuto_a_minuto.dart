import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaMinutoAMinuto extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaMinutoAMinuto({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaMinutoAMinuto> createState() => _PantallaMinutoAMinutoState();
}

class _PantallaMinutoAMinutoState extends State<PantallaMinutoAMinuto> {
  Timer? _timerReloj;
  Timer? _timerCentral;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _streamLegacy;

  Map<String, dynamic>? _datosCentral;

  bool _cargandoCentral = true;
  bool _consultandoCentral = false;

  String? _errorCentral;

  String _tiempoTranscurrido = '00:00';

  Timestamp? _inicioTiempo;
  Timestamp? _horaInicioReal;

  String _estado = '';

  bool _titilar = true;

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  String get _nombreClubLocal {
    if (_usaCentral) {
      final nombre = ContextoClub.nombreClub.trim();

      if (nombre.isNotEmpty) {
        return nombre;
      }
    }

    return widget.config.nombreApp;
  }

  Widget _logoClubLocal() {
    if (_usaCentral) {
      final logoUrl = ContextoClub.logoUrlCentral.trim();

      if (logoUrl.isNotEmpty) {
        return Image.network(
          logoUrl,
          height: 70,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(widget.config.rutaLogo, height: 70);
          },
        );
      }
    }

    return Image.asset(widget.config.rutaLogo, height: 70);
  }

  @override
  void initState() {
    super.initState();

    _timerReloj = Timer.periodic(const Duration(seconds: 1), (_) {
      _actualizarReloj();
    });

    if (_usaCentral) {
      _cargarVivoCentral(inicial: true);

      _timerCentral = Timer.periodic(const Duration(seconds: 3), (_) {
        _cargarVivoCentral();
      });
    } else {
      _streamLegacy = FirebaseFirestore.instance
          .collection('partidos_en_vivo')
          .doc(widget.deporteId)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _timerReloj?.cancel();
    _timerCentral?.cancel();

    super.dispose();
  }

  // ============================================================
  // TUSEDE CENTRAL
  // ============================================================

  Future<void> _cargarVivoCentral({bool inicial = false}) async {
    if (_consultandoCentral) {
      return;
    }

    _consultandoCentral = true;

    try {
      final datos = await ServicioContenidoPublico.cargarVivo(widget.deporteId);

      if (!mounted) {
        return;
      }

      setState(() {
        _datosCentral = datos;
        _errorCentral = null;
        _cargandoCentral = false;

        if (datos != null) {
          _sincronizarDatosPartido(datos);
        } else {
          _limpiarRelojPartido();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      // Si ya tenemos datos mostrados, un fallo puntual de red
      // no borra el partido de la pantalla.
      if (_datosCentral == null || inicial) {
        setState(() {
          _errorCentral = e.toString();

          _cargandoCentral = false;
        });
      }
    } finally {
      _consultandoCentral = false;
    }
  }

  void _reintentarCentral() {
    setState(() {
      _cargandoCentral = true;
      _errorCentral = null;
    });

    _cargarVivoCentral(inicial: true);
  }

  // ============================================================
  // RELOJ
  // ============================================================

  void _sincronizarDatosPartido(Map<String, dynamic> data) {
    _estado = (data['estado'] ?? '1T').toString();

    final inicioTiempo = data['inicio_tiempo'];

    if (inicioTiempo is Timestamp) {
      _inicioTiempo = inicioTiempo;
    } else {
      _inicioTiempo = null;
    }

    final inicioReal = data['inicio_partido_real'];

    if (inicioReal is Timestamp) {
      _horaInicioReal = inicioReal;
    } else {
      _horaInicioReal = null;
    }
  }

  void _limpiarRelojPartido() {
    _estado = '';
    _inicioTiempo = null;
    _horaInicioReal = null;
    _tiempoTranscurrido = '00:00';
    _titilar = true;
  }

  void _actualizarReloj() {
    if (_inicioTiempo == null || (_estado != '1T' && _estado != '2T')) {
      if (mounted && !_titilar) {
        setState(() {
          _titilar = true;
        });
      }

      return;
    }

    final ahora = DateTime.now();

    final inicio = _inicioTiempo!.toDate();

    final diferencia = ahora.difference(inicio);

    final segundosTotales = diferencia.inSeconds < 0 ? 0 : diferencia.inSeconds;

    final minutos = segundosTotales ~/ 60;

    final segundos = segundosTotales % 60;

    if (!mounted) {
      return;
    }

    setState(() {
      _tiempoTranscurrido =
          '${minutos.toString().padLeft(2, '0')}:'
          '${segundos.toString().padLeft(2, '0')}';

      _titilar = !_titilar;
    });
  }

  String _textoEstadoLargo(String estado) {
    if (estado == '1T') {
      return '1er Tiempo';
    }

    if (estado == '2T') {
      return '2do Tiempo';
    }

    if (estado == 'ENTRETIEMPO') {
      return 'Entretiempo';
    }

    if (estado == 'FINALIZADO') {
      return 'Finalizado';
    }

    if (estado == 'SUSPENDIDO') {
      return 'Suspendido';
    }

    return estado;
  }

  // ============================================================
  // CONTENIDO CENTRAL
  // ============================================================

  Widget _contenidoCentral() {
    if (_cargandoCentral && _datosCentral == null) {
      return Center(
        child: CircularProgressIndicator(color: widget.config.colorPrimario),
      );
    }

    if (_errorCentral != null && _datosCentral == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 55),
              const SizedBox(height: 16),
              const Text(
                'No pudimos cargar la transmisión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorCentral!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _reintentarCentral,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final datos = _datosCentral;

    if (datos == null) {
      return _sinTransmision();
    }

    return _construirPartido(datos);
  }

  // ============================================================
  // CONTENIDO LEGACY
  // ============================================================

  Widget _contenidoLegacy() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _streamLegacy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar la transmisión: '
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: widget.config.colorPrimario,
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _sinTransmision();
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return _sinTransmision();
        }

        _sincronizarDatosPartido(data);

        return _construirPartido(data);
      },
    );
  }

  Widget _sinTransmision() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, color: Colors.white24, size: 60),
            SizedBox(height: 16),
            Text(
              'No hay una transmisión en vivo en este momento.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PARTIDO
  // ============================================================

  Widget _construirPartido(Map<String, dynamic> data) {
    final activo = data['activo'] == true;

    if (!activo) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'La transmisión ha finalizado. '
            'Ve al historial para ver el resultado final.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final rival = (data['rival'] ?? 'Rival').toString();

    final escudoRival = (data['escudo_rival'] ?? '').toString();

    final golesLocal = int.tryParse((data['goles_local'] ?? 0).toString()) ?? 0;

    final golesVisita =
        int.tryParse((data['goles_visita'] ?? 0).toString()) ?? 0;

    final categoria = (data['categoria'] ?? '').toString();

    final eventosRaw = data['eventos'];

    final eventos = eventosRaw is List
        ? eventosRaw
              .whereType<Map>()
              .map((evento) => Map<String, dynamic>.from(evento))
              .toList()
              .reversed
              .toList()
        : <Map<String, dynamic>>[];

    String horaInicioTexto = '';

    if (_horaInicioReal != null) {
      final fecha = _horaInicioReal!.toDate();

      horaInicioTexto =
          '${fecha.hour}:'
          '${fecha.minute.toString().padLeft(2, '0')}hs';
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(
            top: 90,
            bottom: 30,
            left: 10,
            right: 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.config.colorPrimario.withValues(alpha: 0.4),
                const Color(0xFF121212),
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          child: Column(
            children: [
              Text(
                'CATEGORÍA $categoria'.toUpperCase(),
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
                    'Inicio: '
                    '$horaInicioTexto',
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
                            color: Colors.white.withValues(alpha: 0.05),
                            boxShadow: [
                              BoxShadow(
                                color: widget.config.colorPrimario.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: _logoClubLocal(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nombreClubLocal.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TABLERO
                  Column(
                    children: [
                      Text(
                        '$golesLocal - '
                        '$golesVisita',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Courier',
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorEstado(
                            _estado,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getColorEstado(
                              _estado,
                            ).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_estado == '1T' || _estado == '2T') ...[
                              AnimatedOpacity(
                                opacity: _titilar ? 1 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getColorEstado(_estado),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getColorEstado(_estado),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _estado == '1T' || _estado == '2T'
                                  ? '${_textoEstadoLargo(_estado)}'
                                        ' | '
                                        '$_tiempoTranscurrido'
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
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: escudoRival.isNotEmpty
                              ? Image.network(
                                  escudoRival,
                                  height: 70,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.shield,
                                      color: Colors.white24,
                                      size: 70,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.shield,
                                  color: Colors.white24,
                                  size: 70,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          rival.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ======================================================
        // EVENTOS
        // ======================================================
        Expanded(
          child: eventos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports, size: 60, color: Colors.white10),
                      SizedBox(height: 15),
                      Text(
                        'ESPERANDO EVENTOS...',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evento = eventos[index];

                    final esLocal = evento['equipo'] == 'local';

                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: esLocal
                                ? _construirTarjetaEvento(evento, true)
                                : const SizedBox(),
                          ),
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
                                      color: esLocal
                                          ? widget.config.colorPrimario
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    boxShadow: esLocal
                                        ? [
                                            BoxShadow(
                                              color: widget.config.colorPrimario
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: _iconoEventoOscuro(
                                    (evento['tipo'] ?? '').toString(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: !esLocal
                                ? _construirTarjetaEvento(evento, false)
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // TARJETAS DE EVENTOS
  // ============================================================

  Widget _construirTarjetaEvento(Map<String, dynamic> evento, bool esLocal) {
    final tipo = (evento['tipo'] ?? '').toString();

    final minuto = (evento['minuto'] ?? "0'").toString();

    final detalle = (evento['detalle'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(
        top: 15,
        bottom: 15,
        left: esLocal ? 15 : 0,
        right: esLocal ? 0 : 15,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(15),
        border: Border(
          left: esLocal
              ? BorderSide(color: widget.config.colorPrimario, width: 4)
              : BorderSide.none,
          right: !esLocal
              ? const BorderSide(color: Colors.white24, width: 4)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: esLocal
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: esLocal
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    if (estado == 'SUSPENDIDO') {
      return Colors.redAccent;
    }

    if (estado == 'ENTRETIEMPO') {
      return Colors.orangeAccent;
    }

    if (estado == 'FINALIZADO') {
      return Colors.grey;
    }

    return const Color(0xFF00FF66);
  }

  Widget _iconoEventoOscuro(String tipo) {
    if (tipo == 'gol') {
      return const Icon(Icons.sports_soccer, color: Colors.white, size: 18);
    }

    if (tipo == 'amarilla') {
      return const Icon(Icons.style, color: Colors.amberAccent, size: 18);
    }

    if (tipo == 'roja') {
      return const Icon(Icons.style, color: Colors.redAccent, size: 18);
    }

    return const Icon(Icons.info_outline, color: Colors.white38, size: 18);
  }

  String _textoEvento(String tipo) {
    if (tipo == 'gol') {
      return 'GOL';
    }

    if (tipo == 'amarilla') {
      return 'Amarilla';
    }

    if (tipo == 'roja') {
      return 'Roja';
    }

    return 'Evento';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'VIVO',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: _usaCentral ? _contenidoCentral() : _contenidoLegacy(),
    );
  }
}
