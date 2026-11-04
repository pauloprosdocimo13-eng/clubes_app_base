import 'package:flutter/material.dart';
import '../servicios/servicio_accesos_club.dart';
import '../servicios/servicio_plataforma_tusede.dart';
import 'pantalla_catalogo_tusede.dart';

/// Solo se abre un club que siga presente en el catálogo público actual.
Map<String, dynamic>? clubPublicadoParaAcceso(
  Map<String, dynamic> catalogo,
  String id,
) {
  if (!ServicioAccesosClub.idValido(id)) return null;
  for (final item in (catalogo['clubes'] as List? ?? const [])) {
    if (item is Map &&
        item['id'] == id &&
        item['activo'] == true &&
        item['origenDatos'] == 'central' &&
        item['estado'] == 'activo') {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

class PantallaAccesoClub extends StatefulWidget {
  final String clubId;
  final Future<Map<String, dynamic>> Function()? cargar;
  const PantallaAccesoClub({super.key, required this.clubId, this.cargar});
  @override
  State<PantallaAccesoClub> createState() => _AccesoState();
}

class _AccesoState extends State<PantallaAccesoClub> {
  late Future<Map<String, dynamic>> _catalogo;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _catalogo =
        widget.cargar?.call() ??
        ServicioPlataformaTuSede.ejecutar('catalogo', {}, publico: true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _catalogo,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final club = snapshot.hasData
          ? clubPublicadoParaAcceso(snapshot.data!, widget.clubId)
          : null;
      if (club != null) return PantallaEspacioClub(club: club);
      return Scaffold(
        appBar: AppBar(title: const Text('TuSede')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.hasError
                      ? 'No pudimos conectar con tu club. Revisá tu conexión y reintentá.'
                      : 'Este club ya no está disponible en el catálogo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  FilledButton(
                    onPressed: () => setState(_cargar),
                    child: const Text('Reintentar'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ver otros clubes'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
