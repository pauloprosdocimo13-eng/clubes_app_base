import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../socios/pantalla_acceso_socio.dart';

class PantallaPruebaCarnetPublico4F extends StatelessWidget {
  final ConfiguracionApp config;

  const PantallaPruebaCarnetPublico4F({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuSede · Prueba 4F-2F-B'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 72,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Carnet Digital público protegido',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Club: ${ContextoClub.nombreClub}\n'
                      'clubId: ${ContextoClub.clubId}\n'
                      'Origen: ${ServicioDatosClub.origenDescripcion}',
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        '✅ Esta prueba NO inicia sesión administrativa.\n'
                        '✅ El navegador NO lee la colección socios.\n'
                        '✅ El DNI se consulta mediante un endpoint controlado.\n'
                        '✅ Güemes continúa en Firebase Legacy.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaAccesoSocio(
                              config: config,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.badge),
                      label: const Text(
                        'ABRIR CARNET SIN LOGIN ADMIN',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
