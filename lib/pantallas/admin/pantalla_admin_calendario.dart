import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para saber quién cobró
import '../../configuracion/configuracion_app.dart';

class PantallaAdminCalendario extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminCalendario({super.key, required this.config});

  @override
  State<PantallaAdminCalendario> createState() =>
      _PantallaAdminCalendarioState();
}

class _PantallaAdminCalendarioState extends State<PantallaAdminCalendario> {
  // Estado
  String? _espacioSeleccionadoId;
  DateTime _fechaSeleccionada = DateTime.now();

  // Generamos horarios de 8 a 23 hs
  final List<String> _horarios = List.generate(
    16,
    (index) => "${index + 8}:00",
  );

  // ID de fecha simple para la BD: YYYY-MM-DD
  String _formatearFecha(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String get _fechaId => _formatearFecha(_fechaSeleccionada);

  // --- 1. SELECTOR DE FECHA ---
  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: widget.config.colorPrimario,
            colorScheme: ColorScheme.light(
              primary: widget.config.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  // --- 2. DIÁLOGO PARA CREAR/EDITAR RESERVA ---
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

    // Variables de estado del diálogo
    bool repetirAnual = false;
    bool registrarEnCaja =
        false; // <--- NUEVO: Checkbox para impactar en finanzas

    bool esFijoExistente = datosActuales?['es_fijo'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                reservaId == null ? "Nueva Reserva" : "Editar Reserva",
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
                    ),

                    // CAMPO SEÑA CON LÓGICA DE CAJA
                    TextField(
                      controller: seniaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Pago / Seña",
                        icon: Icon(Icons.money_off),
                      ),
                      onChanged: (val) {
                        // Si escribe algo en seña, habilitamos opción de caja
                        setStateDialog(() {});
                      },
                    ),

                    // CHECKBOX CAJA (Solo aparece si hay monto en Seña)
                    if (seniaCtrl.text.isNotEmpty &&
                        double.tryParse(seniaCtrl.text)! > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.green),
                        ),
                        child: CheckboxListTile(
                          value: registrarEnCaja,
                          activeColor: Colors.green,
                          title: const Text(
                            "Ingresar dinero a Caja",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            "Genera un movimiento en Finanzas.",
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) =>
                              setStateDialog(() => registrarEnCaja = v!),
                        ),
                      ),

                    TextField(
                      controller: notaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nota (Opcional)",
                        icon: Icon(Icons.note),
                      ),
                    ),

                    // --- SECCIÓN CREAR TURNO FIJO (Solo al crear uno nuevo) ---
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

                    // --- AVISO SI ES TURNO FIJO YA EXISTENTE ---
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
                // BOTÓN BORRAR
                if (reservaId != null)
                  TextButton(
                    onPressed: () async {
                      // CASO 1: Turno normal -> Borrado simple
                      if (!esFijoExistente) {
                        await FirebaseFirestore.instance
                            .collection('reservas')
                            .doc(reservaId)
                            .delete();
                        Navigator.pop(ctx);
                        return;
                      }

                      // CASO 2: Turno Fijo -> Preguntar
                      showDialog(
                        context: context,
                        builder: (alertCtx) => AlertDialog(
                          title: const Text("Liberar Turno Fijo"),
                          content: const Text(
                            "Este turno se repite todo el año.\n¿Qué deseas hacer?",
                          ),
                          actions: [
                            TextButton(
                              child: const Text("SOLO ESTE DÍA"),
                              onPressed: () async {
                                Navigator.pop(alertCtx);
                                await FirebaseFirestore.instance
                                    .collection('reservas')
                                    .doc(reservaId)
                                    .delete();
                                Navigator.pop(ctx);
                              },
                            ),
                            TextButton(
                              child: const Text(
                                "LIBERAR TODO EL AÑO",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(alertCtx);
                                try {
                                  WriteBatch batch = FirebaseFirestore.instance
                                      .batch();

                                  // Buscamos TODOS los fijos de este horario/cancha
                                  final snapshot = await FirebaseFirestore
                                      .instance
                                      .collection('reservas')
                                      .where(
                                        'espacio_id',
                                        isEqualTo: _espacioSeleccionadoId,
                                      )
                                      .where('hora', isEqualTo: hora)
                                      .where('es_fijo', isEqualTo: true)
                                      .get();

                                  int cont = 0;
                                  for (var doc in snapshot.docs) {
                                    final data = doc.data();
                                    final fechaDoc = data['fecha'] as String;

                                    // Filtramos MANUALMENTE (en memoria) fechas futuras o igual a hoy
                                    if (fechaDoc.compareTo(_fechaId) >= 0) {
                                      batch.delete(doc.reference);
                                      cont++;
                                    }
                                  }

                                  await batch.commit();
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Se liberaron $cont fechas futuras.",
                                        ),
                                      ),
                                    );
                                  Navigator.pop(ctx);
                                } catch (e) {
                                  print("Error borrando fijos: $e");
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      "LIBERAR TURNO",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                // BOTÓN GUARDAR
                ElevatedButton(
                  onPressed: () async {
                    if (clienteCtrl.text.isEmpty) return;

                    final dataBase = {
                      'espacio_id': _espacioSeleccionadoId,
                      'hora': hora,
                      'cliente': clienteCtrl.text,
                      'precio': precioCtrl.text,
                      'senia': seniaCtrl.text,
                      'nota': notaCtrl.text,
                      'creado_el': FieldValue.serverTimestamp(),
                      'es_fijo': repetirAnual,
                    };

                    try {
                      // 1. REGISTRO EN CAJA (Si corresponde)
                      if (registrarEnCaja) {
                        double monto = double.tryParse(seniaCtrl.text) ?? 0;
                        if (monto > 0) {
                          await FirebaseFirestore.instance
                              .collection('movimientos')
                              .add({
                                'tipo': 'ingreso',
                                'monto': monto,
                                'concepto':
                                    "Alquiler Cancha - ${clienteCtrl.text} - Fecha $_fechaId $hora hs",
                                'metodo': 'Efectivo',
                                'categoria': 'Alquileres',
                                'fecha': FieldValue.serverTimestamp(),
                                'origen': 'calendario',
                                'admin_email':
                                    FirebaseAuth.instance.currentUser?.email ??
                                    'Admin',
                              });
                        }
                      }

                      // 2. GUARDADO DE RESERVA
                      if (reservaId == null) {
                        // --- NUEVA RESERVA ---
                        if (repetirAnual) {
                          // Crear Anual (Batch)
                          WriteBatch batch = FirebaseFirestore.instance.batch();
                          DateTime fechaIteracion = _fechaSeleccionada;
                          int anioActual = _fechaSeleccionada.year;

                          while (fechaIteracion.year == anioActual) {
                            DocumentReference docRef = FirebaseFirestore
                                .instance
                                .collection('reservas')
                                .doc();
                            final dataCopia = Map<String, dynamic>.from(
                              dataBase,
                            );
                            dataCopia['fecha'] = _formatearFecha(
                              fechaIteracion,
                            );
                            batch.set(docRef, dataCopia);
                            fechaIteracion = fechaIteracion.add(
                              const Duration(days: 7),
                            );
                          }
                          await batch.commit();
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "¡Turnos fijos creados hasta fin de año!",
                                ),
                              ),
                            );
                        } else {
                          // Reserva Única
                          final dataUnica = Map<String, dynamic>.from(dataBase);
                          dataUnica['fecha'] = _fechaId;
                          await FirebaseFirestore.instance
                              .collection('reservas')
                              .add(dataUnica);
                        }
                      } else {
                        // --- EDITAR ---
                        final dataEditar = Map<String, dynamic>.from(dataBase);
                        dataEditar['fecha'] = _fechaId;
                        dataEditar['es_fijo'] = esFijoExistente;
                        await FirebaseFirestore.instance
                            .collection('reservas')
                            .doc(reservaId)
                            .update(dataEditar);
                      }

                      Navigator.pop(ctx);
                      if (registrarEnCaja && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Reserva guardada e Ingreso registrado en Caja.",
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error al guardar: $e")),
                        );
                    }
                  },
                  child: const Text("GUARDAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Canchas"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // A. SELECTOR DE ESPACIO
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
                  return const Text("No hay canchas/espacios creados.");

                if (_espacioSeleccionadoId == null && espacios.isNotEmpty) {
                  Future.microtask(() {
                    if (mounted)
                      setState(
                        () => _espacioSeleccionadoId = espacios.first.id,
                      );
                  });
                }

                return DropdownButtonFormField<String>(
                  value: _espacioSeleccionadoId,
                  decoration: const InputDecoration(
                    labelText: "Seleccionar Cancha/Espacio",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  items: espacios.map((e) {
                    final data = e.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: e.id,
                      child: Text(data['titulo'] ?? 'Espacio'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _espacioSeleccionadoId = v),
                );
              },
            ),
          ),

          // B. SELECTOR DE FECHA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fecha: $_fechaId",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.config.colorPrimario,
                  ),
                ),
                IconButton(
                  onPressed: _seleccionarFecha,
                  icon: const Icon(Icons.calendar_month, size: 30),
                  color: widget.config.colorPrimario,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // C. GRILLA DE HORARIOS
          Expanded(
            child: _espacioSeleccionadoId == null
                ? const Center(child: Text("Seleccioná un espacio arriba"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reservas')
                        .where('espacio_id', isEqualTo: _espacioSeleccionadoId)
                        .where('fecha', isEqualTo: _fechaId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      Map<String, DocumentSnapshot> reservasDelDia = {};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        reservasDelDia[data['hora']] = doc;
                      }

                      return ListView.builder(
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

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            color: estaOcupado
                                ? Colors.red[50]
                                : Colors.green[50],
                            child: ListTile(
                              leading: Icon(
                                Icons.access_time,
                                color: estaOcupado ? Colors.red : Colors.green,
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
                                ],
                              ),
                              subtitle: Text(
                                estaOcupado
                                    ? "${datosReserva?['cliente']} (${datosReserva?['nota'] ?? ''})"
                                    : "DISPONIBLE",
                                style: TextStyle(
                                  color: estaOcupado
                                      ? Colors.red[900]
                                      : Colors.green[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Icon(
                                estaOcupado
                                    ? Icons.edit
                                    : Icons.add_circle_outline,
                                color: estaOcupado
                                    ? Colors.orange
                                    : Colors.green,
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
          ),
        ],
      ),
    );
  }
}
