import 'dart:math';
import 'package:flutter/material.dart';
import '../servicios/servicio_respaldos_tusede.dart';

class PantallaRespaldosClub extends StatefulWidget {
  final List<Map<String, dynamic>> clubes;
  final String? clubId;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  ejecutar;
  const PantallaRespaldosClub({
    super.key,
    required this.clubes,
    this.clubId,
    this.ejecutar,
  });
  @override
  State<PantallaRespaldosClub> createState() => _RespaldosState();
}

class _RespaldosState extends State<PantallaRespaldosClub> {
  bool _ocupado = false;
  String? _error, _mensaje, _club;
  dynamic _siguiente;
  List<Map<String, dynamic>> _operaciones = [];
  Future<Map<String, dynamic>> _api(
    String a, [
    Map<String, dynamic> d = const {},
  ]) => (widget.ejecutar ?? ServicioRespaldosTuSede.ejecutar)(a, d);
  @override
  void initState() {
    super.initState();
    _club = widget.clubId;
    _operar(() => _leer());
  }

  Future<void> _leer({bool mas = false}) async {
    final r = await _api('listar', {
      if (mas && _siguiente != null) 'antes': _siguiente,
    });
    if (!mounted) return;
    setState(() {
      final nuevas = (r['operaciones'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _operaciones = mas ? [..._operaciones, ...nuevas] : nuevas;
      _siguiente = r['siguiente'];
    });
  }

  Future<void> _operar(Future<void> Function() fn) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _continuar(Map<String, dynamic> job) async {
    while (mounted && job['estado'] != 'completado') {
      setState(
        () => _mensaje =
            '${job['tipo'] == 'respaldo' ? 'Respaldando' : 'Recuperando'} · ${job['estado']} · ${job['procesados'] ?? 0} procesados. Podés salir y retomar desde el listado.',
      );
      job = await _api('continuar', {'operacionId': job['id']});
    }
    if (!mounted) return;
    setState(
      () => _mensaje = job['tipo'] == 'respaldo'
          ? 'Respaldo completo y verificado.'
          : 'Recuperación completa: ${job['destino']} quedó en borrador. Revisá sus datos y asigná nuevamente sus administradores.',
    );
    await _leer();
  }

  Future<void> _crear() async {
    if (_club == null) return;
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear respaldo del club'),
        content: Text(
          'Se copiarán los documentos e imágenes de $_club al almacenamiento privado. No incluye cuentas, contraseñas ni archivos alojados en otros sitios.\n\nEsta versión admite hasta 500 documentos y 100 archivos (256 MB en total). El almacenamiento genera consumo en Google Cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear respaldo'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _operar(() async {
      final job = await _api('crear', {'clubId': _club, 'operacionId': id});
      await _leer();
      await _continuar(job);
    });
  }

  Future<void> _restaurar(Map<String, dynamic> backup) async {
    final destino = TextEditingController(),
        confirmacion = TextEditingController();
    final form = GlobalKey<FormState>();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar como club nuevo'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Se creará un borrador con otro identificador. No se sobrescribe el club original ni se reactivan usuarios. La matriz de permisos y las claves de seguridad se configuran nuevamente.',
                ),
                if ((backup['enlacesExternos'] as num? ?? 0) > 0)
                  const Text(
                    'Hay enlaces externos: se conservan, pero sus archivos no forman parte de la copia.',
                  ),
                TextFormField(
                  controller: destino,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo identificador',
                  ),
                  validator: (v) =>
                      RegExp(r'^[a-z0-9][a-z0-9_-]{1,39}$').hasMatch(v ?? '')
                      ? null
                      : 'Usá 2 a 40 minúsculas, números o guiones',
                ),
                TextFormField(
                  controller: confirmacion,
                  decoration: const InputDecoration(
                    labelText: 'Repetí el nuevo identificador',
                  ),
                  validator: (v) => v == destino.text && (v ?? '').isNotEmpty
                      ? null
                      : 'Los identificadores deben coincidir',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, destino.text);
              }
            },
            child: const Text('Recuperar borrador'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    destino.dispose();
    confirmacion.dispose();
    if (id == null || !mounted) return;
    await _operar(() async {
      final job = await _api('restaurar', {
        'respaldoId': backup['id'],
        'destino': id,
        'confirmacion': id,
      });
      await _leer();
      await _continuar(job);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Respaldos y recuperación'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _ocupado ? null : () => _operar(() => _leer()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Una copia para volver atrás',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Respaldos privados de los datos e imágenes de cada club. Solo el superadmin puede crearlos y recuperarlos. Permanecen disponibles al eliminar el club original.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _club,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Club a respaldar'),
          items: widget.clubes
              .where(
                (c) =>
                    c['origenDatos'] == 'central' &&
                    ['activo', 'borrador'].contains(c['estado']),
              )
              .map(
                (c) => DropdownMenuItem(
                  value: c['id'].toString(),
                  child: Text(c['nombre'].toString()),
                ),
              )
              .toList(),
          onChanged: _ocupado ? null : (v) => setState(() => _club = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _ocupado || _club == null ? null : _crear,
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Nuevo respaldo'),
        ),
        if (_ocupado) const LinearProgressIndicator(),
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_mensaje!),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Historial',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (!_ocupado && _operaciones.isEmpty && _error == null)
          const Text('Todavía no hay respaldos.'),
        for (final j in _operaciones)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${j['tipo'] == 'respaldo' ? 'Respaldo' : 'Recuperación'} · ${j['nombre']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${j['destino'] ?? j['clubId']} · ${j['estado']}'),
                  Text(
                    DateTime.fromMillisecondsSinceEpoch(
                      (j['creadoMs'] as num).toInt(),
                    ).toLocal().toString().split('.').first,
                  ),
                  if (j['documentos'] != null)
                    Text(
                      '${j['documentos']} documentos · ${j['archivos']} archivos',
                    ),
                  if (j['estado'] != 'completado')
                    TextButton.icon(
                      onPressed: _ocupado
                          ? null
                          : () => _operar(() => _continuar(j)),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Retomar'),
                    ),
                  if (j['tipo'] == 'respaldo' && j['estado'] == 'completado')
                    TextButton.icon(
                      onPressed: _ocupado ? null : () => _restaurar(j),
                      icon: const Icon(Icons.restore),
                      label: const Text('Recuperar como borrador'),
                    ),
                ],
              ),
            ),
          ),
        if (_siguiente != null)
          TextButton(
            onPressed: _ocupado ? null : () => _operar(() => _leer(mas: true)),
            child: const Text('Ver anteriores'),
          ),
      ],
    ),
  );
}
