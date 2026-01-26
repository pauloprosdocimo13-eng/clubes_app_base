import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_calendario_usuario.dart'; // <--- IMPORTANTE: Conectamos la nueva pantalla

class PantallaReservas extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaReservas({super.key, required this.config});

  // Función para navegar al calendario visual
  Future<void> _verDisponibilidad(BuildContext context, String espacioId, String titulo, String telefonoWsp) async {
    // Si el club no configuró teléfono, avisamos pero igual dejamos entrar para ver
    if (telefonoWsp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aviso: El club no configuró un teléfono para reservas.")));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaCalendarioUsuario(
          config: config,
          espacioId: espacioId,
          tituloEspacio: titulo,
          telefonoWsp: telefonoWsp, // Pasamos el teléfono a la siguiente pantalla
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alquiler de Espacios"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // 1. Primero leemos la configuración general para obtener el teléfono de reservas
        future: FirebaseFirestore.instance.collection('configuracion').doc('reservas').get(),
        builder: (context, snapshotConfig) {
          
          if (snapshotConfig.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String telefonoWsp = "";
          if (snapshotConfig.hasData && snapshotConfig.data!.exists) {
            final data = snapshotConfig.data!.data() as Map<String, dynamic>;
            telefonoWsp = data['telefono_wsp'] ?? "";
          }

          // 2. Luego mostramos la lista de espacios
          return StreamBuilder<QuerySnapshot>(
            // FIX IMPORTANTE: Quitamos el filtro 'activo' == true por ahora
            // para asegurar que se vean las canchas aunque no tengan ese campo configurado.
            stream: FirebaseFirestore.instance.collection('espacios').snapshots(),
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_soccer, size: 60, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text("No hay espacios cargados.", style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 5),
                      const Text("(Pedile al admin que cree uno en el panel)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final espacios = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: espacios.length,
                itemBuilder: (context, index) {
                  final data = espacios[index].data() as Map<String, dynamic>;
                  final espacioId = espacios[index].id;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FOTO DEL ESPACIO (Si tiene)
                        if (data['foto_url'] != null && data['foto_url'] != "")
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: Image.network(
                              data['foto_url'],
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c,o,s) => Container(height: 150, color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)),
                            ),
                          )
                        else
                          Container(
                            height: 100, 
                            decoration: BoxDecoration(
                              color: config.colorPrimario.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15))
                            ),
                            child: Center(child: Icon(Icons.stadium, size: 40, color: config.colorPrimario)),
                          ),
                        
                        // INFO
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(data['titulo'] ?? 'Espacio Sin Nombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (data['precio'] != null)
                                    Text("\$${data['precio']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
                                ],
                              ),
                              if (data['descripcion'] != null) ...[
                                const SizedBox(height: 5),
                                Text(data['descripcion'], style: TextStyle(color: Colors.grey[600])),
                              ],
                              const SizedBox(height: 15),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: config.colorPrimario, 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                  ),
                                  onPressed: () => _verDisponibilidad(context, espacioId, data['titulo'] ?? 'Cancha', telefonoWsp),
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text("VER DISPONIBILIDAD Y RESERVAR"),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}