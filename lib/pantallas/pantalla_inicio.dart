import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../widgets/boton_menu.dart';
import '../widgets/dialogo_sugerencias.dart';
import '../widgets/selector_tira_bottom_sheet.dart';
import 'pantalla_avisos.dart';
import 'pantalla_galeria.dart';
import 'pantalla_historial_minuto.dart';
import 'pantalla_jugadores.dart';
import 'pantalla_login_admin.dart';
import 'pantalla_minuto_a_minuto.dart';
import 'pantalla_noticias.dart';
import 'pantalla_posiciones_web.dart';
import 'pantalla_resultados.dart';
import 'pantalla_rivales.dart';
import 'pantalla_sorteos.dart';
import 'pantalla_tienda.dart';
import 'prode/pantalla_prode_usuario.dart';
import 'socios/pantalla_acceso_socio.dart';
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
  bool _cargandoConfig = true;

  bool _moduloMinuto = false;
  bool _moduloTienda = false;
  bool _moduloSorteos = false;
  bool _moduloStream = false;
  bool _moduloProde = false;
  bool _moduloVotacion = false;
  bool _moduloInstitucional = false;

  List<String> _categoriasDelDeporte = <String>[];

  // ============================================================
  // DATOS PÚBLICOS DE TUSEDE CENTRAL
  // ============================================================

  bool _streamCentralEnVivo = false;
  String _streamCentralUrl = '';

  bool _minutoCentralEnVivo = false;

  Map<String, String> _enlacesCentral = <String, String>{};

  Timer? _timerVivoCentral;

  @override
  void initState() {
    super.initState();

    _cargarConfiguracionGeneral();
  }

  @override
  void dispose() {
    _timerVivoCentral?.cancel();
    super.dispose();
  }

  // ============================================================
  // CONFIGURACIÓN GENERAL
  // ============================================================

  Future<void> _cargarConfiguracionGeneral() async {
    if (ServicioDatosClub.usaTuSedeCentral) {
      await _cargarConfiguracionCentral();
      return;
    }

    await _cargarConfiguracionLegacy();
  }

  // ============================================================
  // TUSEDE CENTRAL
  // ============================================================

  Future<void> _cargarConfiguracionCentral() async {
    try {
      final datos = await ServicioContenidoPublico.cargarConfiguracion();

      if (!mounted) return;

      setState(() {
        _moduloMinuto = datos.moduloActivo('minuto_a_minuto');

        _moduloTienda = datos.moduloActivo('tienda');

        _moduloSorteos = datos.moduloActivo('sorteos');

        _moduloStream = datos.moduloActivo('stream');

        _moduloProde = datos.moduloActivo('prode');

        _moduloVotacion = datos.moduloActivo('votacion');

        _moduloInstitucional = datos.moduloActivo('institucional');

        _categoriasDelDeporte = datos.categoriasDe(widget.deporteId);

        _streamCentralEnVivo = datos.streamEnVivo;
        _streamCentralUrl = datos.streamUrl;

        _enlacesCentral = Map<String, String>.from(datos.enlaces);

        _cargandoConfig = false;
      });

      await _consultarVivoCentral();

      _timerVivoCentral?.cancel();

      _timerVivoCentral = Timer.periodic(const Duration(seconds: 3), (_) {
        _consultarVivoCentral();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoConfig = false;
      });
    }
  }

  Future<void> _consultarVivoCentral() async {
    if (!ServicioDatosClub.usaTuSedeCentral) {
      return;
    }

    try {
      final vivo = await ServicioContenidoPublico.cargarVivo(widget.deporteId);

      final activo = vivo != null && vivo['activo'] == true;

      if (!mounted) return;

      if (_minutoCentralEnVivo != activo) {
        setState(() {
          _minutoCentralEnVivo = activo;
        });
      }
    } catch (_) {
      // Si existe un error transitorio de red, conservamos
      // el último estado conocido para evitar parpadeos
      // o cambios falsos en el menú.
    }
  }

  // ============================================================
  // FIREBASE LEGACY
  // ============================================================

  Future<void> _cargarConfiguracionLegacy() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _cargandoConfig = false;
        });

        return;
      }

      final data = doc.data()!;

      final rawModulos = data['modulos_activos'];

      final modulos = rawModulos is Map
          ? Map<String, dynamic>.from(rawModulos)
          : <String, dynamic>{};

      final rawMenu = data['menu_deportes'];

      final menuDeportes = rawMenu is List ? rawMenu : <dynamic>[];

      final deporteData = menuDeportes.firstWhere((element) {
        if (element is! Map) {
          return false;
        }

        return (element['id'] ?? '').toString() == widget.deporteId;
      }, orElse: () => <String, dynamic>{});

      List<String> categorias = <String>[];

      if (deporteData is Map) {
        final rawCategorias = deporteData['categorias'];

        if (rawCategorias is List) {
          categorias = rawCategorias
              .map((categoria) => categoria.toString())
              .toList();
        }
      }

      setState(() {
        _moduloMinuto = modulos['minuto_a_minuto'] == true;

        _moduloTienda = modulos['tienda'] == true;

        _moduloSorteos = modulos['sorteos'] == true;

        _moduloStream = modulos['stream'] == true;

        _moduloProde = modulos['prode'] == true;

        _moduloVotacion = modulos['votacion'] == true;

        _moduloInstitucional = modulos['institucional'] == true;

        _categoriasDelDeporte = categorias;

        _cargandoConfig = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoConfig = false;
      });
    }
  }

  // ============================================================
  // NAVEGACIÓN
  // ============================================================

  void _navegarA(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  Future<void> _lanzarURL(String urlString) async {
    if (urlString.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(urlString.trim());

    if (uri == null) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir: $urlString')));
    }
  }

  // ============================================================
  // TABLA DE POSICIONES
  // ============================================================

  Future<void> _abrirTablaPosiciones() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando tabla de posiciones...'),
        duration: Duration(seconds: 1),
      ),
    );

    if (ServicioDatosClub.usaTuSedeCentral) {
      final url = _enlacesCentral[widget.deporteId] ?? '';

      _abrirPosicionesDesdeUrl(url);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('enlaces')
          .get();

      if (!mounted) return;

      final data = doc.data();

      final url = (data?[widget.deporteId] ?? '').toString().trim();

      _abrirPosicionesDesdeUrl(url);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar la tabla de posiciones.'),
        ),
      );
    }
  }

  void _abrirPosicionesDesdeUrl(String url) {
    if (!mounted) return;

    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link no configurado')));

      return;
    }

    _navegarA(
      PantallaPosicionesWeb(
        config: widget.config,
        url: url,
        titulo: 'Posiciones ${widget.deporteTitulo}',
      ),
    );
  }

  // ============================================================
  // BOTONES
  // ============================================================

  List<Widget> _construirBotones({
    required Color colorPrimario,
    required bool hayStreamEnVivo,
    required String urlStream,
    required bool hayMinutoEnVivo,
  }) {
    final botones = <Widget>[];

    if (_moduloStream) {
      botones.add(
        BotonMenu(
          titulo: hayStreamEnVivo ? 'MIRAR VIVO' : 'Transmisión',
          icono: Icons.live_tv,
          colorPrimario: hayStreamEnVivo ? Colors.red : Colors.grey,
          alPresionar: () {
            if (hayStreamEnVivo && urlStream.trim().isNotEmpty) {
              _lanzarURL(urlStream);
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay transmisión en vivo ahora.'),
              ),
            );
          },
        ),
      );
    }

    if (_moduloProde) {
      botones.add(
        BotonMenu(
          titulo: 'Jugar Prode',
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
          titulo: 'Votar Figura',
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
          titulo: hayMinutoEnVivo ? 'Goles VIVO' : 'Historial',
          icono: Icons.timer,
          colorPrimario: hayMinutoEnVivo ? Colors.amber[700]! : Colors.grey,
          alPresionar: () {
            if (hayMinutoEnVivo) {
              _navegarA(
                PantallaMinutoAMinuto(
                  config: widget.config,
                  deporteId: widget.deporteId,
                ),
              );

              return;
            }

            _navegarA(
              PantallaHistorialMinuto(
                config: widget.config,
                deporteId: widget.deporteId,
              ),
            );
          },
        ),
      );
    }

    if (_moduloTienda) {
      botones.add(
        BotonMenu(
          titulo: 'Tienda',
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
          titulo: 'Rifas',
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
          titulo: 'Carnet Socio',
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
        titulo: 'Fixture y Resultados',
        icono: Icons.scoreboard,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            PantallaResultados(
              config: widget.config,
              deporteId: widget.deporteId,
              tituloDeporte: widget.deporteTitulo,
            ),
          );
        },
      ),
      BotonMenu(
        titulo: 'Noticias',
        icono: Icons.newspaper,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            Scaffold(
              appBar: AppBar(title: const Text('Noticias')),
              body: PantallaNoticias(config: widget.config),
            ),
          );
        },
      ),
      BotonMenu(
        titulo: 'Jugadores',
        icono: Icons.groups,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            PantallaJugadores(
              config: widget.config,
              deporteId: widget.deporteId,
              tituloDeporte: widget.deporteTitulo,
              categorias: _categoriasDelDeporte,
            ),
          );
        },
      ),
      BotonMenu(
        titulo: 'Galería',
        icono: Icons.photo_library,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            Scaffold(
              appBar: AppBar(
                title: Text('Galería ${widget.deporteTitulo}'),
                backgroundColor: colorPrimario,
                foregroundColor: Colors.white,
              ),
              body: PantallaGaleria(
                config: widget.config,
                deporteId: widget.deporteId,
              ),
            ),
          );
        },
      ),
      BotonMenu(
        titulo: 'Avisos',
        icono: Icons.notifications_active,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            Scaffold(
              appBar: AppBar(
                title: Text('Avisos ${widget.deporteTitulo}'),
                backgroundColor: colorPrimario,
                foregroundColor: Colors.white,
              ),
              body: PantallaAvisos(
                config: widget.config,
                deporteId: widget.deporteId,
              ),
            ),
          );
        },
      ),
      BotonMenu(
        titulo: 'Rivales',
        icono: Icons.location_on,
        colorPrimario: colorPrimario,
        alPresionar: () {
          _navegarA(
            PantallaRivales(config: widget.config, deporteId: widget.deporteId),
          );
        },
      ),
      BotonMenu(
        titulo: 'Posiciones',
        icono: Icons.bar_chart,
        colorPrimario: colorPrimario,
        alPresionar: _abrirTablaPosiciones,
      ),
    ]);

    return botones;
  }

  // ============================================================
  // GRILLA CENTRAL
  // ============================================================

  Widget _construirGrillaCentral(Color colorPrimario) {
    final botones = _construirBotones(
      colorPrimario: colorPrimario,
      hayStreamEnVivo: _streamCentralEnVivo,
      urlStream: _streamCentralUrl,
      hayMinutoEnVivo: _minutoCentralEnVivo,
    );

    return _grilla(botones);
  }

  // ============================================================
  // GRILLA LEGACY
  // ============================================================

  Widget _construirGrillaLegacy(Color colorPrimario) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('configuracion')
          .doc('stream')
          .snapshots(),
      builder: (context, snapshotStream) {
        bool hayStreamEnVivo = false;
        String urlStream = '';

        if (snapshotStream.hasData && snapshotStream.data!.exists) {
          final data = snapshotStream.data!.data();

          if (data != null) {
            hayStreamEnVivo = data['en_vivo'] == true;

            urlStream = (data['url'] ?? '').toString();
          }
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('partidos_en_vivo')
              .doc(widget.deporteId)
              .snapshots(),
          builder: (context, snapshotVivo) {
            bool hayMinutoEnVivo = false;

            if (snapshotVivo.hasData && snapshotVivo.data!.exists) {
              final data = snapshotVivo.data!.data();

              if (data != null) {
                hayMinutoEnVivo = data['activo'] == true;
              }
            }

            final botones = _construirBotones(
              colorPrimario: colorPrimario,
              hayStreamEnVivo: hayStreamEnVivo,
              urlStream: urlStream,
              hayMinutoEnVivo: hayMinutoEnVivo,
            );

            return _grilla(botones);
          },
        );
      },
    );
  }

  Widget _grilla(List<Widget> botones) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      children: botones,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final nombreClub = ContextoClub.nombreClub.trim().isNotEmpty
        ? ContextoClub.nombreClub.trim()
        : widget.config.nombreApp;

    final lemaClub = ContextoClub.lema.trim();

    final colorPrimario = ContextoClub.colorPrimario;

    final colorSecundario = ContextoClub.colorSecundario;

    final colorFondoSuperior = Color.alphaBlend(
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
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white70,
            ),
            tooltip: 'Administración',
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
            onPressed: () {
              SelectorTiraBottomSheet.mostrar(
                context,
                config: widget.config,
                deporteIdActual: widget.deporteId,
              );
            },
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
                    'Menú Principal',
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

                  // ===========================================
                  // GRILLA DE BOTONES
                  // ===========================================
                  Expanded(
                    child: _cargandoConfig
                        ? Center(
                            child: CircularProgressIndicator(
                              color: colorPrimario,
                            ),
                          )
                        : ServicioDatosClub.usaTuSedeCentral
                        ? _construirGrillaCentral(colorPrimario)
                        : _construirGrillaLegacy(colorPrimario),
                  ),

                  // ===========================================
                  // FOOTER
                  // ===========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Column(
                      children: [
                        const Text(
                          'Desarrollado por PROSDO DIGITAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _lanzarURL('https://prosdodigital.site');
                              },
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'prosdodigital.site',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            GestureDetector(
                              onTap: () {
                                _lanzarURL('https://wa.me/5491126440284');
                              },
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.phone_android,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '11-2644-0284',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
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

              // ===============================================
              // SOLAPA DE SUGERENCIAS
              // ===============================================
              Positioned(
                right: 0,
                top: MediaQuery.of(context).size.height * 0.35,
                child: GestureDetector(
                  onTap: () {
                    mostrarDialogoSugerencias(context, widget.config);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(-2, 2),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.white),
                        SizedBox(height: 5),
                        Text(
                          'IDEAS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
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
