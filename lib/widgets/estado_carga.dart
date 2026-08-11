import 'package:flutter/material.dart';

enum TipoEstadoPantalla { cargando, error, vacio, listo }

class EstadoCarga extends StatelessWidget {
  final TipoEstadoPantalla estado;
  final Widget? child;
  final String? mensaje;
  final VoidCallback? onReintentar;
  final Color? colorPrimario;
  final IconData iconoVacio;

  const EstadoCarga({
    super.key,
    required this.estado,
    this.child,
    this.mensaje,
    this.onReintentar,
    this.colorPrimario,
    this.iconoVacio = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorPrimario ?? Theme.of(context).colorScheme.primary;

    switch (estado) {
      case TipoEstadoPantalla.listo:
        return child ?? const SizedBox.shrink();
      case TipoEstadoPantalla.cargando:
        return Center(child: CircularProgressIndicator(color: color));
      case TipoEstadoPantalla.vacio:
        return _ContenedorEstado(
          icono: iconoVacio,
          color: color,
          titulo: mensaje ?? 'No hay información disponible',
          subtitulo: 'Volvé más tarde o contactá al club.',
        );
      case TipoEstadoPantalla.error:
        return _ContenedorEstado(
          icono: Icons.wifi_off,
          color: Colors.orange[800]!,
          titulo: mensaje ?? 'Sin conexión',
          subtitulo: 'Verificá tu internet e intentá de nuevo.',
          onReintentar: onReintentar,
        );
    }
  }
}

class _ContenedorEstado extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onReintentar;

  const _ContenedorEstado({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: color.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
