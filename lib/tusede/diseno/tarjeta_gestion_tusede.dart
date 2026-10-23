import 'package:flutter/material.dart';
import 'identidad_tusede.dart';

class TarjetaGestionTuSede extends StatelessWidget {
  final Map<String, dynamic> club;
  final bool ocupado;
  final VoidCallback? onAbrir,
      onEditar,
      onAdministradores,
      onLogo,
      onActivar,
      onEliminar;
  const TarjetaGestionTuSede({
    super.key,
    required this.club,
    this.ocupado = false,
    this.onAbrir,
    this.onEditar,
    this.onAdministradores,
    this.onLogo,
    this.onActivar,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final estado =
        club['estado']?.toString() ??
        (club['activo'] == true ? 'activo' : 'inactivo');
    final etiqueta = switch (estado) {
      'activo' => 'Activo',
      'borrador' => 'Borrador',
      'eliminando' => 'Eliminando',
      _ => estado,
    };
    final legacy = club['id'] == 'guemes';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: ocupado ? null : onAbrir,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EscudoTuSede(
                    url:
                        (club['identidad'] as Map?)?['logoUrl']?.toString() ??
                        '',
                    dimension: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club['nombre'].toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          club['id'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            EtiquetaTuSede(etiqueta),
                            if (legacy)
                              const EtiquetaTuSede('Integración Legacy'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onLogo != null || onActivar != null || onEliminar != null)
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones del club',
                      enabled: !ocupado,
                      onSelected: (accion) {
                        switch (accion) {
                          case 'logo':
                            onLogo?.call();
                          case 'activar':
                            onActivar?.call();
                          case 'eliminar':
                            onEliminar?.call();
                        }
                      },
                      itemBuilder: (_) => [
                        if (onLogo != null)
                          const PopupMenuItem(
                            value: 'logo',
                            child: Text('Cambiar logo'),
                          ),
                        if (onActivar != null)
                          const PopupMenuItem(
                            value: 'activar',
                            child: Text('Activar club'),
                          ),
                        if (onEliminar != null)
                          PopupMenuItem(
                            value: 'eliminar',
                            child: Text(
                              estado == 'eliminando'
                                  ? 'Retomar eliminación'
                                  : 'Eliminar club',
                              style: const TextStyle(color: Color(0xFFFFB4AB)),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (onEditar != null ||
              onAdministradores != null ||
              onAbrir != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (onEditar != null)
                    TextButton.icon(
                      onPressed: ocupado ? null : onEditar,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Editar'),
                    ),
                  if (onAdministradores != null)
                    TextButton.icon(
                      onPressed: ocupado ? null : onAdministradores,
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 18,
                      ),
                      label: const Text('Administradores'),
                    ),
                  if (onAbrir != null && estado != 'borrador')
                    TextButton.icon(
                      onPressed: ocupado ? null : onAbrir,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                      label: const Text('Abrir'),
                    ),
                ],
              ),
            ),
          ],
          if (legacy)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                'Integración de acceso pendiente.',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
