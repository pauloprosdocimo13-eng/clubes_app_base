import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';

class PantallaAvisos extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAvisos({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('avisos')
            .where('deporte_id', isEqualTo: deporteId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          // --- ESPIONAJE ---
          print("--- DEBUG AVISOS ---");
          if (snapshot.hasError) {
            print("🔴 ERROR CRÍTICO AVISOS: ${snapshot.error}");
            // Si falta el índice, el link aparecerá en la consola o aquí:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SelectableText(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("🟡 AVISOS: 0 documentos encontrados.");
            print("REVISA FIREBASE: Colección 'avisos', campo 'deporte_id' == '$deporteId'");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    "No hay avisos recientes",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final avisos = snapshot.data!.docs;
          print("🟢 ÉXITO: ${avisos.length} avisos encontrados.");

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: avisos.length,
            itemBuilder: (context, index) {
              final data = avisos[index].data() as Map<String, dynamic>;
              final bool importante = data['importante'] ?? false;

              String fechaTexto = "";
              if (data['fecha'] != null) {
                Timestamp ts = data['fecha'];
                DateTime dt = ts.toDate();
                fechaTexto = "${dt.day}/${dt.month}/${dt.year}";
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: importante ? Colors.red : config.colorPrimario,
                        width: 5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data['titulo'] ?? 'Aviso',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: importante ? Colors.red : Colors.black87,
                                ),
                              ),
                            ),
                            if (importante)
                              const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fechaTexto,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const Divider(),
                        Text(
                          data['mensaje'] ?? '',
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
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