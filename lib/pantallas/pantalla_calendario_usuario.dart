import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_reservas_publicas.dart';

class PantallaCalendarioUsuario extends StatefulWidget {
  final ConfiguracionApp config;
  final String espacioId;
  final String tituloEspacio;
  final String telefonoWsp;

  const PantallaCalendarioUsuario({
    super.key,
    required this.config,
    required this.espacioId,
    required this.tituloEspacio,
    required this.telefonoWsp,
  });

  @override
  State<PantallaCalendarioUsuario> createState() =>
      _PantallaCalendarioUsuarioState();
}

class _PantallaCalendarioUsuarioState
    extends State<PantallaCalendarioUsuario> {
  DateTime _fechaSeleccionada = DateTime.now();
  bool _procesandoReserva = false;
  int _refresh = 0;

  final ServicioReservasPublicas _servicio =
      ServicioReservasPublicas();

  final List<String> _horarios = List.generate(
    32,
    (index) {
      final hora = 8 + (index ~/ 2);
      final minutos = (index % 2 == 0) ? '00' : '30';
      return '$hora:$minutos';
    },
  );

  String get _fechaId =>
      '${_fechaSeleccionada.year}-'
      '${_fechaSeleccionada.month.toString().padLeft(2, '0')}-'
      '${_fechaSeleccionada.day.toString().padLeft(2, '0')}';

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: ContextoClub.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
        _refresh++;
      });
    }
  }

  Future<Map<String, String>> _cargarDisponibilidad() {
    // Cada incremento de _refresh fuerza un nuevo build y una nueva consulta.
    return _servicio.cargarDisponibilidad(
      espacioId: widget.espacioId,
      fecha: _fechaId,
    );
  }

  Future<void> _reservarTurno(String hora) async {
    if (_procesandoReserva) return;

    setState(() => _procesandoReserva = true);

    try {
      await _servicio.reservarTurno(
        espacioId: widget.espacioId,
        espacioNombre: widget.tituloEspacio,
        fecha: _fechaId,
        hora: hora,
      );

      if (!mounted) return;

      setState(() => _refresh++);

      final telefonoLimpio = widget.telefonoWsp.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      if (telefonoLimpio.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La reserva quedó pendiente. '
              'El club todavía no configuró WhatsApp.',
            ),
          ),
        );
        return;
      }

      final mensaje =
          'Hola! Acabo de reservar en la App: '
          '*${widget.tituloEspacio}* para el día '
          '*$_fechaId* a las *$hora* hs. '
          "Quedó como 'Pendiente'. ¿Cómo hago la seña?";

      final url =
          'https://wa.me/$telefonoLimpio'
          '?text=${Uri.encodeComponent(mensaje)}';

      try {
        if (!await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.platformDefault,
          );
        }
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir WhatsApp, '
              'pero tu reserva ya quedó pendiente en el sistema.',
            ),
          ),
        );
      }
    } on ReservaPublicaException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );

      setState(() => _refresh++);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos completar la reserva. '
            'Intentá nuevamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesandoReserva = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tituloEspacio),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: color),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estás viendo el día:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_fechaSeleccionada.day}/'
                        '${_fechaSeleccionada.month}/'
                        '${_fechaSeleccionada.year}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _seleccionarFecha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CAMBIAR'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _leyendaColor(Colors.green[100]!, 'Libre'),
                const SizedBox(width: 15),
                _leyendaColor(Colors.orange[100]!, 'Pendiente'),
                const SizedBox(width: 15),
                _leyendaColor(Colors.red[100]!, 'Ocupado'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, String>>(
              future: _cargarDisponibilidad(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() => _refresh++),
                            child: const Text('REINTENTAR'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final estados =
                    snapshot.data ?? <String, String>{};

                return ListView.builder(
                  itemCount: _horarios.length,
                  itemBuilder: (context, index) {
                    final hora = _horarios[index];
                    final estado = estados[hora];

                    final esConfirmada = estado == 'confirmada';
                    final esPendiente = estado == 'pendiente';
                    final ocupado = esConfirmada || esPendiente;

                    Color bgColor = Colors.white;
                    Color borderColor = Colors.grey[300]!;
                    Color iconColor = Colors.green[800]!;
                    Color iconBg = Colors.green[100]!;

                    if (esConfirmada) {
                      bgColor = Colors.red[50]!;
                      borderColor = Colors.red[100]!;
                      iconColor = Colors.red[800]!;
                      iconBg = Colors.red[100]!;
                    } else if (esPendiente) {
                      bgColor = Colors.orange[50]!;
                      borderColor = Colors.orange[100]!;
                      iconColor = Colors.orange[800]!;
                      iconBg = Colors.orange[100]!;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      elevation: 0,
                      color: bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: borderColor),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '$hora hs',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: _buildBotonAccion(
                          ocupado,
                          esPendiente,
                          hora,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion(
    bool ocupado,
    bool esPendiente,
    String hora,
  ) {
    if (ocupado) {
      if (esPendiente) {
        return const Text(
          'EN PROCESO...',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
      }

      return const Text(
        'OCUPADO',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
      ),
      onPressed: _procesandoReserva
          ? null
          : () => _reservarTurno(hora),
      child: const Text('RESERVAR'),
    );
  }

  Widget _leyendaColor(Color color, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
