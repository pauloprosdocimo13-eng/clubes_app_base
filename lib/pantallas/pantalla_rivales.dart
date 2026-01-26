import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';

class PantallaRivales extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaRivales({
    super.key,
    required this.config,
    required this.deporteId,
  });

  Future<void> _abrirMapa(BuildContext context, String? urlManual, String? direccionEscrita) async {
    String urlFinal = "";

    // 1. Prioridad: Link explícito puesto por el admin
    if (urlManual != null && urlManual.isNotEmpty && (urlManual.startsWith('http') || urlManual.startsWith('https'))) {
      urlFinal = urlManual;
    }
    // 2. Fallback: Si no hay link, buscamos por la dirección escrita
    else if (direccionEscrita != null && direccionEscrita.isNotEmpty) {
      // Codificamos la dirección (ej: "Cavia 2" -> "Cavia%202")
      final query = Uri.encodeComponent(direccionEscrita);
      urlFinal = "https://www.google.com/maps/search/?api=1&query=$query";
    }

    if (urlFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos de ubicación para este club.")));
      return;
    }

    try {
      await launchUrl(Uri.parse(urlFinal), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el mapa.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rivales de la Zona"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rivales')
            .where('deporte_id', isEqualTo: deporteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text("No hay rivales cargados.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Sin Nombre';
              final direccion = data['direccion'] ?? 'Dirección no disponible';
              final esTechado = data['es_techado'] ?? false;
              final escudo = data['escudo_url'] ?? '';

              // Datos para el mapa
              final urlMapa = data['mapa_url'];
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  // AL TOCAR: Pasamos tanto el link manual como la dirección escrita
                  onTap: () => _abrirMapa(context, urlMapa, direccion),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        // ESCUDO
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                            image: escudo.isNotEmpty
                                ? DecorationImage(image: NetworkImage(escudo), fit: BoxFit.cover)
                                : null,
                          ),
                          child: escudo.isEmpty ? const Icon(Icons.shield, color: Colors.grey) : null,
                        ),
                        const SizedBox(width: 15),
                        
                        // INFO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(direccion, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // ETIQUETA TECHADO / AIRE LIBRE
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: esTechado ? Colors.green[50] : Colors.orange[50],
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: esTechado ? Colors.green : Colors.orange),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(esTechado ? Icons.roofing : Icons.sunny, 
                                        size: 12, color: esTechado ? Colors.green[800] : Colors.orange[800]),
                                    const SizedBox(width: 5),
                                    Text(
                                      esTechado ? "CANCHA TECHADA" : "AIRE LIBRE",
                                      style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold,
                                          color: esTechado ? Colors.green[800] : Colors.orange[800]
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        // FLECHA
                        const Icon(Icons.chevron_right, color: Colors.grey),
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