import 'package:flutter/material.dart';
import '../../configuracion/configuracion_app.dart';
import '../../pantallas/pantalla_seleccion_actividad.dart';
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
      title: const Text('TuSede'),
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Elegí tu club',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (clubes.isEmpty)
                  const Text('Todavía no hay clubes publicados.'),
                for (final c in clubes)
                  Card(
                    child: ListTile(
                      title: Text(c['nombre'].toString()),
                      subtitle: Text(
                        (c['identidad'] as Map?)?['lema']?.toString() ?? '',
                      ),
                      leading: _LogoCatalogo(
                        url:
                            (c['identidad'] as Map?)?['logoUrl']?.toString() ??
                            '',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PantallaEspacioClub(
                            club: Map<String, dynamic>.from(c),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _LogoCatalogo extends StatelessWidget {
  final String url;
  const _LogoCatalogo({required this.url});
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? const Icon(Icons.groups)
      : Image.network(
          url,
          width: 48,
          height: 48,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, error, stack) =>
              const Icon(Icons.broken_image_outlined),
        );
}

class PantallaEspacioClub extends StatefulWidget {
  final Map<String, dynamic> club;
  const PantallaEspacioClub({super.key, required this.club});
  @override
  State<PantallaEspacioClub> createState() => _EspacioState();
}

class _EspacioState extends State<PantallaEspacioClub> {
  late ConfiguracionApp _config;
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
          builder: (_) => PantallaSeleccionActividad(config: _config),
        ),
      ),
    ),
  );
}
