import 'pantalla_acceso_club.dart';
import '../servicios/servicio_accesos_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../diseno/identidad_tusede.dart';
import '../../configuracion/configuracion_app.dart';
import '../../pantallas/pantalla_seleccion_actividad.dart';
import '../../pantallas/pantalla_seleccion.dart';
import '../servicios/servicio_contenido_publico.dart';
import '../modelos/club_tusede.dart';
import '../servicios/contexto_club.dart';
import '../servicios/servicio_control_tusede.dart';
import '../servicios/servicio_plataforma_tusede.dart';
import 'pantalla_plataforma_tusede.dart';

class PantallaCatalogoTuSede extends StatefulWidget {
  final String? clubInicial;
  const PantallaCatalogoTuSede({super.key, this.clubInicial});
  @override
  State<PantallaCatalogoTuSede> createState() => _CatalogoState();
}

class _CatalogoState extends State<PantallaCatalogoTuSede> {
  late Future<Map<String, dynamic>> _clubes;
  bool _accesoDisponible = false;
  String? _agregandoClub;
  Future<void> _agregarAcceso(Map club) async {
    if (_agregandoClub != null) return;
    setState(() => _agregandoClub = club['id'].toString());
    try {
      final mensaje = await ServicioAccesosClub.agregar(
        Map<String, dynamic>.from(club),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo solicitar el acceso directo. Volvé a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _agregandoClub = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _clubes = _cargar();
    ServicioAccesosClub.disponible().then((value) {
      if (mounted) setState(() => _accesoDisponible = value);
    });
    if (widget.clubInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PantallaAccesoClub(clubId: widget.clubInicial!),
          ),
        );
      });
    }
  }

  Future<Map<String, dynamic>> _cargar() =>
      ServicioPlataformaTuSede.ejecutar('catalogo', {}, publico: true);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const MarcaTuSede(),
      actions: [
        IconButton(
          tooltip: 'Administración TuSede',
          icon: const Icon(Icons.admin_panel_settings_outlined),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PantallaPlataformaTuSede(),
              ),
            );
            if (mounted) setState(() => _clubes = _cargar());
          },
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _clubes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos cargar los clubes.'),
                FilledButton(
                  onPressed: () => setState(() => _clubes = _cargar()),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final clubes = (snap.data!['clubes'] as List).cast<Map>();
        return VistaCatalogoTuSede(
          clubes: clubes,
          onAgregarAcceso: _accesoDisponible ? _agregarAcceso : null,
          agregandoClub: _agregandoClub,
          onAbrir: (club) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PantallaEspacioClub(club: Map<String, dynamic>.from(club)),
            ),
          ),
        );
      },
    ),
  );
}

class VistaCatalogoTuSede extends StatelessWidget {
  final List<Map> clubes;
  final ValueChanged<Map> onAbrir;
  final ValueChanged<Map>? onAgregarAcceso;
  final String? agregandoClub;
  const VistaCatalogoTuSede({
    super.key,
    required this.clubes,
    required this.onAbrir,
    this.onAgregarAcceso,
    this.agregandoClub,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const CabeceraTuSede(
            etiqueta: 'El punto de encuentro',
            titulo: 'Tu club.\nSiempre cerca.',
            descripcion:
                'Toda la vida de tu club, en un solo lugar.\nNoticias, actividades y mucho más.',
            pie: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                EtiquetaTuSede('Comunidad', oscura: true),
                EtiquetaTuSede('Deporte', oscura: true),
                EtiquetaTuSede('Tu gente', oscura: true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Elegí tu club',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              EtiquetaTuSede(
                '${clubes.length} ${clubes.length == 1 ? 'club' : 'clubes'}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Entrá y descubrí todo lo que está pasando.'),
          const SizedBox(height: 20),
          if (clubes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Todavía no hay clubes publicados. Volvé pronto para encontrar el tuyo.',
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final club in clubes)
                    SizedBox(
                      width: ancho,
                      child: TarjetaCatalogoTuSede(
                        club: club,
                        onTap: () => onAbrir(club),
                        onAgregarAcceso: onAgregarAcceso == null
                            ? null
                            : () => onAgregarAcceso!(club),
                        accesoOcupado: agregandoClub != null,
                        agregandoAcceso: agregandoClub == club['id'],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'Hecho para clubes. Pensado para vos.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA5BDB7)),
            ),
          ),
        ],
      ),
    ),
  );
}

class TarjetaCatalogoTuSede extends StatelessWidget {
  final Map club;
  final VoidCallback onTap;
  final VoidCallback? onAgregarAcceso;
  final bool accesoOcupado, agregandoAcceso;
  const TarjetaCatalogoTuSede({
    super.key,
    required this.club,
    required this.onTap,
    this.onAgregarAcceso,
    this.accesoOcupado = false,
    this.agregandoAcceso = false,
  });
  @override
  Widget build(BuildContext context) {
    final identidad = club['identidad'] as Map? ?? {};
    final lema = identidad['lema']?.toString().trim() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EscudoTuSede(url: identidad['logoUrl']?.toString() ?? ''),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club['nombre'].toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(lema.isEmpty ? 'Tu comunidad te espera' : lema),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conocé el club',
                      style: TextStyle(
                        color: mentaTuSede,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: mentaTuSede,
                    size: 20,
                  ),
                ],
              ),
              if (onAgregarAcceso != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: accesoOcupado ? null : onAgregarAcceso,
                    icon: const Icon(
                      Icons.add_to_home_screen_rounded,
                      size: 18,
                    ),
                    label: Text(
                      agregandoAcceso
                          ? 'Preparando acceso…'
                          : 'Agregar al inicio',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mentaTuSede,
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Color(0xFF40635D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PantallaEspacioClub extends StatefulWidget {
  final Map<String, dynamic> club;
  const PantallaEspacioClub({super.key, required this.club});
  @override
  State<PantallaEspacioClub> createState() => _EspacioState();
}

class _EspacioState extends State<PantallaEspacioClub> {
  late ConfiguracionApp _config;
  late Future<bool> _arranque;
  final _navigator = GlobalKey<NavigatorState>();
  bool _accesoDisponible = false;
  bool _agregandoAcceso = false;
  Future<void> _agregarAcceso() async {
    if (_agregandoAcceso) return;
    setState(() => _agregandoAcceso = true);
    try {
      final mensaje = await ServicioAccesosClub.agregar(widget.club);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo solicitar el acceso directo. Volvé a intentarlo.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _agregandoAcceso = false);
    }
  }

  @override
  void initState() {
    super.initState();
    ServicioAccesosClub.disponible().then((value) {
      if (mounted) setState(() => _accesoDisponible = value);
    });
    final club = ClubTuSede.fromMap(widget.club['id'].toString(), {
      ...widget.club,
      'origenDatos': 'central',
    });
    _config = ConfiguracionApp(
      nombreApp: club.nombre,
      nombreSabor: 'generico',
      clubIdTuSede: club.id,
      prefijoColeccion: club.id,
      colorPrimario: _color(club.colorPrimarioHex, const Color(0xFF1565C0)),
      colorSecundario: _color(club.colorSecundarioHex, const Color(0xFFFFC107)),
      rutaLogo: 'assets/tusede/splash_icon.png',
      urlSubidaFoto: '',
    );
    ConfiguracionApp.actual = _config;
    ContextoClub.cambiarClub(club);
    ServicioControlTuSede.invalidarCache();
    _arranque = ServicioContenidoPublico.cargarConfiguracion().then(
      (config) => config.activarMultiActividad,
    );
  }

  Color _color(String hex, Color fallback) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
      ? Color(int.parse('FF${hex.substring(1)}', radix: 16))
      : fallback;
  @override
  void dispose() {
    ContextoClub.limpiar();
    ServicioControlTuSede.invalidarCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(colorSchemeSeed: _config.colorPrimario, useMaterial3: true),
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leadingWidth: 48,
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color.alphaBlend(
          const Color(0xB3000000),
          _config.colorPrimario,
        ),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          _config.nombreApp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opciones del club',
            color: Color.alphaBlend(
              const Color(0xB3000000),
              _config.colorPrimario,
            ),
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'acceso') _agregarAcceso();
              if (value == 'cambiar') Navigator.of(context).pop();
            },
            itemBuilder: (_) => [
              if (_accesoDisponible)
                PopupMenuItem<String>(
                  value: 'acceso',
                  enabled: !_agregandoAcceso,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_to_home_screen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _agregandoAcceso
                            ? 'Preparando acceso…'
                            : 'Agregar mi club al inicio',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'cambiar',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Cambiar club', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Navigator(
              key: _navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => FutureBuilder<bool>(
                  future: _arranque,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No se pudo cargar el inicio del club.'),
                            TextButton(
                              onPressed: () => setState(() {
                                _arranque =
                                    ServicioContenidoPublico.cargarConfiguracion()
                                        .then(
                                          (config) =>
                                              config.activarMultiActividad,
                                        );
                              }),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }
                    return snapshot.data!
                        ? PantallaSeleccionActividad(config: _config)
                        : PantallaSeleccion(config: _config);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
