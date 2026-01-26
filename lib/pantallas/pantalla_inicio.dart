import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';
import '../widgets/boton_menu.dart';
import '../widgets/banner_publicidad.dart';

// Importamos todas las pantallas principales
import 'pantalla_noticias.dart';
import 'pantalla_resultados.dart';
import 'pantalla_jugadores.dart';
import 'pantalla_galeria.dart';
import 'pantalla_avisos.dart';
import 'pantalla_login_admin.dart';
import 'pantalla_rivales.dart';

// Importamos los Módulos Extra
import 'pantalla_minuto_a_minuto.dart';
import 'pantalla_historial_minuto.dart';
import 'pantalla_tienda.dart';
import 'pantalla_sorteos.dart';
import 'prode/pantalla_prode_usuario.dart';
import 'votacion/pantalla_votacion_usuario.dart'; // <--- IMPORT NUEVO (VOTACIÓN)


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
  // Variable para asegurar que el popup no salga dos veces
  bool _verificandoAviso = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _chequearAvisoEntrada();
      });
    });
  }

  // --- LÓGICA DEL POP-UP (AVISO DE ENTRADA) ---
  Future<void> _chequearAvisoEntrada() async {
    if (_verificandoAviso) return;
    _verificandoAviso = true;

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('aviso_entrada').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        bool activo = data['activo'] ?? false;

        if (activo && mounted) {
          String titulo = data['titulo'] ?? 'Aviso Importante';
          String mensaje = data['mensaje'] ?? '';
          String imagenUrl = data['imagen_url'] ?? '';

          _mostrarDialogoAviso(titulo, mensaje, imagenUrl);
        }
      }
    } catch (e) {
      print("Error chequeando aviso: $e");
    }
  }

  void _mostrarDialogoAviso(String titulo, String mensaje, String imagenUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        // Usamos Scroll por si la imagen es muy alta o el texto muy largo
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagenUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: ConstrainedBox(
                    // LÍMITE DE ALTURA:
                    constraints: const BoxConstraints(
                      maxHeight: 350,
                      minHeight: 100,
                      minWidth: double.infinity,
                    ),
                    child: Image.network(
                      imagenUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                            height: 150,
                            child: Center(
                                child: CircularProgressIndicator(color: widget.config.colorPrimario)
                            )
                        );
                      },
                      errorBuilder: (c, o, s) => Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Icon(Icons.campaign, size: 50, color: widget.config.colorPrimario),
                ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    if (titulo.isNotEmpty)
                      Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: widget.config.colorPrimario, fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                    if (titulo.isNotEmpty && mensaje.isNotEmpty)
                      const SizedBox(height: 10),
                    if (mensaje.isNotEmpty)
                      Text(
                          mensaje,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16)
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _navegarA(Widget pantalla) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => pantalla),
    );
  }

  Future<void> _lanzarURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo abrir: $urlString")),
        );
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
          _lanzarURL(url);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link no configurado")));
        }
      }
    } catch (e) {
      print("Error buscando posiciones: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.config.nombreApp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              _navegarA(PantallaLoginAdmin(
                config: widget.config,
                deporteIdInicial: widget.deporteId,
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: "Cambiar Categoría",
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, widget.config.colorPrimario],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text("Menú Principal", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),

              // --- GRILLA DE BOTONES DINÁMICA ---
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('configuracion').doc('general').snapshots(),
                  builder: (context, snapshotConfig) {

                    bool moduloMinuto = false;
                    bool moduloTienda = false;
                    bool moduloSorteos = false;
                    bool moduloStream = false;
                    bool moduloProde = false;
                    bool moduloVotacion = false; // <--- VARIABLE VOTACIÓN
                    List<String> categoriasDelDeporte = [];

                    if (snapshotConfig.hasData && snapshotConfig.data!.exists) {
                      final data = snapshotConfig.data!.data() as Map<String, dynamic>;
                      final modulos = data['modulos_activos'] as Map<String, dynamic>? ?? {};

                      moduloMinuto = modulos['minuto_a_minuto'] ?? false;
                      moduloTienda = modulos['tienda'] ?? false;
                      moduloSorteos = modulos['sorteos'] ?? false;
                      moduloStream = modulos['stream'] ?? false;
                      moduloProde = modulos['prode'] ?? false;
                      moduloVotacion = modulos['votacion'] ?? false; // <--- LEEMOS CONFIG VOTACIÓN

                      final menuDeportes = List.from(data['menu_deportes'] ?? []);
                      try {
                        final deporteData = menuDeportes.firstWhere(
                                (element) => element['id'] == widget.deporteId,
                            orElse: () => <String, dynamic>{}
                        );
                        if (deporteData is Map && deporteData.containsKey('categorias')) {
                          categoriasDelDeporte = List<String>.from(deporteData['categorias']);
                        }
                      } catch (e) {
                        print("Error buscando categorías: $e");
                      }
                    }

                    // AÑADIMOS STREAM (Y RESTO DE MÓDULOS)
                    return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('configuracion').doc('stream').snapshots(),
                        builder: (context, snapshotStream) {

                          bool hayVivo = false;
                          String urlStream = "";
                          if (snapshotStream.hasData && snapshotStream.data!.exists) {
                            final sData = snapshotStream.data!.data() as Map<String, dynamic>;
                            hayVivo = sData['en_vivo'] ?? false;
                            urlStream = sData['url'] ?? '';
                          }

                          // LEEMOS ESTADO DEL PARTIDO EN VIVO (MINUTO A MINUTO)
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('partidos_en_vivo').doc(widget.deporteId).snapshots(),
                            builder: (context, snapshotVivo) {

                              bool enVivoMinuto = false;
                              if (snapshotVivo.hasData && snapshotVivo.data!.exists) {
                                final data = snapshotVivo.data!.data() as Map<String, dynamic>;
                                enVivoMinuto = data['activo'] ?? false;
                              }

                              List<Widget> botones = [];

                              // --- STREAMING ---
                              if (moduloStream) {
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
                                              const SnackBar(content: Text("No hay transmisión en vivo ahora."))
                                          );
                                        }
                                      },
                                    )
                                );
                              }

                              // --- PRODE ---
                              if (moduloProde) {
                                botones.add(
                                    BotonMenu(
                                      titulo: "Jugar Prode",
                                      icono: Icons.emoji_events,
                                      colorPrimario: Colors.deepOrange,
                                      alPresionar: () {
                                        _navegarA(PantallaProdeUsuario(config: widget.config));
                                      },
                                    )
                                );
                              }

                              // --- VOTACIÓN MVP (MÓDULO NUEVO) ---
                              if (moduloVotacion) {
                                botones.add(
                                    BotonMenu(
                                      titulo: "Votar Figura",
                                      icono: Icons.star,
                                      colorPrimario: Colors.amber[700]!, // Color Dorado
                                      alPresionar: () {
                                        _navegarA(PantallaVotacionUsuario(config: widget.config));
                                      },
                                    )
                                );
                              }

                              // --- MINUTO A MINUTO ---
                              if (moduloMinuto) {
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
                                    )
                                );
                              }

                              // --- TIENDA ---
                              if (moduloTienda) {
                                botones.add(
                                    BotonMenu(
                                      titulo: "Tienda",
                                      icono: Icons.store,
                                      colorPrimario: Colors.purple,
                                      alPresionar: () {
                                        _navegarA(PantallaTienda(config: widget.config));
                                      },
                                    )
                                );
                              }

                              // --- RIFAS ---
                              if (moduloSorteos) {
                                botones.add(
                                    BotonMenu(
                                      titulo: "Rifas",
                                      icono: Icons.local_activity,
                                      colorPrimario: Colors.pink,
                                      alPresionar: () {
                                        _navegarA(PantallaSorteos(config: widget.config));
                                      },
                                    )
                                );
                              }

                              // --- BOTONES ESTÁNDAR ---
                              botones.addAll([
                                BotonMenu(
                                  titulo: "Resultados",
                                  icono: Icons.scoreboard,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () {
                                    _navegarA(
                                        PantallaResultados(
                                          config: widget.config,
                                          deporteId: widget.deporteId,
                                          tituloDeporte: widget.deporteTitulo,
                                        )
                                    );
                                  },
                                ),
                                BotonMenu(
                                  titulo: "Noticias",
                                  icono: Icons.newspaper,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () => _navegarA(Scaffold(appBar: AppBar(title: const Text("Noticias")), body: PantallaNoticias(config: widget.config))),
                                ),
                                BotonMenu(
                                  titulo: "Jugadores",
                                  icono: Icons.groups,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () {
                                    _navegarA(
                                        PantallaJugadores(
                                          config: widget.config,
                                          deporteId: widget.deporteId,
                                          tituloDeporte: widget.deporteTitulo,
                                          categorias: categoriasDelDeporte,
                                        )
                                    );
                                  },
                                ),
                                BotonMenu(
                                  titulo: "Galería",
                                  icono: Icons.photo_library,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () => _navegarA(Scaffold(
                                      appBar: AppBar(title: Text("Galería ${widget.deporteTitulo}"), backgroundColor: widget.config.colorPrimario, foregroundColor: Colors.white),
                                      body: PantallaGaleria(config: widget.config, deporteId: widget.deporteId))),
                                ),
                                BotonMenu(
                                  titulo: "Avisos",
                                  icono: Icons.notifications_active,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () => _navegarA(Scaffold(
                                      appBar: AppBar(title: Text("Avisos ${widget.deporteTitulo}"), backgroundColor: widget.config.colorPrimario, foregroundColor: Colors.white),
                                      body: PantallaAvisos(config: widget.config, deporteId: widget.deporteId))),
                                ),
                                BotonMenu(
                                  titulo: "Rivales",
                                  icono: Icons.location_on,
                                  colorPrimario: widget.config.colorPrimario,
                                  alPresionar: () => _navegarA(PantallaRivales(config: widget.config, deporteId: widget.deporteId)),
                                ),
                                BotonMenu(
                                  titulo: "Posiciones",
                                  icono: Icons.bar_chart,
                                  colorPrimario: widget.config.colorPrimario,
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
                        }
                    );
                  },
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: BannerPublicidad(),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                color: Colors.black.withOpacity(0.3),
                child: Column(
                  children: [
                    const Text(
                      "Desarrollado por PROSDO DIGITAL",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _lanzarURL("https://prosdodigital.site"),
                          child: const Row(
                            children: [
                              Icon(Icons.language, color: Colors.white70, size: 16),
                              SizedBox(width: 5),
                              Text("prosdodigital.site", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => _lanzarURL("https://wa.me/5491126440284"),
                          child: const Row(
                            children: [
                              Icon(Icons.phone_android, color: Colors.white70, size: 16),
                              SizedBox(width: 5),
                              Text("11-2644-0284", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}