import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_aviso_entrada.dart';
import '../servicios/servicio_version.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../widgets/estado_carga.dart';
import '../widgets/logo_club_tusede.dart';

// PANTALLAS DE NAVEGACIÓN
import 'pantalla_inicio.dart';
import 'pantalla_login_admin.dart';
import 'pantalla_reservas.dart';
import 'socios/pantalla_acceso_socio.dart';

class PantallaSeleccion extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaSeleccion({super.key, required this.config});

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _DatosSeleccion {
  final List<Map<String, dynamic>> deportes;
  final bool mostrarInstitucional;
  final bool mostrarReservas;

  const _DatosSeleccion({
    required this.deportes,
    required this.mostrarInstitucional,
    required this.mostrarReservas,
  });
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  late Future<_DatosSeleccion> _futureDatos;

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

  @override
  void initState() {
    super.initState();

    _futureDatos = _cargarDatos();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ServicioVersion.mostrarBloqueoSiCorresponde(context);

      if (mounted) {
        await ServicioAvisoEntrada.mostrarSiCorresponde(context, widget.config);
      }
    });
  }

  // ============================================================
  // CARGA DE CONFIGURACIÓN
  // ============================================================

  Future<_DatosSeleccion> _cargarDatos() async {
    if (_usaCentral) {
      return _cargarDatosCentral();
    }

    return _cargarDatosLegacy();
  }

  Future<_DatosSeleccion> _cargarDatosCentral() async {
    final configuracion = await ServicioContenidoPublico.cargarConfiguracion();

    return _DatosSeleccion(
      deportes: List<Map<String, dynamic>>.from(configuracion.menuDeportes),
      mostrarInstitucional: configuracion.moduloActivo('institucional'),
      mostrarReservas: configuracion.moduloActivo('reservas'),
    );
  }

  Future<_DatosSeleccion> _cargarDatosLegacy() async {
    final doc = await FirebaseFirestore.instance
        .collection('configuracion')
        .doc('general')
        .get();

    final deportes = <Map<String, dynamic>>[];

    bool mostrarInstitucional = false;
    bool mostrarReservas = false;

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;

      final menuRaw = data['menu_deportes'];

      if (menuRaw is List) {
        for (final item in menuRaw) {
          if (item is Map) {
            deportes.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final modulosRaw = data['modulos_activos'];

      if (modulosRaw is Map) {
        mostrarInstitucional = modulosRaw['institucional'] == true;

        mostrarReservas = modulosRaw['reservas'] == true;
      }
    }

    return _DatosSeleccion(
      deportes: deportes,
      mostrarInstitucional: mostrarInstitucional,
      mostrarReservas: mostrarReservas,
    );
  }

  void _recargar() {
    setState(() {
      _futureDatos = _cargarDatos();
    });
  }

  // ============================================================
  // ADMIN
  // ============================================================

  Future<void> _abrirAdmin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaLoginAdmin(config: widget.config),
      ),
    );

    if (mounted) {
      _recargar();
    }
  }

  // ============================================================
  // NAVEGACIÓN
  // ============================================================

  void _abrirDeporte(Map<String, dynamic> deporte) {
    final id = (deporte['id'] ?? '').toString().trim();

    final titulo = (deporte['titulo'] ?? id).toString().trim();

    if (id.isEmpty) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaInicio(
          config: widget.config,
          deporteId: id,
          deporteTitulo: titulo.isEmpty ? id : titulo,
        ),
      ),
    );
  }

  // ============================================================
  // ICONOS
  // ============================================================

  IconData _obtenerIcono(String id) {
    final idNormalizado = id.toLowerCase();

    if (idNormalizado.contains('baby')) {
      return Icons.sports_soccer;
    }

    if (idNormalizado.contains('futsal')) {
      return Icons.sports_handball;
    }

    if (idNormalizado.contains('futbol') || idNormalizado.contains('fútbol')) {
      return Icons.sports_soccer;
    }

    if (idNormalizado.contains('patin') || idNormalizado.contains('patín')) {
      return Icons.sports_gymnastics;
    }

    if (idNormalizado.contains('boxeo')) {
      return Icons.sports_mma;
    }

    if (idNormalizado.contains('taekwondo')) {
      return Icons.sports_martial_arts;
    }

    return Icons.star;
  }

  // ============================================================
  // PANTALLA VACÍA
  // ============================================================

  Widget _sinDeportes(Color colorPrimario) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_soccer, size: 50, color: Colors.white24),
          const SizedBox(height: 10),
          const Text(
            'No hay categorías activas.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: _abrirAdmin,
            child: const Text('Ingresar al Panel de Admin'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
            style: TextButton.styleFrom(
              foregroundColor: colorPrimario.computeLuminance() > 0.5
                  ? Colors.black87
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA DE DEPORTES
  // ============================================================

  Widget _listaDeportes(
    List<Map<String, dynamic>> deportes,
    Color colorPrimario,
  ) {
    if (deportes.isEmpty) {
      return _sinDeportes(colorPrimario);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: deportes.length,
      itemBuilder: (context, index) {
        final deporte = deportes[index];

        final id = (deporte['id'] ?? '').toString();

        final titulo = (deporte['titulo'] ?? id).toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colorPrimario,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
            onPressed: () {
              _abrirDeporte(deporte);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_obtenerIcono(id)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    titulo.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MÓDULOS INSTITUCIONALES
  // ============================================================

  Widget _modulosExtras({
    required bool mostrarInstitucional,
    required bool mostrarReservas,
  }) {
    final hayModulosExtras = mostrarInstitucional || mostrarReservas;

    if (!hayModulosExtras) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'INSTITUCIONAL / SERVICIOS',
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaReservas(config: widget.config),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month),
                  SizedBox(width: 10),
                  Text(
                    'ALQUILER DE CANCHAS / SALÓN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (mostrarInstitucional) const SizedBox(height: 10),
          ],
          if (mostrarInstitucional)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaAccesoSocio(config: widget.config),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge),
                  SizedBox(width: 10),
                  Text(
                    'ACCESO SOCIOS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorPrimario = ContextoClub.colorPrimario;

    final colorSecundario = ContextoClub.colorSecundario;

    final colorFondoSuperior = Color.alphaBlend(
      Colors.black.withAlpha(170),
      colorSecundario,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorFondoSuperior, colorPrimario.withValues(alpha: 0.88)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_DatosSeleccion>(
            future: _futureDatos,
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
                  onReintentar: _recargar,
                );
              }

              final datos =
                  snapshot.data ??
                  const _DatosSeleccion(
                    deportes: [],
                    mostrarInstitucional: false,
                    mostrarReservas: false,
                  );

              return Column(
                children: [
                  // ==================================================
                  // ENCABEZADO
                  // ==================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        LogoClubTuSede(
                          config: widget.config,
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white24,
                          ),
                          tooltip: 'Administración',
                          onPressed: _abrirAdmin,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Seleccioná una categoría',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // DEPORTES / TIRAS
                  // ==================================================
                  Expanded(
                    child: _listaDeportes(datos.deportes, colorPrimario),
                  ),

                  // ==================================================
                  // SERVICIOS
                  // ==================================================
                  _modulosExtras(
                    mostrarInstitucional: datos.mostrarInstitucional,
                    mostrarReservas: datos.mostrarReservas,
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
