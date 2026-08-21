import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../servicios/servicio_aviso_entrada.dart';
import '../servicios/servicio_version.dart';
import '../widgets/estado_carga.dart';
// PANTALLAS DE NAVEGACIÓN
import 'pantalla_inicio.dart';
import 'socios/pantalla_acceso_socio.dart';
import 'pantalla_reservas.dart';
import 'pantalla_login_admin.dart';

class PantallaSeleccion extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaSeleccion({super.key, required this.config});

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ServicioVersion.mostrarBloqueoSiCorresponde(context);
      if (mounted) {
        await ServicioAvisoEntrada.mostrarSiCorresponde(context, widget.config);
      }
    });
  }

  // --- MÉTODOS AUXILIARES ---
  IconData _obtenerIcono(String id) {
    if (id.contains('baby')) return Icons.sports_soccer;
    if (id.contains('futsal')) return Icons.sports_handball;
    return Icons.star;
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ETAPA 4E-1D - IDENTIDAD DINAMICA TUSEDE
    // ============================================================
    final Color colorPrimario = ContextoClub.colorPrimario;
    final Color colorSecundario = ContextoClub.colorSecundario;

    final Color colorFondoSuperior = Color.alphaBlend(
      Colors.black.withAlpha(170),
      colorSecundario,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorFondoSuperior,
              colorPrimario.withOpacity(0.88),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('configuracion')
                .doc('general')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return EstadoCarga(
                  estado: TipoEstadoPantalla.cargando,
                  colorPrimario: colorPrimario,
                );
              }

              if (snapshot.hasError) {
                return EstadoCarga(
                  estado: TipoEstadoPantalla.error,
                  colorPrimario: colorPrimario,
                  onReintentar: () => setState(() {}),
                );
              }

              // Preparamos variables por defecto
              List<dynamic> listaDeportes = [];
              bool mostrarInstitucional = false;
              bool mostrarReservas = false;

              // 2. SI HAY DATOS, LOS LEEMOS
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                listaDeportes = data['menu_deportes'] as List<dynamic>? ?? [];

                final modulos =
                    data['modulos_activos'] as Map<String, dynamic>? ?? {};
                mostrarInstitucional = modulos['institucional'] ?? false;
                mostrarReservas = modulos['reservas'] ?? false;
              }

              final bool hayModulosExtras =
                  mostrarInstitucional || mostrarReservas;

              return Column(
                children: [
                  // --- ENCABEZADO CON "PUERTA TRASERA" ADMIN ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Espacio vacío para equilibrar
                        const SizedBox(width: 40),

                        // LOGO CENTRAL
                        Image.asset(widget.config.rutaLogo, height: 100),

                        // BOTÓN DE ACCESO ADMIN (Salvavidas)
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white24,
                          ), // Sutil
                          onPressed: () {
                            // Navegamos directo al Login de Admin
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PantallaLoginAdmin(config: widget.config),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "Seleccioná una categoría",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- LISTA DE DEPORTES ---
                  Expanded(
                    child: listaDeportes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sports_soccer,
                                  size: 50,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "No hay categorías activas.",
                                  style: TextStyle(color: Colors.white54),
                                ),
                                const SizedBox(height: 5),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PantallaLoginAdmin(
                                              config: widget.config,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Ingresar al Panel de Admin",
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: listaDeportes.length,
                            itemBuilder: (context, index) {
                              final deporte =
                                  listaDeportes[index] as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: colorPrimario,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 5,
                                  ),
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PantallaInicio(
                                          config: widget.config,
                                          deporteId: deporte['id'],
                                          deporteTitulo: deporte['titulo'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_obtenerIcono(deporte['id'])),
                                      const SizedBox(width: 10),
                                      Text(
                                        deporte['titulo']
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // --- SECCIÓN INFERIOR (MÓDULOS) ---
                  if (hayModulosExtras)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "INSTITUCIONAL / SERVICIOS",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 15),

                          if (mostrarReservas) ...[
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal[800],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PantallaReservas(config: widget.config),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month),
                                  SizedBox(width: 10),
                                  Text(
                                    "ALQUILER DE CANCHAS / SALÓN",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (mostrarInstitucional)
                              const SizedBox(height: 10),
                          ],

                          if (mostrarInstitucional)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PantallaAccesoSocio(
                                      config: widget.config,
                                    ),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.badge),
                                  SizedBox(width: 10),
                                  Text(
                                    "ACCESO SOCIOS",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
