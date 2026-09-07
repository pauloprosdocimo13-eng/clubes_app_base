import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_reservas_publicas.dart';
import 'pantalla_calendario_usuario.dart';

class PantallaReservas extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaReservas({
    super.key,
    required this.config,
  });

  Future<void> _verDisponibilidad(
    BuildContext context,
    EspacioPublico espacio,
    String telefonoWsp,
  ) async {
    if (telefonoWsp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aviso: El club no configuró un teléfono para reservas.',
          ),
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaCalendarioUsuario(
          config: config,
          espacioId: espacio.id,
          tituloEspacio: espacio.titulo,
          telefonoWsp: telefonoWsp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ServicioReservasPublicas();
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alquiler de Espacios · ${ContextoClub.nombreCorto}',
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<PortadaReservasPublica>(
        future: servicio.cargarPortada(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final portada = snapshot.data;

          if (portada == null || portada.espacios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_soccer,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No hay espacios cargados.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '(Pedile al admin que cree uno en el panel)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: portada.espacios.length,
            itemBuilder: (context, index) {
              final espacio = portada.espacios[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (espacio.fotoUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: Image.network(
                          espacio.fotoUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => Container(
                            height: 150,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.stadium,
                            size: 40,
                            color: color,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  espacio.titulo,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (espacio.precio.isNotEmpty)
                                Text(
                                  '\$${espacio.precio}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                            ],
                          ),
                          if (espacio.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              espacio.descripcion,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => _verDisponibilidad(
                                context,
                                espacio,
                                portada.telefonoWsp,
                              ),
                              icon: const Icon(Icons.calendar_month),
                              label: const Text(
                                'VER DISPONIBILIDAD Y RESERVAR',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
