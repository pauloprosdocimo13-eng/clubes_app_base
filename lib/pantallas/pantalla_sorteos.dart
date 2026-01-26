import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_detalle_sorteo.dart';

class PantallaSorteos extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaSorteos({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sorteos Activos"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sorteos')
            .where('activo', isEqualTo: true) // Solo activas
            .orderBy('fecha_sorteo', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_activity_outlined, size: 70, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("No hay sorteos activos por ahora.", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              final titulo = data['titulo'] ?? 'Gran Rifa';
              final premio = data['premio'] ?? 'Sorpresa';
              final precio = data['precio'] ?? 0;
              final vendidos = (data['numeros_vendidos'] as List?)?.length ?? 0;
              final total = data['cantidad_numeros'] ?? 100;
              final porcentaje = total > 0 ? vendidos / total : 0.0;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaDetalleSorteo(
                      config: config,
                      sorteoId: id,
                      dataSorteo: data,
                    )));
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: config.colorSecundario.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10)
                              ),
                              child: Icon(Icons.confirmation_number, color: config.colorSecundario, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text(premio, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                ],
                              ),
                            ),
                            Text("\$$precio", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: config.colorPrimario)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        // BARRA DE PROGRESO
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: porcentaje,
                            backgroundColor: Colors.grey[200],
                            color: porcentaje > 0.8 ? Colors.red : Colors.green, // Rojo si quedan pocos
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Números vendidos: $vendidos de $total",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: config.colorPrimario,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaDetalleSorteo(
                                config: config,
                                sorteoId: id,
                                dataSorteo: data,
                              )));
                            },
                            child: const Text("ELEGIR MI NÚMERO"),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}