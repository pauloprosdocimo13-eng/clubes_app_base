import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../widgets/boton_menu.dart';

// Importamos el widget de sugerencias
import '../widgets/dialogo_sugerencias.dart';

// Importamos todas las pantallas principales
import 'pantalla_noticias.dart';
import 'pantalla_resultados.dart';
import 'pantalla_jugadores.dart';
import 'pantalla_galeria.dart';
import 'pantalla_avisos.dart';
import 'pantalla_login_admin.dart';
import 'pantalla_rivales.dart';
import 'pantalla_posiciones_web.dart';
import 'socios/pantalla_acceso_socio.dart';
import '../widgets/selector_tira_bottom_sheet.dart';

// Importamos los Módulos Extra
import 'pantalla_minuto_a_minuto.dart';
import 'pantalla_historial_minuto.dart';
import 'pantalla_tienda.dart';
import 'pantalla_sorteos.dart';
import 'prode/pantalla_prode_usuario.dart';
import 'votacion/pantalla_votacion_usuario.dart';
import 'package:clubes_app_base/widgets/etiqueta_version.dart';

class PantallaInicio extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String deporteTitulo;

  const PantallaInicio({
    super.key,
    required this.config,
    required this.deporteId,
    required this.deporteTitulo,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  // VARIABLES PARA LA OPTIMIZACIÓN DE FIREBASE
  bool _cargandoConfig = true;
  bool _moduloMinuto = false;
  bool _moduloTienda = false;
  bool _moduloSorteos = false;
  bool _moduloStream = false;
  bool _moduloProde = false;
  bool _moduloVotacion = false;
  bool _moduloInstitucional = false;
  List<String> _categoriasDelDeporte = [];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionGeneral(); // Cargamos esto UNA SOLA VEZ
  }

  // OPTIMIZACIÓN: Leemos la configuración estática con .get() en lugar de .snapshots()
  Future<void> _cargarConfiguracionGeneral() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final modulos = data['modulos_activos'] as Map<String, dynamic>? ?? {};

        setState(() {
          _moduloMinuto = modulos['minuto_a_minuto'] ?? false;
          _moduloTienda = modulos['tienda'] ?? false;
          _moduloSorteos = modulos['sorteos'] ?? false;
          _moduloStream = modulos['stream'] ?? false;
          _moduloProde = modulos['prode'] ?? false;
          _moduloVotacion = modulos['votacion'] ?? false;
          _moduloInstitucional = modulos['institucional'] ?? false;

          final menuDeportes = List.from(data['menu_deportes'] ?? []);
          final deporteData = menuDeportes.firstWhere(
            (element) => element['id'] == widget.deporteId,
            orElse: () => <String, dynamic>{},
          );
          if (deporteData is Map && deporteData.containsKey('categorias')) {
            _categoriasDelDeporte = List<String>.from(deporteData['categorias']);
          }
          _cargandoConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoConfig = false);
      }
    }
  }

  void _navegarA(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
  }

  Future<void> _lanzarURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No se pudo abrir: $urlString")));
      }
    }
  }

  Future<void> _abrirTablaPosiciones() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Buscando tabla de posiciones..."), duration: Duration(seconds: 1)),
    );
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('enlaces').get();
      if (doc.exists && doc.data() != null) {
        final String? url = doc.data()![widget.deporteId];
        if (url != null && url.isNotEmpty) {
          if (mounted) {
            _navegarA(
              PantallaPosicionesWeb(
                config: widget.config,
                url: url,
                titulo: "Posiciones ${widget.deporteTitulo}",
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link no configurado")));
          }
        }
      }
    } catch (e) {
      print("Error buscando posiciones: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ETAPA 4E-1 - IDENTIDAD VISUAL DINAMICA TUSEDE
    // ============================================================
    // ContextoClub ya fue inicializado desde ConfiguracionApp y,
    // si TuSede Central respondió correctamente, contiene la
    // identidad remota del club. Sus getters de color mantienen
    // fallback automático a los valores Legacy.
    final String nombreClub = ContextoClub.nombreClub.trim().isNotEmpty
        ? ContextoClub.nombreClub.trim()
        : widget.config.nombreApp;
    final String lemaClub = ContextoClub.lema.trim();
    final Color colorPrimario = ContextoClub.colorPrimario;
    final Color colorSecundario = ContextoClub.colorSecundario;

    // Oscurecemos levemente el color secundario para conservar
    // buena lectura del AppBar y del texto blanco sobre el fondo.
    final Color colorFondoSuperior = Color.alphaBlend(
      Colors.black.withAlpha(120),
      colorSecundario,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreClub,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.deporteTitulo.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white70),
            tooltip: "Administración",
            onPressed: () {
              _navegarA(
                PantallaLoginAdmin(
                  config: widget.config,
                  deporteIdInicial: widget.deporteId,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Cambiar Categoría',
            onPressed: () => SelectorTiraBottomSheet.mostrar(
              context,
              config: widget.config,
              deporteIdActual: widget.deporteId,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorFondoSuperior, colorPrimario],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Menú Principal",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (lemaClub.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        lemaClub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // --- GRILLA DE BOTONES ---
                  Expanded(
                    child: _cargandoConfig
                        ? Center(child: CircularProgressIndicator(color: colorPrimario))
                        : StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('configuracion').doc('stream').snapshots(),
                            builder: (context, snapshotStream) {
                              bool hayVivo = false;
                              String urlStream = "";
                              if (snapshotStream.hasData && snapshotStream.data!.exists) {
                                final sData = snapshotStream.data!.data() as Map<String, dynamic>;
                                hayVivo = sData['en_vivo'] ?? false;
                                urlStream = sData['url'] ?? '';
                              }

                              return StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).snapshots(),
                                builder: (context, snapshotVivo) {
                                  bool enVivoMinuto = false;
                                  if (snapshotVivo.hasData && snapshotVivo.data!.exists) {
                                    final data = snapshotVivo.data!.data() as Map<String, dynamic>;
                                    enVivoMinuto = data['activo'] ?? false;
                                  }

                                  List<Widget> botones = [];

                                  if (_moduloStream) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: hayVivo ? "MIRAR VIVO" : "Transmisión",
                                        icono: Icons.live_tv,
                                        colorPrimario: hayVivo ? Colors.red : Colors.grey,
                                        alPresionar: () {
                                          if (hayVivo && urlStream.isNotEmpty) {
                                            _lanzarURL(urlStream);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("No hay transmisión en vivo ahora.")),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloProde) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: "Jugar Prode",
                                        icono: Icons.emoji_events,
                                        colorPrimario: Colors.deepOrange,
                                        alPresionar: () {
                                          _navegarA(PantallaProdeUsuario(config: widget.config));
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloVotacion) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: "Votar Figura",
                                        icono: Icons.star,
                                        colorPrimario: Colors.amber[700]!,
                                        alPresionar: () {
                                          _navegarA(PantallaVotacionUsuario(config: widget.config));
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloMinuto) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: enVivoMinuto ? "Goles VIVO" : "Historial",
                                        icono: Icons.timer,
                                        colorPrimario: enVivoMinuto ? Colors.amber[700]! : Colors.grey,
                                        alPresionar: () {
                                          if (enVivoMinuto) {
                                            _navegarA(PantallaMinutoAMinuto(config: widget.config, deporteId: widget.deporteId));
                                          } else {
                                            _navegarA(PantallaHistorialMinuto(config: widget.config, deporteId: widget.deporteId));
                                          }
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloTienda) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: "Tienda",
                                        icono: Icons.store,
                                        colorPrimario: Colors.purple,
                                        alPresionar: () {
                                          _navegarA(PantallaTienda(config: widget.config));
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloSorteos) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: "Rifas",
                                        icono: Icons.local_activity,
                                        colorPrimario: Colors.pink,
                                        alPresionar: () {
                                          _navegarA(PantallaSorteos(config: widget.config));
                                        },
                                      ),
                                    );
                                  }

                                  if (_moduloInstitucional) {
                                    botones.add(
                                      BotonMenu(
                                        titulo: "Carnet Socio",
                                        icono: Icons.badge,
                                        colorPrimario: Colors.green[700]!,
                                        alPresionar: () {
                                          _navegarA(PantallaAccesoSocio(config: widget.config));
                                        },
                                      ),
                                    );
                                  }

                                  botones.addAll([
                                    BotonMenu(
                                      titulo: "Fixture y Resultados",
                                      icono: Icons.scoreboard,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () {
                                        _navegarA(PantallaResultados(config: widget.config, deporteId: widget.deporteId, tituloDeporte: widget.deporteTitulo));
                                      },
                                    ),
                                    BotonMenu(
                                      titulo: "Noticias",
                                      icono: Icons.newspaper,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () => _navegarA(
                                        Scaffold(
                                          appBar: AppBar(title: const Text("Noticias")),
                                          body: PantallaNoticias(config: widget.config),
                                        ),
                                      ),
                                    ),
                                    BotonMenu(
                                      titulo: "Jugadores",
                                      icono: Icons.groups,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () {
                                        _navegarA(PantallaJugadores(config: widget.config, deporteId: widget.deporteId, tituloDeporte: widget.deporteTitulo, categorias: _categoriasDelDeporte));
                                      },
                                    ),
                                    BotonMenu(
                                      titulo: "Galería",
                                      icono: Icons.photo_library,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () => _navegarA(
                                        Scaffold(
                                          appBar: AppBar(
                                            title: Text("Galería ${widget.deporteTitulo}"),
                                            backgroundColor: colorPrimario,
                                            foregroundColor: Colors.white,
                                          ),
                                          body: PantallaGaleria(config: widget.config, deporteId: widget.deporteId),
                                        ),
                                      ),
                                    ),
                                    BotonMenu(
                                      titulo: "Avisos",
                                      icono: Icons.notifications_active,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () => _navegarA(
                                        Scaffold(
                                          appBar: AppBar(
                                            title: Text("Avisos ${widget.deporteTitulo}"),
                                            backgroundColor: colorPrimario,
                                            foregroundColor: Colors.white,
                                          ),
                                          body: PantallaAvisos(config: widget.config, deporteId: widget.deporteId),
                                        ),
                                      ),
                                    ),
                                    BotonMenu(
                                      titulo: "Rivales",
                                      icono: Icons.location_on,
                                      colorPrimario: colorPrimario,
                                      alPresionar: () => _navegarA(PantallaRivales(config: widget.config, deporteId: widget.deporteId)),
                                    ),
                                    BotonMenu(
                                      titulo: "Posiciones",
                                      icono: Icons.bar_chart,
                                      colorPrimario: colorPrimario,
                                      alPresionar: _abrirTablaPosiciones,
                                    ),
                                  ]);

                                  return GridView.count(
                                    crossAxisCount: 3,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                    children: botones,
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  // --- FOOTER DESARROLLADOR ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    color: Colors.black.withOpacity(0.4),
                    child: Column(
                      children: [
                        const Text(
                          "Desarrollado por PROSDO DIGITAL",
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _lanzarURL("https://prosdodigital.site"),
                              child: const Row(
                                children: [
                                  Icon(Icons.language, color: Colors.white70, size: 14),
                                  SizedBox(width: 4),
                                  Text("prosdodigital.site", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            GestureDetector(
                              onTap: () => _lanzarURL("https://wa.me/5491126440284"),
                              child: const Row(
                                children: [
                                  Icon(Icons.phone_android, color: Colors.white70, size: 14),
                                  SizedBox(width: 4),
                                  Text("11-2644-0284", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  EtiquetaVersion(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // --- SOLAPA FLOTANTE DE SUGERENCIAS ---
              Positioned(
                right: 0,
                top: MediaQuery.of(context).size.height * 0.35,
                child: GestureDetector(
                  onTap: () => mostrarDialogoSugerencias(context, widget.config),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(-2, 2)),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.white),
                        SizedBox(height: 5),
                        Text("IDEAS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}