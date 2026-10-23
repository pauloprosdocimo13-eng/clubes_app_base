import 'package:flutter/material.dart';

/// Mantiene la selección provisional hasta que el usuario pulse Usar color.
Future<Color?> elegirColorClub(BuildContext context, Color inicial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _PaletaClub(inicial: inicial),
  );
}

class _PaletaClub extends StatefulWidget {
  final Color inicial;
  const _PaletaClub({required this.inicial});

  @override
  State<_PaletaClub> createState() => _PaletaClubState();
}

class _PaletaClubState extends State<_PaletaClub> {
  late HSVColor _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = HSVColor.fromColor(widget.inicial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _seleccion.toColor();
    final contraste = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final opciones = <Color>[
      const Color(0xFF1565C0),
      const Color(0xFFFFC107),
      ...Colors.primaries,
      Colors.black,
      Colors.white,
      Colors.grey,
    ];
    return AlertDialog(
      title: const Text('Elegir color'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  'Color seleccionado',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: contraste),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opcion in opciones)
                    Semantics(
                      label:
                          'Color ${opcion.toARGB32().toRadixString(16).substring(2)}',
                      selected: opcion.toARGB32() == color.toARGB32(),
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => setState(
                          () => _seleccion = HSVColor.fromColor(opcion),
                        ),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: opcion,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: opcion.toARGB32() == color.toARGB32()
                              ? Icon(Icons.check, color: contraste)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Ajustar tono'),
              Slider(
                value: _seleccion.hue,
                max: 360,
                label: '${_seleccion.hue.round()}°',
                onChanged: (v) =>
                    setState(() => _seleccion = _seleccion.withHue(v)),
              ),
              const Text('Intensidad'),
              Slider(
                value: _seleccion.saturation,
                label: '${(_seleccion.saturation * 100).round()}%',
                onChanged: (v) =>
                    setState(() => _seleccion = _seleccion.withSaturation(v)),
              ),
              const Text('Brillo'),
              Slider(
                value: _seleccion.value,
                label: '${(_seleccion.value * 100).round()}%',
                onChanged: (v) =>
                    setState(() => _seleccion = _seleccion.withValue(v)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Usar color'),
        ),
      ],
    );
  }
}
