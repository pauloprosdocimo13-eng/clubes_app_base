import 'package:flutter/material.dart';
import 'tusede/diseno/identidad_tusede.dart';
import 'tusede/servicios/servicio_firebase_tusede.dart';
import 'tusede/servicios/servicio_accesos_club.dart';
import 'tusede/pantallas/pantalla_catalogo_tusede.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServicioFirebaseTuSede.inicializar();
  runApp(const AplicacionTuSede());
}

class AplicacionTuSede extends StatefulWidget {
  final Widget Function(String?)? crearInicio;
  const AplicacionTuSede({super.key, this.crearInicio});
  @override
  State<AplicacionTuSede> createState() => _AplicacionState();
}

class _AplicacionState extends State<AplicacionTuSede> {
  String? _clubInicial;
  int _entrada = 0;
  bool _cambiando = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ServicioAccesosClub.escuchar(_abrir);
    });
  }

  Future<void> _abrir(String? id) async {
    if (!mounted) return;
    final entrada = ++_entrada;
    // Desmontar también el navegador interno antes de cambiar el contexto global.
    // Así dispose() de un club anterior no borra el contexto del siguiente.
    setState(() => _cambiando = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || entrada != _entrada) return;
    setState(() {
      _clubInicial = id;
      _cambiando = false;
    });
  }

  @override
  void dispose() {
    ServicioAccesosClub.dejarDeEscuchar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: ValueKey('$_entrada-$_cambiando'),
    title: 'TuSede',
    debugShowCheckedModeBanner: false,
    theme: temaTuSede(),
    home: _cambiando
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : (widget.crearInicio?.call(_clubInicial) ??
              PantallaCatalogoTuSede(clubInicial: _clubInicial)),
  );
}
