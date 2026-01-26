import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

class PantallaHistorialMinuto extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaHistorialMinuto({super.key, required this.config, required this.deporteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Partidos"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Consultamos la colección historial
        stream: FirebaseFirestore.instance
            .collection('historial_partidos')
            .where('deporte_id', isEqualTo: deporteId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aún no hay partidos finalizados en el historial."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              final rival = data['rival'] ?? 'Rival';
              final golesL = data['goles_local'] ?? 0;
              final golesV = data['goles_visita'] ?? 0;
              final categoria = data['categoria'] ?? '';
              final estado = data['estado'] ?? 'FINALIZADO';
              final motivo = data['motivo_suspension'];
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final eventos = List.from(data['eventos'] ?? []);

              // Formatear fecha simple
              String fechaTexto = fecha != null
                  ? "${fecha.day}/${fecha.month} - ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}hs"
                  : "";

              // --- DETALLE VISUAL: Solo poner "Cat." si es un número ---
              String textoCategoria = categoria;
              if (RegExp(r'^[0-9]+$').hasMatch(categoria)) {
                textoCategoria = "Cat: $categoria";
              }
              // --------------------------------------------------------

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.all(15),
                  // CABECERA DEL PARTIDO
                  title: Column(
                    children: [
                      Text("$fechaTexto - $textoCategoria", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // LOCAL
                          Expanded(child: Text(config.nombreApp, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                          // RESULTADO
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                                color: estado == 'SUSPENDIDO' ? Colors.orange : Colors.black,
                                borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                                "$golesL - $golesV",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                            ),
                          ),
                          // RIVAL
                          Expanded(child: Text(rival, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      if (estado == 'SUSPENDIDO')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("SUSPENDIDO: ${motivo ?? 'Sin motivo'}", style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  // DETALLE DE EVENTOS (AL DESPLEGAR)
                  children: [
                    const Divider(),
                    if (eventos.isEmpty)
                      const Padding(padding: EdgeInsets.all(10), child: Text("Sin incidencias registradas."))
                    else
                      ...eventos.map((evt) {
                        bool esLocal = evt['equipo'] == 'local';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            evt['tipo'] == 'gol' ? Icons.sports_soccer : Icons.style,
                            color: evt['tipo'] == 'gol' ? Colors.black : _colorTarjeta(evt['tipo']),
                            size: 20,
                          ),
                          title: Text("${evt['minuto']} - ${evt['tipo'].toString().toUpperCase()}"),
                          subtitle: Text(evt['detalle'] ?? ''),
                          trailing: Text(esLocal ? "LOCAL" : "VISITA", style: TextStyle(color: esLocal ? config.colorPrimario : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
                        );
                      }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _colorTarjeta(String tipo) {
    if (tipo == 'amarilla') return Colors.yellow[700]!;
    if (tipo == 'roja') return Colors.red;
    if (tipo == 'azul') return Colors.blue;
    return Colors.grey;
  }
}