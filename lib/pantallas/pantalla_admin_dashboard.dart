import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../configuracion/configuracion_app.dart';
import '../../configuracion/admin_permisos.dart'; // <--- IMPORTANTE
import '../tusede/configuracion/modulos_tusede.dart';
import '../tusede/servicios/servicio_modulos_tusede.dart';

// PANTALLAS ADMIN (Básicas)
import 'pantalla_admin_partidos.dart';
import 'pantalla_admin_jugadores.dart';
import 'pantalla_admin_avisos.dart';
import 'pantalla_admin_noticias.dart';
import 'pantalla_admin_publicidad.dart';
import 'pantalla_admin_deportes.dart';
import 'pantalla_admin_galeria.dart';

// MÓDULOS EXTRA (Gestión Avanzada)
import 'admin/pantalla_admin_socios.dart';
import 'admin/pantalla_admin_pagos_config.dart';
import 'admin/pantalla_admin_precios.dart';
import 'admin/pantalla_admin_finanzas.dart';
import 'admin/pantalla_admin_asistencia.dart';
import 'admin/pantalla_admin_espacios.dart';
import 'admin/pantalla_admin_calendario.dart';
import 'admin/pantalla_admin_rivales.dart';
import 'admin/pantalla_admin_minuto.dart';
import 'admin/pantalla_admin_tienda.dart';
import 'admin/pantalla_admin_sorteos.dart';
import 'admin/pantalla_admin_aviso_entrada.dart';
import 'admin/pantalla_admin_stream.dart';
import 'admin/pantalla_admin_scanner.dart';
import 'admin/prode/pantalla_admin_prode.dart';
import 'admin/votacion/pantalla_admin_votacion.dart';

// IMPORTAMOS LA PANTALLA DE USUARIOS Y LA NUEVA MATRIZ DE PERMISOS
import 'admin/pantalla_admin_usuarios.dart';
import 'admin/pantalla_admin_matriz_permisos.dart';
import 'admin/pantalla_admin_config_club.dart';

// IMPORTAMOS LA PIZARRA
import 'pantalla_pizarra_tactica.dart';

class PantallaAdminDashboard extends StatefulWidget {
  final ConfiguracionApp config;
  final String? deporteIdInicial;

  const PantallaAdminDashboard({
    super.key,
    required this.config,
    this.deporteIdInicial,
  });

  @override
  State<PantallaAdminDashboard> createState() => _PantallaAdminDashboardState();
}

class _PantallaAdminDashboardState extends State<PantallaAdminDashboard> {
  String _deporteSeleccionadoId = 'baby_h';
  String _deporteSeleccionadoNombre = 'Cargando...';

  // ROL DEL USUARIO
  String _rolUsuario = ''; // <--- AQUÍ GUARDAMOS EL ROL

  // VARIABLES DE CONTROL DE MÓDULOS (Configuración Global)
  bool _mostrarModuloSocios = false;
  bool _mostrarModuloReservas = false;
  bool _mostrarMinutoAMinuto = false;
  bool _mostrarTienda = false;
  bool _mostrarSorteos = false;
  bool _mostrarStream = false;
  bool _mostrarProde = false;
  bool _mostrarVotacion = false;
  bool _mostrarPizarra = false;

  List<Map<String, String>> _deportesDisponibles = [];

  @override
  void initState() {
    super.initState();
    if (widget.deporteIdInicial != null) {
      _deporteSeleccionadoId = widget.deporteIdInicial!;
    }
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    // 1. DESCARGAR MATRIZ DE PERMISOS DE FIREBASE
    await AdminPermisos.inicializarMatriz();

    // 2. CARGAR ROL DE SEGURIDAD
    String rol = await AdminPermisos.obtenerRol();

    // 3. CARGAR CONFIGURACIÓN
    await _cargarConfiguracionGlobal();

    if (mounted) {
      setState(() {
        _rolUsuario = rol;
      });
    }
  }

  Future<void> _cargarConfiguracionGlobal() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();
      if (doc.exists) {
        final data = doc.data()!;

        // A. CARGAR DEPORTES
        if (data.containsKey('menu_deportes')) {
          List<dynamic> menu = data['menu_deportes'];
          List<Map<String, String>> listaTemporal = [];
          for (var item in menu) {
            listaTemporal.add({
              'id': item['id'],
              'nombre': item['titulo'].toString().toUpperCase(),
            });
          }

          if (listaTemporal.isNotEmpty) {
            if (mounted) {
              setState(() {
                _deportesDisponibles = listaTemporal;
                final existe = _deportesDisponibles.any(
                  (d) => d['id'] == _deporteSeleccionadoId,
                );

                if (existe) {
                  final deporte = _deportesDisponibles.firstWhere(
                    (d) => d['id'] == _deporteSeleccionadoId,
                  );
                  _deporteSeleccionadoNombre = deporte['nombre']!;
                } else {
                  _deporteSeleccionadoId = listaTemporal[0]['id']!;
                  _deporteSeleccionadoNombre = listaTemporal[0]['nombre']!;
                }
              });
            }
          }
        }

        // B. VERIFICAR QUÉ MÓDULOS ESTÁN ACTIVOS (GLOBALMENTE)
        final modulos = data['modulos_activos'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          setState(() {
            _mostrarModuloSocios = modulos['institucional'] ?? false;
            _mostrarModuloReservas = modulos['reservas'] ?? false;
            _mostrarMinutoAMinuto = modulos['minuto_a_minuto'] ?? false;
            _mostrarTienda = modulos['tienda'] ?? false;
            _mostrarSorteos = modulos['sorteos'] ?? false;
            _mostrarStream = modulos['stream'] ?? false;
            _mostrarProde = modulos['prode'] ?? false;
            _mostrarVotacion = modulos['votacion'] ?? false;
            _mostrarPizarra = modulos['pizarra'] ?? false;
          });
        }
      }
    } catch (e) {
      print("Error cargando configuración: $e");
    }
  }

  void _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.of(context).pop();
  }

  // --- FUNCIÓN HELPER PARA VERIFICAR VISIBILIDAD ---
  // Combina si el módulo está activo globalmente Y si el usuario tiene permiso
  bool _puedeVer(
    String titulo, {
    bool moduloActivo = true,
    String? moduloTuSede,
  }) {
    // 1. Configuración Legacy: si el módulo está apagado, nadie lo ve.
    if (!moduloActivo) return false;

    // 2. Configuración central TuSede: solo puede restringir.
    // Si TuSede no pudo cargar su configuración, el servicio conserva Legacy.
    if (moduloTuSede != null &&
        !ServicioModulosTuSede.activo(moduloTuSede)) {
      return false;
    }

    // 3. Permisos Legacy por rol.
    return AdminPermisos.puedeVer(_rolUsuario, titulo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Control"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          // --- SELECTOR DE TIRA (Solo visible si tiene acceso a algun deporte) ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Trabajando sobre:",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                _deportesDisponibles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButton<String>(
                        value: _deporteSeleccionadoId,
                        isExpanded: true,
                        underline: Container(
                          height: 2,
                          color: widget.config.colorPrimario,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: widget.config.colorPrimario,
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _deportesDisponibles.map((dep) {
                          return DropdownMenuItem<String>(
                            value: dep['id'],
                            child: Text(dep['nombre']!),
                          );
                        }).toList(),
                        onChanged: (nuevoId) {
                          if (nuevoId != null) {
                            final nombre = _deportesDisponibles.firstWhere(
                              (d) => d['id'] == nuevoId,
                            )['nombre'];
                            setState(() {
                              _deporteSeleccionadoId = nuevoId;
                              _deporteSeleccionadoNombre = nombre!;
                            });
                          }
                        },
                      ),
              ],
            ),
          ),

          // --- MENÚ DE BOTONES ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- PIZARRA TÁCTICA ---
                if (_puedeVer("Pizarra Táctica", moduloActivo: _mostrarPizarra))
                  _TarjetaAdmin(
                    titulo: "Pizarra Táctica",
                    subtitulo: "Armar jugadas y estrategias",
                    icono: Icons.view_quilt_rounded,
                    color: Colors.teal,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaPizarraTactica(config: widget.config),
                        ),
                      );
                    },
                  ),

                // MINUTO A MINUTO
                if (_puedeVer(
                  "Consola en VIVO",
                  moduloActivo: _mostrarMinutoAMinuto,
                ))
                  _TarjetaAdmin(
                    titulo: "Consola en VIVO",
                    subtitulo: "Goles, Tiempo y Tarjetas",
                    icono: Icons.timer,
                    color: Colors.amber[800]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminMinuto(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                // STREAMING
                if (_puedeVer(
                  "Configurar Streaming",
                  moduloActivo: _mostrarStream,
                ))
                  _TarjetaAdmin(
                    titulo: "Configurar Streaming",
                    subtitulo: "Enlace del Vivo (YouTube/FB)",
                    icono: Icons.live_tv,
                    color: Colors.red[700]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminStream(config: widget.config),
                        ),
                      );
                    },
                  ),

                // PRODE
                if (_puedeVer(
                  "Gestión Prode",
                  moduloActivo: _mostrarProde,
                  moduloTuSede: ModulosTuSede.prode,
                ))
                  _TarjetaAdmin(
                    titulo: "Gestión Prode",
                    subtitulo: "Crear fechas y resultados",
                    icono: Icons.emoji_events,
                    color: Colors.deepOrange,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminProde(config: widget.config),
                        ),
                      );
                    },
                  ),

                // VOTACIÓN MVP
                if (_puedeVer(
                  "Votación Figura",
                  moduloActivo: _mostrarVotacion,
                  moduloTuSede: ModulosTuSede.votacion,
                ))
                  _TarjetaAdmin(
                    titulo: "Votación Figura",
                    subtitulo: "Elegir MVP del partido",
                    icono: Icons.how_to_vote,
                    color: Colors.amber[700]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminVotacion(config: widget.config),
                        ),
                      );
                    },
                  ),

                // TIENDA
                if (_puedeVer(
                  "Tienda Oficial",
                  moduloActivo: _mostrarTienda,
                  moduloTuSede: ModulosTuSede.productos,
                ))
                  _TarjetaAdmin(
                    titulo: "Tienda Oficial",
                    subtitulo: "Gestionar Productos y Precios",
                    icono: Icons.store,
                    color: Colors.purple,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminTienda(config: widget.config),
                        ),
                      );
                    },
                  ),

                // SORTEOS
                if (_puedeVer(
                  "Gestionar Rifas",
                  moduloActivo: _mostrarSorteos,
                  moduloTuSede: ModulosTuSede.sorteos,
                ))
                  _TarjetaAdmin(
                    titulo: "Gestionar Rifas",
                    subtitulo: "Crear sorteos y controlar números",
                    icono: Icons.local_activity,
                    color: Colors.pink,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminSorteos(config: widget.config),
                        ),
                      );
                    },
                  ),

                // INSTITUCIONAL (SOCIOS, PAGOS Y GESTIÓN)
                if (_mostrarModuloSocios) ...[
                  // 1. Asistencia
                  if (_puedeVer(
                    "Tomar Asistencia",
                    moduloTuSede: ModulosTuSede.asistencias,
                  ))
                    _TarjetaAdmin(
                      titulo: "Tomar Asistencia",
                      subtitulo: "Control diario de presentes",
                      icono: Icons.checklist,
                      color: Colors.cyan[700]!,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminAsistencia(config: widget.config),
                        ),
                      ),
                    ),

                  // 2. Finanzas
                  if (_puedeVer(
                    "Caja y Finanzas",
                    moduloTuSede: ModulosTuSede.finanzas,
                  ))
                    _TarjetaAdmin(
                      titulo: "Caja y Finanzas",
                      subtitulo: "Ingresos y Egresos del Club",
                      icono: Icons.attach_money,
                      color: Colors.green[900]!,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminFinanzas(config: widget.config),
                        ),
                      ),
                    ),

                  // 3. Escáner
                  if (_puedeVer(
                    "Escanear Ingreso",
                    moduloTuSede: ModulosTuSede.socios,
                  ))
                    _TarjetaAdmin(
                      titulo: "Escanear Ingreso",
                      subtitulo: "Validar QR de Carnet Digital",
                      icono: Icons.qr_code_scanner,
                      color: Colors.green[800]!,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminScanner(config: widget.config),
                        ),
                      ),
                    ),

                  // 4. Padrón
                  if (_puedeVer(
                    "Padrón Socios",
                    moduloTuSede: ModulosTuSede.socios,
                  ))
                    _TarjetaAdmin(
                      titulo: "Padrón Socios",
                      subtitulo: "Altas, bajas y cuotas",
                      icono: Icons.badge,
                      color: Colors.indigo,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminSocios(config: widget.config),
                        ),
                      ),
                    ),

                  // 6. Precios
                  if (_puedeVer(
                    "Config. Precios",
                    moduloTuSede: ModulosTuSede.cuotas,
                  ))
                    _TarjetaAdmin(
                      titulo: "Config. Precios",
                      subtitulo: "Valor cuota mensual",
                      icono: Icons.price_change,
                      color: Colors.blueAccent,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminPrecios(config: widget.config),
                        ),
                      ),
                    ),

                  // 7. Pagos Config
                  if (_puedeVer(
                    "Configurar Pagos",
                    moduloTuSede: ModulosTuSede.cuotas,
                  ))
                    _TarjetaAdmin(
                      titulo: "Configurar Pagos",
                      subtitulo: "Link de MP, CBU y Alias",
                      icono: Icons.credit_card,
                      color: Colors.teal,
                      alPresionar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              PantallaAdminPagosConfig(config: widget.config),
                        ),
                      ),
                    ),
                ],

                // RESERVAS
                if (_mostrarModuloReservas) ...[
                  if (_puedeVer(
                    "Agenda / Reservas",
                    moduloTuSede: ModulosTuSede.reservas,
                  ))
                    _TarjetaAdmin(
                      titulo: "Agenda / Reservas",
                      subtitulo: "Ver ocupación y anotar",
                      icono: Icons.edit_calendar,
                      color: Colors.deepPurple[700]!,
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PantallaAdminCalendario(config: widget.config),
                          ),
                        );
                      },
                    ),

                  if (_puedeVer(
                    "Configurar Espacios",
                    moduloTuSede: ModulosTuSede.espacios,
                  ))
                    _TarjetaAdmin(
                      titulo: "Configurar Espacios",
                      subtitulo: "Crear Canchas, Salones, Buffet",
                      icono: Icons.settings_input_component,
                      color: Colors.deepPurple[300]!,
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PantallaAdminEspacios(config: widget.config),
                          ),
                        );
                      },
                    ),
                ],

                const Divider(height: 30),

                // DEPORTIVOS
                if (_puedeVer(
                  "Gestionar Partidos",
                  moduloTuSede: ModulosTuSede.partidos,
                ))
                  _TarjetaAdmin(
                    titulo: "Gestionar Partidos",
                    subtitulo: "Resultados para $_deporteSeleccionadoNombre",
                    icono: Icons.scoreboard,
                    color: Colors.blue[800]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminPartidos(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Rivales y Ubicaciones",
                  moduloTuSede: ModulosTuSede.deportes,
                ))
                  _TarjetaAdmin(
                    titulo: "Rivales y Ubicaciones",
                    subtitulo: "Direcciones para $_deporteSeleccionadoNombre",
                    icono: Icons.map,
                    color: Colors.red[700]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminRivales(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Gestionar Plantel",
                  moduloTuSede: ModulosTuSede.jugadores,
                ))
                  _TarjetaAdmin(
                    titulo: "Gestionar Plantel",
                    subtitulo: "Jugadores de $_deporteSeleccionadoNombre",
                    icono: Icons.groups,
                    color: Colors.green[700]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminJugadores(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Avisos Urgentes",
                  moduloTuSede: ModulosTuSede.avisos,
                ))
                  _TarjetaAdmin(
                    titulo: "Avisos Urgentes",
                    subtitulo: "Alertas para $_deporteSeleccionadoNombre",
                    icono: Icons.campaign,
                    color: Colors.orange[800]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminAvisos(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                // GLOBALES
                if (_puedeVer(
                  "Publicar Noticia",
                  moduloTuSede: ModulosTuSede.noticias,
                ))
                  _TarjetaAdmin(
                    titulo: "Publicar Noticia",
                    subtitulo: "Novedades Generales del Club",
                    icono: Icons.newspaper,
                    color: Colors.indigo,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminNoticias(config: widget.config),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Configurar Pop-up",
                  moduloTuSede: ModulosTuSede.avisos,
                ))
                  _TarjetaAdmin(
                    titulo: "Configurar Pop-up",
                    subtitulo: "Aviso emergente al iniciar la app",
                    icono: Icons.campaign_outlined,
                    color: Colors.teal[800]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminAvisoEntrada(config: widget.config),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Subir Fotos",
                  moduloTuSede: ModulosTuSede.galeria,
                ))
                  _TarjetaAdmin(
                    titulo: "Subir Fotos",
                    subtitulo: "Administrar Galería y Álbumes",
                    icono: Icons.photo_library,
                    color: Colors.pink[600]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminGaleria(
                            config: widget.config,
                            deporteId: _deporteSeleccionadoId,
                          ),
                        ),
                      );
                    },
                  ),

                if (_puedeVer("Publicidad"))
                  _TarjetaAdmin(
                    titulo: "Publicidad",
                    subtitulo: "Sponsors Generales",
                    icono: Icons.monetization_on,
                    color: Colors.purple[700]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminPublicidad(config: widget.config),
                        ),
                      );
                    },
                  ),

                if (_puedeVer(
                  "Configurar Tiras",
                  moduloTuSede: ModulosTuSede.deportes,
                ))
                  _TarjetaAdmin(
                    titulo: "Configurar Tiras",
                    subtitulo: "Agregar o quitar deportes",
                    icono: Icons.settings,
                    color: Colors.blueGrey,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminDeportes(config: widget.config),
                        ),
                      );
                    },
                  ),

                // SEGURIDAD / USUARIOS (Solo el Súper Admin ve esto)
                if (_rolUsuario == 'admin') ...[
                  const Divider(height: 30),
                  _TarjetaAdmin(
                    titulo: 'Configuración del Club',
                    subtitulo: 'Actividades, contacto y portal',
                    icono: Icons.tune,
                    color: Colors.indigo,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminConfigClub(config: widget.config),
                        ),
                      );
                    },
                  ),
                  _TarjetaAdmin(
                    titulo: "Gestión de Usuarios",
                    subtitulo: "Crear cuentas y asignar roles",
                    icono: Icons.admin_panel_settings,
                    color: Colors.red[900]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PantallaAdminUsuarios(config: widget.config),
                        ),
                      );
                    },
                  ),

                  // NUEVA TARJETA: MATRIZ DE PERMISOS
                  _TarjetaAdmin(
                    titulo: "Matriz de Permisos",
                    subtitulo: "Configurar accesos por rol",
                    icono: Icons.security,
                    color: Colors.blueGrey[900]!,
                    alPresionar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaAdminMatrizPermisos(
                            config: widget.config,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAdmin extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback alPresionar;

  const _TarjetaAdmin({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
