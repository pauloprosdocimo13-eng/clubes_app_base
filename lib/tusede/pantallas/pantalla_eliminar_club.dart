import 'package:flutter/material.dart';
import '../servicios/servicio_plataforma_tusede.dart';

class PantallaEliminarClub extends StatefulWidget {
  final String clubId;
  final String nombre;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  ejecutar;
  const PantallaEliminarClub({
    super.key,
    required this.clubId,
    required this.nombre,
    this.ejecutar,
  });

  @override
  State<PantallaEliminarClub> createState() => _EliminarClubState();
}

class _EliminarClubState extends State<PantallaEliminarClub> {
  final _confirmacion = TextEditingController();
  Map<String, dynamic>? _plan;
  bool _ocupado = false;
  bool _iniciada = false;
  bool _completada = false;
  String? _error;
  String _estado = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _solicitar(
    String accion,
    Map<String, dynamic> datos,
  ) {
    return widget.ejecutar != null
        ? widget.ejecutar!(accion, datos)
        : ServicioPlataformaTuSede.ejecutar(accion, datos);
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final plan = await _solicitar('prepararEliminacion', {
        'clubId': widget.clubId,
      });
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _iniciada = plan['enCurso'] == true;
        _estado = plan['estado']?.toString() ?? '';
        _completada = _estado == 'completada';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _ejecutar() async {
    if (_ocupado || _plan == null || _completada) return;
    if (!_iniciada && _confirmacion.text != widget.clubId) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (!_iniciada) {
        await _solicitar('iniciarEliminacion', {
          'clubId': widget.clubId,
          'confirmacion': _confirmacion.text,
          'token': _plan!['token'],
        });
        if (!mounted) return;
        setState(() {
          _iniciada = true;
          _estado = 'usuarios';
        });
      }
      while (mounted) {
        final result = await _solicitar('continuarEliminacion', {
          'clubId': widget.clubId,
        });
        if (!mounted) return;
        setState(() {
          _estado = result['estado'].toString();
          _completada = _estado == 'completada';
        });
        if (_completada) break;
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = '$e\nUsá Actualizar estado antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = (_plan?['cuentas'] as List?) ?? [];
    final colecciones = (_plan?['colecciones'] as List?) ?? [];
    const etapas = {
      'usuarios':
          'Preparando y retirando cuentas del club. El primer paso espera aproximadamente un minuto.',
      'documentos': 'Eliminando documentos del club.',
      'archivos': 'Eliminando archivos del club.',
      'verificando': 'Verificando que no queden datos ni cuentas pendientes.',
      'completada': 'Eliminación completada y verificada.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar club')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.nombre,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(widget.clubId),
              const SizedBox(height: 16),
              if (_ocupado) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_iniciada) ...[
                const SizedBox(height: 16),
                Text(etapas[_estado] ?? 'Eliminación en curso.'),
                if (!_completada)
                  const Text(
                    'El club ya no está disponible. Si cerrás esta pantalla, podés retomar desde Administración de clubes. La operación no se puede deshacer.',
                  ),
              ] else if (_plan != null) ...[
                const Text(
                  'Se eliminarán el club, todos sus documentos y subcolecciones, y los archivos guardados en su carpeta de TuSede. No se crea un respaldo.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Colecciones encontradas: ${colecciones.isEmpty ? "ninguna" : colecciones.join(", ")}.',
                ),
                Text(
                  'Versiones de archivos encontradas: ${_plan!["archivos"]}${_plan!["masArchivos"] == true ? " o más" : ""}.',
                ),
                const SizedBox(height: 12),
                const Text('Cuentas asociadas:'),
                if (cuentas.isEmpty) const Text('No hay cuentas asociadas.'),
                for (final cuenta in cuentas)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${cuenta["nombre"]} · ${cuenta["email"]}'),
                    subtitle: Text(
                      cuenta['tipo'] == 'exclusiva'
                          ? 'Se eliminarán la cuenta de acceso y su perfil.'
                          : 'Se conserva la cuenta y se retira únicamente este club.',
                    ),
                  ),
                const Text(
                  'Se conserva la auditoría. Las imágenes externas y las retenciones automáticas de Storage no se purgan. Güemes y los demás clubes quedan fuera de esta operación.',
                ),
                const SizedBox(height: 16),
                Text('Para confirmar, escribí exactamente: ${widget.clubId}'),
                TextField(
                  controller: _confirmacion,
                  enabled: !_ocupado,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Identificador del club',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 20),
              if (!_completada) ...[
                TextButton(
                  onPressed: _ocupado ? null : _cargar,
                  child: const Text('Actualizar estado'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed:
                      _ocupado ||
                          _plan == null ||
                          (!_iniciada && _confirmacion.text != widget.clubId)
                      ? null
                      : _ejecutar,
                  child: Text(
                    _iniciada
                        ? 'Continuar eliminación'
                        : 'Eliminar definitivamente',
                  ),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver al listado'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
