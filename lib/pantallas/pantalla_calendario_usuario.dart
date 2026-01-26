import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';

class PantallaCalendarioUsuario extends StatefulWidget {
  final ConfiguracionApp config;
  final String espacioId;     // ID de la cancha
  final String tituloEspacio; // Nombre (ej: Cancha 5)
  final String telefonoWsp;   // Teléfono del club

  const PantallaCalendarioUsuario({
    super.key,
    required this.config,
    required this.espacioId,
    required this.tituloEspacio,
    required this.telefonoWsp,
  });

  @override
  State<PantallaCalendarioUsuario> createState() => _PantallaCalendarioUsuarioState();
}

class _PantallaCalendarioUsuarioState extends State<PantallaCalendarioUsuario> {
  DateTime _fechaSeleccionada = DateTime.now();
  
  // Generamos horarios de 8 a 23 hs (Puedes ajustar esto según el club)
  final List<String> _horarios = List.generate(16, (index) => "${index + 8}:00");

  // Formato YYYY-MM-DD para la base de datos
  String get _fechaId => "${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2,'0')}-${_fechaSeleccionada.day.toString().padLeft(2,'0')}";

  // Selector de fecha seguro (No deja elegir el pasado)
  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(), // Bloqueamos fechas pasadas
      lastDate: DateTime.now().add(const Duration(days: 60)), // Max 2 meses adelante
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: widget.config.colorPrimario),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  // Acción al tocar un horario libre
  void _reservarTurno(String hora) async {
    // 1. Mensaje pre-armado
    final mensaje = "Hola! Vi en la App que *${widget.tituloEspacio}* está libre el día *$_fechaId* a las *$hora* hs. Quisiera reservarla.";
    
    // 2. Armamos la URL de WhatsApp
    final url = "https://wa.me/${widget.telefonoWsp}?text=${Uri.encodeComponent(mensaje)}";

    // 3. Lanzamos
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
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
          // --- CABECERA CON FECHA ---
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
                      const Text("Estás viendo el día:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _seleccionarFecha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario, 
                    foregroundColor: Colors.white
                  ),
                  child: const Text("CAMBIAR"),
                )
              ],
            ),
          ),
          
          const Divider(height: 1),

          // --- LISTA DE HORARIOS (VERDE / ROJO) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .where('espacio_id', isEqualTo: widget.espacioId)
                  .where('fecha', isEqualTo: _fechaId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Guardamos qué horas están ocupadas en un Set para búsqueda rápida
                Set<String> horasOcupadas = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  horasOcupadas.add(data['hora']);
                }

                return ListView.builder(
                  itemCount: _horarios.length,
                  itemBuilder: (context, index) {
                    final hora = _horarios[index];
                    final bool ocupado = horasOcupadas.contains(hora);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      elevation: 0,
                      color: ocupado ? Colors.red[50] : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: ocupado ? Colors.red[100]! : Colors.grey[300]!)
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ocupado ? Colors.red[100] : Colors.green[100],
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: ocupado ? Colors.red[800] : Colors.green[800],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          "$hora hs",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: ocupado 
                          ? const Text("OCUPADO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                elevation: 0,
                              ),
                              onPressed: () => _reservarTurno(hora),
                              child: const Text("RESERVAR"),
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