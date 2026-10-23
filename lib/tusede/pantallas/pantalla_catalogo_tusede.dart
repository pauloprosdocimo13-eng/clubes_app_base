import 'package:flutter/material.dart';
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
  const PantallaCatalogoTuSede({super.key});
  @override
  State<PantallaCatalogoTuSede> createState() => _CatalogoState();
}

class _CatalogoState extends State<PantallaCatalogoTuSede> {
  late Future<Map<String, dynamic>> _clubes;
  @override
  void initState() {
    super.initState();
    _clubes = _cargar();
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
  const VistaCatalogoTuSede({
    super.key,
    required this.clubes,
    required this.onAbrir,
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
  const TarjetaCatalogoTuSede({
    super.key,
    required this.club,
    required this.onTap,
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
  @override
  void initState() {
    super.initState();
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
        title: const Text('TuSede'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Cambiar club'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Navigator(
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
                                    (config) => config.activarMultiActividad,
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
  );
}
