import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminCalendario extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminCalendario({super.key, required this.config});

  @override
  State<PantallaAdminCalendario> createState() =>
      _PantallaAdminCalendarioState();
}

class _PantallaAdminCalendarioState extends State<PantallaAdminCalendario> {
  String? _espacioSeleccionadoId;
  DateTime _fechaSeleccionada = DateTime.now();
  late DateTime _mesVisualizado;

  // CORRECCIÓN 1: Turnos cada media hora (de 8:00 a 23:30)
  final List<String> _horarios = List.generate(32, (index) {
    int hora = 8 + (index ~/ 2);
    String minutos = (index % 2 == 0) ? "00" : "30";
    return "$hora:$minutos";
  });

  @override
  void initState() {
    super.initState();
    _mesVisualizado = DateTime(
      _fechaSeleccionada.year,
      _fechaSeleccionada.month,
      1,
    );
  }

  String _formatearFecha(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String get _fechaId => _formatearFecha(_fechaSeleccionada);
  String get _hoyId => _formatearFecha(DateTime.now());

  String _nombreMes(int mes) {
    const meses = [
      "Enero",
      "Febrero",
      "Marzo",
      "Abril",
      "Mayo",
      "Junio",
      "Julio",
      "Agosto",
      "Septiembre",
      "Octubre",
      "Noviembre",
      "Diciembre",
    ];
    return meses[mes - 1];
  }

  // --- DIÁLOGO PARA AGREGAR FACTURA / VENCIMIENTO ---
  void _dialogoNuevoVencimiento() {
    final tituloCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Anotar Vencimiento para $_fechaId"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              decoration: const InputDecoration(
                labelText: "Servicio (Ej: Luz, Agua, Internet)",
                icon: Icon(Icons.receipt_long),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monto a pagar (Opcional)",
                icon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (tituloCtrl.text.isEmpty) return;

              await FirebaseFirestore.instance.collection('vencimientos').add({
                'titulo': tituloCtrl.text,
                'monto': montoCtrl.text,
                'fecha': _fechaId,
                'pagado': false,
                'creado_el': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("¡Vencimiento agendado!")),
                );
              }
            },
            child: const Text("GUARDAR VENCIMIENTO"),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO PARA RESERVAS ---
  void _reservar(
    String hora,
    String? reservaId,
    Map<String, dynamic>? datosActuales,
  ) {
    if (_espacioSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primero seleccioná un espacio.")),
      );
      return;
    }

    final clienteCtrl = TextEditingController(
      text: datosActuales?['cliente'] ?? '',
    );
    final notaCtrl = TextEditingController(text: datosActuales?['nota'] ?? '');
    final precioCtrl = TextEditingController(
      text: datosActuales?['precio'] ?? '',
    );
    final seniaCtrl = TextEditingController(
      text: datosActuales?['senia'] ?? '',
    );

    bool repetirAnual = false;
    bool esFijoExistente = datosActuales?['es_fijo'] ?? false;
    double seniaGuardadaPreviamente =
        double.tryParse(datosActuales?['senia'] ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double precio = double.tryParse(precioCtrl.text) ?? 0;
            double senia = double.tryParse(seniaCtrl.text) ?? 0;
            double saldo = precio - senia;

            return AlertDialog(
              title: Text(
                reservaId == null ? "Nueva Reserva" : "Administrar Reserva",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Fecha: $_fechaId - Hora: $hora",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: clienteCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre Cliente",
                        icon: Icon(Icons.person),
                      ),
                    ),
                    TextField(
                      controller: precioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Precio Total",
                        icon: Icon(Icons.attach_money),
                      ),
                      onChanged: (v) => setStateDialog(() {}),
                    ),
                    TextField(
                      controller: seniaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Pago / Seña",
                        icon: Icon(Icons.money_off),
                      ),
                      onChanged: (v) => setStateDialog(() {}),
                    ),
                    if (precio > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: saldo > 0 ? Colors.red[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: saldo > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Saldo a cobrar:"),
                                Text(
                                  "\$${saldo.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: saldo > 0
                                        ? Colors.red
                                        : Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                            if (reservaId != null && saldo > 0) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.payments),
                                  label: Text(
                                    "COBRAR RESTANTE (\$${saldo.toStringAsFixed(0)})",
                                  ),
                                  onPressed: () async {
                                    bool confirmar =
                                        await showDialog(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text(
                                              "Confirmar Cobro",
                                            ),
                                            content: Text(
                                              "¿Confirmas que recibiste \$${saldo.toStringAsFixed(0)} en efectivo?\n\nSe generará un ingreso en caja.",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text("Cancelar"),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text(
                                                  "CONFIRMAR COBRO",
                                                ),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;

                                    if (!confirmar) return;
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('movimientos')
                                          .add({
                                            'tipo': 'ingreso',
                                            'monto': saldo,
                                            'concepto':
                                                "Saldo Alquiler - ${clienteCtrl.text} - $_fechaId $hora hs",
                                            'metodo': 'Efectivo',
                                            'categoria': 'Alquileres',
                                            'fecha':
                                                FieldValue.serverTimestamp(),
                                            'origen': 'calendario_admin',
                                            'admin_email':
                                                FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.email ??
                                                'Admin',
                                          });
                                      await FirebaseFirestore.instance
                                          .collection('reservas')
                                          .doc(reservaId)
                                          .update({
                                            'senia': precioCtrl.text,
                                            'saldo_pendiente': 0,
                                          });
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "¡Cobro registrado y saldo actualizado!",
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text("Error: $e")),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    TextField(
                      controller: notaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nota (Opcional)",
                        icon: Icon(Icons.note),
                      ),
                    ),
                    if (reservaId == null) ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            "Fijar turno todo el año",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            "Repite este día y horario hasta el 31/12.",
                            style: TextStyle(fontSize: 12),
                          ),
                          value: repetirAnual,
                          activeColor: Colors.orange,
                          onChanged: (val) {
                            setStateDialog(() => repetirAnual = val ?? false);
                          },
                        ),
                      ),
                    ],
                    if (reservaId != null && esFijoExistente) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 16,
                              color: Colors.deepOrange,
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                "Este es un turno fijo anual.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (reservaId != null)
                  TextButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('reservas')
                          .doc(reservaId)
                          .delete();
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "BORRAR",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (clienteCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Falta nombre del cliente"),
                        ),
                      );
                      return;
                    }

                    // --- VALIDACIÓN DE SEGURIDAD ANTI-PISADAS ---
                    if (reservaId == null) {
                      final verificacion = await FirebaseFirestore.instance
                          .collection('reservas')
                          .where('espacio_id', isEqualTo: _espacioSeleccionadoId)
                          .where('fecha', isEqualTo: _fechaId)
                          .where('hora', isEqualTo: hora)
                          .get();

                      if (verificacion.docs.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error: Ya se generó una reserva en este horario justo recién. Actualice la pantalla."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    double precioFinal = double.tryParse(precioCtrl.text) ?? 0;
                    double seniaFinal = double.tryParse(seniaCtrl.text) ?? 0;
                    double saldoFinal = precioFinal - seniaFinal;

                    final dataBase = {
                      'espacio_id': _espacioSeleccionadoId,
                      'hora': hora,
                      'cliente': clienteCtrl.text,
                      'precio': precioCtrl.text,
                      'senia': seniaCtrl.text,
                      'saldo_pendiente': saldoFinal,
                      'nota': notaCtrl.text,
                      'estado': 'confirmada',
                      'creado_el': FieldValue.serverTimestamp(),
                      'es_fijo': repetirAnual || esFijoExistente,
                    };

                    try {
                      double ingresoRealAhora =
                          seniaFinal - seniaGuardadaPreviamente;
                      if (ingresoRealAhora > 0) {
                        await FirebaseFirestore.instance
                            .collection('movimientos')
                            .add({
                              'tipo': 'ingreso',
                              'monto': ingresoRealAhora,
                              'concepto':
                                  "Reserva Cancha - ${clienteCtrl.text} - $_fechaId $hora hs",
                              'metodo': 'Efectivo',
                              'categoria': 'Alquileres',
                              'fecha': FieldValue.serverTimestamp(),
                              'origen': 'calendario_admin',
                              'admin_email':
                                  FirebaseAuth.instance.currentUser?.email ??
                                  'Admin',
                            });
                      }

                      if (reservaId == null) {
                        if (repetirAnual) {
                          DateTime fechaIteradora = _fechaSeleccionada;
                          int anioActual = fechaIteradora.year;
                          WriteBatch batch = FirebaseFirestore.instance.batch();
                          int contadorReservas = 0;

                          while (fechaIteradora.year == anioActual) {
                            String idGenerado = FirebaseFirestore.instance
                                .collection('reservas')
                                .doc()
                                .id;
                            DocumentReference docRef = FirebaseFirestore
                                .instance
                                .collection('reservas')
                                .doc(idGenerado);

                            final dataGuardar = Map<String, dynamic>.from(
                              dataBase,
                            );
                            dataGuardar['fecha'] = _formatearFecha(
                              fechaIteradora,
                            );
                            batch.set(docRef, dataGuardar);

                            contadorReservas++;
                            fechaIteradora = fechaIteradora.add(
                              const Duration(days: 7),
                            ); // Sumamos 1 semana
                          }
                          await batch.commit(); // Ejecutamos todo junto

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "¡Se generaron $contadorReservas reservas fijas!",
                                ),
                                backgroundColor: Colors.green[700],
                              ),
                            );
                          }
                        } else {
                          final dataGuardar = Map<String, dynamic>.from(
                            dataBase,
                          );
                          dataGuardar['fecha'] = _fechaId;
                          await FirebaseFirestore.instance
                              .collection('reservas')
                              .add(dataGuardar);
                        }
                      } else {
                        final dataEditar = Map<String, dynamic>.from(dataBase);
                        dataEditar['fecha'] = _fechaId;
                        dataEditar['es_fijo'] = esFijoExistente;
                        await FirebaseFirestore.instance
                            .collection('reservas')
                            .doc(reservaId)
                            .update(dataEditar);
                      }
                      Navigator.pop(ctx);
                      if (mounted && !repetirAnual)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("¡Guardado!"),
                            backgroundColor: Colors.green[700],
                          ),
                        );
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: const Text("CONFIRMAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MOTOR DEL CALENDARIO ---
  Widget _buildCalendarioNativo(BuildContext context) {
    int primerDiaSemana = DateTime(
      _mesVisualizado.year,
      _mesVisualizado.month,
      1,
    ).weekday;
    int diasAntes = primerDiaSemana - 1;
    int diasMes = DateTime(
      _mesVisualizado.year,
      _mesVisualizado.month + 1,
      0,
    ).day;
    double anchoPantalla = MediaQuery.of(context).size.width;
    double aspectRatioCalculado = anchoPantalla > 800
        ? 3.0
        : (anchoPantalla > 500 ? 1.8 : 1.1);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vencimientos')
            .where('pagado', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshotVencimientos) {
          Set<String> diasConVencimientos = {};
          if (snapshotVencimientos.hasData) {
            for (var doc in snapshotVencimientos.data!.docs) {
              diasConVencimientos.add(doc['fecha'] ?? '');
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservas')
                .where('espacio_id', isEqualTo: _espacioSeleccionadoId)
                .snapshots(),
            builder: (context, snapshotReservas) {
              Set<String> diasConReservas = {};
              if (snapshotReservas.hasData) {
                String prefijoMes =
                    "${_mesVisualizado.year}-${_mesVisualizado.month.toString().padLeft(2, '0')}";
                for (var doc in snapshotReservas.data!.docs) {
                  String fechaStr = doc['fecha'] ?? '';
                  if (fechaStr.startsWith(prefijoMes))
                    diasConReservas.add(fechaStr);
                }
              }

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(
                          () => _mesVisualizado = DateTime(
                            _mesVisualizado.year,
                            _mesVisualizado.month - 1,
                            1,
                          ),
                        ),
                      ),
                      Text(
                        "${_nombreMes(_mesVisualizado.month)} ${_mesVisualizado.year}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(
                          () => _mesVisualizado = DateTime(
                            _mesVisualizado.year,
                            _mesVisualizado.month + 1,
                            1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: widget.config.colorPrimario,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ["L", "M", "M", "J", "V", "S", "D"]
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                        right: BorderSide(color: Colors.grey[300]!, width: 0.5),
                        bottom: BorderSide(
                          color: Colors.grey[300]!,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: diasAntes + diasMes,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: aspectRatioCalculado,
                      ),
                      itemBuilder: (context, index) {
                        if (index < diasAntes)
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 0.5,
                              ),
                              color: Colors.grey[50],
                            ),
                          );

                        int dia = index - diasAntes + 1;
                        DateTime fechaCelda = DateTime(
                          _mesVisualizado.year,
                          _mesVisualizado.month,
                          dia,
                        );
                        String fechaCeldaId = _formatearFecha(fechaCelda);

                        Color colorPrimarioResaltado = Colors.blue[700]!;
                        bool isSelected = _fechaId == fechaCeldaId;
                        bool isToday = _hoyId == fechaCeldaId;
                        bool hasReserva = diasConReservas.contains(
                          fechaCeldaId,
                        );
                        bool hasVencimiento = diasConVencimientos.contains(
                          fechaCeldaId,
                        );

                        return InkWell(
                          onTap: () =>
                              setState(() => _fechaSeleccionada = fechaCelda),
                          child: Container(
                            decoration: BoxDecoration(
                              border: isToday && !isSelected
                                  ? Border.all(
                                      color: colorPrimarioResaltado.withOpacity(
                                        0.5,
                                      ),
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: Colors.grey[300]!,
                                      width: 0.5,
                                    ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorPrimarioResaltado
                                    : Colors.white,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    "$dia",
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (hasReserva)
                                          Container(
                                            width: (anchoPantalla / 7) * 0.4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.orange[800],
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        if (hasReserva && hasVencimiento)
                                          const SizedBox(width: 2),
                                        if (hasVencimiento)
                                          Container(
                                            width: (anchoPantalla / 7) * 0.2,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agenda / Reservas"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text("Anotar Gasto/Vencimiento"),
        onPressed: _dialogoNuevoVencimiento,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- AVISO DE "HOY VENCE" ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vencimientos')
                  .where('fecha', isEqualTo: _hoyId)
                  .where('pagado', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const SizedBox();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red[800],
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notification_important,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "¡ATENCIÓN! VENCIMIENTOS DE HOY",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ...snapshot.data!.docs.map(
                        (doc) => Text(
                          "👉 ${doc['titulo']} (\$${doc['monto']})",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // A. SELECTOR DE ESPACIO GENERAL OBLIGATORIO
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey[200],
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('espacios')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final espacios = snapshot.data!.docs;

                  if (espacios.isEmpty)
                    return const Text("No hay canchas creadas.");

                  return DropdownButtonFormField<String>(
                    value: _espacioSeleccionadoId,
                    decoration: const InputDecoration(
                      labelText: "Seleccione un Espacio...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: espacios
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              (e.data() as Map)['titulo'] ?? 'Espacio',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _espacioSeleccionadoId = v),
                  );
                },
              ),
            ),

            // B. CABECERA: CALENDARIO MENSUAL
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                leading: Icon(
                  Icons.calendar_month,
                  color: widget.config.colorPrimario,
                  size: 28,
                ),
                title: const Text(
                  "Calendario de Ocupación",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  "Naranja: Reservas | Rojo: Facturas/Gastos",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                children: [_buildCalendarioNativo(context)],
              ),
            ),

            const Divider(height: 1),

            // --- CUEVA DE VENCIMIENTOS DEL DÍA SELECCIONADO ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vencimientos')
                  .where('fecha', isEqualTo: _fechaId)
                  .where('pagado', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const SizedBox();
                return Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🧾 Vencimientos para este día:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ...snapshot.data!.docs.map(
                        (doc) => Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.red),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.receipt_long,
                              color: Colors.red,
                            ),
                            title: Text(
                              doc['titulo'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Monto: \$${doc['monto']}"),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              child: const Text("MARCAR PAGADO"),
                              onPressed: () async {
                                bool confirmar =
                                    await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Confirmar Pago"),
                                        content: Text(
                                          "¿Confirmas que pagaste \$${doc['monto']} por ${doc['titulo']}?\n\nSe registrará un EGRESO en la caja.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text("Cancelar"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text("CONFIRMAR"),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;

                                if (!confirmar) return;

                                try {
                                  double montoEgreso =
                                      double.tryParse(
                                        doc['monto'].toString(),
                                      ) ??
                                      0;

                                  await FirebaseFirestore.instance
                                      .collection('movimientos')
                                      .add({
                                        'tipo': 'egreso',
                                        'monto': montoEgreso,
                                        'concepto':
                                            "Pago de servicio/gasto: ${doc['titulo']}",
                                        'metodo': 'Efectivo',
                                        'categoria': 'Servicios',
                                        'fecha': FieldValue.serverTimestamp(),
                                        'origen': 'calendario_admin',
                                        'admin_email':
                                            FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.email ??
                                            'Admin',
                                      });

                                  await FirebaseFirestore.instance
                                      .collection('vencimientos')
                                      .doc(doc.id)
                                      .update({'pagado': true});

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "¡Pago registrado en caja exitosamente!",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // C. LEYENDA Y GRILLA DE CANCHAS
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.grey[100],
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

            _espacioSeleccionadoId == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Text(
                        "⬆️ Por favor, seleccioná un Espacio para ver su agenda.",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reservas')
                        .where('espacio_id', isEqualTo: _espacioSeleccionadoId)
                        .where('fecha', isEqualTo: _fechaId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      Map<String, DocumentSnapshot> reservasDelDia = {};
                      for (var doc in snapshot.data!.docs) {
                        reservasDelDia[(doc.data() as Map)['hora']] = doc;
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _horarios.length,
                        itemBuilder: (context, index) {
                          final hora = _horarios[index];
                          final bool estaOcupado = reservasDelDia.containsKey(
                            hora,
                          );
                          final datosReserva = estaOcupado
                              ? reservasDelDia[hora]!.data()
                                    as Map<String, dynamic>
                              : null;
                          final bool esFijo = datosReserva?['es_fijo'] ?? false;
                          String estado =
                              datosReserva?['estado'] ?? 'confirmada';
                          bool esPendiente = estado == 'pendiente';

                          Color colorFondo = !estaOcupado
                              ? Colors.green[50]!
                              : (esPendiente
                                    ? Colors.orange[50]!
                                    : Colors.red[50]!);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: estaOcupado
                                    ? (esPendiente ? Colors.orange : Colors.red)
                                    : Colors.green,
                                width: 0.5,
                              ),
                            ),
                            color: colorFondo,
                            child: ListTile(
                              leading: Icon(
                                Icons.access_time,
                                color: !estaOcupado
                                    ? Colors.green
                                    : (esPendiente
                                          ? Colors.orange
                                          : Colors.red),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    "$hora hs",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (esFijo) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "FIJO",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (esPendiente) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "PENDIENTE",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                estaOcupado
                                    ? "${datosReserva?['cliente'] ?? 'Anónimo'} (${datosReserva?['nota'] ?? ''})"
                                    : "DISPONIBLE",
                                style: TextStyle(
                                  color: !estaOcupado
                                      ? Colors.green[900]
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Icon(
                                estaOcupado
                                    ? Icons.edit
                                    : Icons.add_circle_outline,
                                color: estaOcupado ? Colors.grey : Colors.green,
                              ),
                              onTap: () => _reservar(
                                hora,
                                estaOcupado ? reservasDelDia[hora]!.id : null,
                                datosReserva,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}