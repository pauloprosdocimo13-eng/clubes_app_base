import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';

class PantallaCalendarioUsuario extends StatefulWidget {
  final ConfiguracionApp config;
  final String espacioId; // ID de la cancha
  final String tituloEspacio; // Nombre (ej: Cancha 5)
  final String telefonoWsp; // Teléfono del club

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

class _PantallaCalendarioUsuarioState extends State<PantallaCalendarioUsuario> {
  DateTime _fechaSeleccionada = DateTime.now();
  bool _procesandoReserva = false; // Para evitar doble tap

  // Generamos horarios de 8 a 23:30 hs (cada 30 minutos)
  final List<String> _horarios = List.generate(
    32, // 16 horas * 2 turnos por hora
    (index) {
      int hora = 8 + (index ~/ 2); // División entera para sacar la hora
      String minutos = (index % 2 == 0)
          ? "00"
          : "30"; // Par es en punto, impar es y media
      return "$hora:$minutos";
    },
  );

  String get _fechaId =>
      "${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}";

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ), // Permitimos hoy
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.config.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  // LOGICA PRINCIPAL DE RESERVA
  void _reservarTurno(String hora) async {
    if (_procesandoReserva) return;
    setState(() => _procesandoReserva = true);

    try {
      // 1. Verificar si alguien nos ganó de mano en el último segundo
      final check = await FirebaseFirestore.instance
          .collection('reservas')
          .where('espacio_id', isEqualTo: widget.espacioId)
          .where('fecha', isEqualTo: _fechaId)
          .where('hora', isEqualTo: hora)
          .get();

      // Filtramos si hay alguna reserva válida (confirmada o pendiente reciente)
      bool ocupadoReal = false;
      final ahora = DateTime.now();

      for (var doc in check.docs) {
        String estado = doc['estado'] ?? 'confirmada';
        if (estado == 'confirmada') {
          ocupadoReal = true;
          break;
        }
        if (estado == 'pendiente') {
          Timestamp? creado = doc['creado_el'];
          if (creado != null) {
            final diferencia = ahora.difference(creado.toDate()).inMinutes;
            if (diferencia < 30) {
              // Si tiene menos de 30 min, está ocupada
              ocupadoReal = true;
              break;
            }
          }
        }
      }

      if (ocupadoReal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("¡Uy! Alguien acaba de reservar este horario."),
            ),
          );
        }
        setState(() => _procesandoReserva = false);
        return;
      }

      // 2. BLOQUEAMOS LA CANCHA (Estado Pendiente)
      await FirebaseFirestore.instance.collection('reservas').add({
        'espacio_id': widget.espacioId,
        'fecha': _fechaId,
        'hora': hora,
        'estado': 'pendiente', // <--- CLAVE: Pendiente
        'creado_el': FieldValue.serverTimestamp(), // <--- CLAVE: Hora exacta
        'espacio_nombre':
            widget.tituloEspacio, // Para facilitar lectura en admin
      });

      // 3. Abrimos WhatsApp (LÓGICA BLINDADA Y LIMPIA)
      String telefonoLimpio = widget.telefonoWsp.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      final mensaje =
          "Hola! Acabo de reservar en la App: *${widget.tituloEspacio}* para el día *$_fechaId* a las *$hora* hs. Quedó como 'Pendiente'. ¿Cómo hago la seña?";
      final url =
          "https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(mensaje)}";

      try {
        if (!await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No se pudo abrir WhatsApp, pero tu reserva ya quedó pendiente en el sistema.",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _procesandoReserva = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tituloEspacio),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // CABECERA
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: widget.config.colorPrimario),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Estás viendo el día:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
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
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("CAMBIAR"),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // LEYENDA DE COLORES
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _leyendaColor(Colors.green[100]!, "Libre"),
                const SizedBox(width: 15),
                _leyendaColor(Colors.orange[100]!, "Pendiente"),
                const SizedBox(width: 15),
                _leyendaColor(Colors.red[100]!, "Ocupado"),
              ],
            ),
          ),

          // LISTA DE HORARIOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .where('espacio_id', isEqualTo: widget.espacioId)
                  .where('fecha', isEqualTo: _fechaId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Analizamos qué horarios están ocupados y cuáles pendientes
                Set<String> ocupadasConfirmadas = {};
                Set<String> ocupadasPendientes = {};

                final ahora = DateTime.now();

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  String h = data['hora'];
                  String estado =
                      data['estado'] ??
                      'confirmada'; // Compatibilidad hacia atrás

                  if (estado == 'confirmada') {
                    ocupadasConfirmadas.add(h);
                  } else if (estado == 'pendiente') {
                    // Verificamos expiración (30 min)
                    Timestamp? creado = data['creado_el'];
                    if (creado != null) {
                      final diferencia = ahora
                          .difference(creado.toDate())
                          .inMinutes;
                      if (diferencia < 30) {
                        // Aún es válida la prioridad
                        ocupadasPendientes.add(h);
                      } else {
                        // Expiró: No la agregamos a ningún set, así que se verá LIBRE.
                      }
                    } else {
                      // Si no tiene fecha (error raro), asumimos pendiente reciente
                      ocupadasPendientes.add(h);
                    }
                  }
                }

                return ListView.builder(
                  itemCount: _horarios.length,
                  itemBuilder: (context, index) {
                    final hora = _horarios[index];

                    bool esConfirmada = ocupadasConfirmadas.contains(hora);
                    bool esPendiente = ocupadasPendientes.contains(hora);
                    bool ocupado = esConfirmada || esPendiente;

                    // Definimos colores según estado
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
                          "$hora hs",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: _buildBotonAccion(ocupado, esPendiente, hora),
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

  // Widget auxiliar para el botón o texto
  Widget _buildBotonAccion(bool ocupado, bool esPendiente, String hora) {
    if (ocupado) {
      if (esPendiente) {
        return const Text(
          "EN PROCESO...",
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
      } else {
        return const Text(
          "OCUPADO",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        );
      }
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
      ),
      onPressed: _procesandoReserva ? null : () => _reservarTurno(hora),
      child: const Text("RESERVAR"),
    );
  }

  Widget _leyendaColor(Color color, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
