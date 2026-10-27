import 'package:flutter/material.dart';
import '../servicios/servicio_plataforma_tusede.dart';
import '../servicios/servicio_firebase_tusede.dart';

class PantallaEquipoClub extends StatefulWidget {
  final String clubId, nombreClub;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  ejecutar;
  const PantallaEquipoClub({
    super.key,
    required this.clubId,
    required this.nombreClub,
    this.ejecutar,
  });
  @override
  State<PantallaEquipoClub> createState() => _EquipoState();
}

class _EquipoState extends State<PantallaEquipoClub> {
  static const roles = {
    'tesoreria': 'Tesorería',
    'administracion': 'Administración',
    'deportes': 'Deportes',
    'institucional': 'Comunicación',
    'ingreso': 'Control de ingreso',
  };
  bool _ocupado = false;
  String? _error, _mensaje;
  List<Map<String, dynamic>> _usuarios = [];
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<Map<String, dynamic>> _api(
    String accion, [
    Map<String, dynamic> datos = const {},
  ]) => (widget.ejecutar ?? ServicioPlataformaTuSede.ejecutar)(accion, {
    'clubId': widget.clubId,
    ...datos,
  });
  Future<void> _leer() async {
    final r = await _api('listarEquipo');
    if (mounted)
      setState(
        () => _usuarios = (r['usuarios'] as List)
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList(),
      );
  }

  Future<void> _operar(Future<void> Function() operacion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await operacion();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cargar() => _operar(_leer);
  Future<void> _formulario([Map<String, dynamic>? usuario]) async {
    final nombre = TextEditingController();
    final email = TextEditingController();
    final form = GlobalKey<FormState>();
    var rol = usuario?['rol']?.toString() ?? 'administracion';
    var activo = usuario?['activo'] == true;
    var confirmado = false;
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, cambiar) => AlertDialog(
          title: Text(
            usuario == null ? 'Nueva cuenta del club' : 'Editar acceso',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (usuario == null) ...[
                      TextFormField(
                        controller: nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y apellido',
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Ingresá el nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo real del usuario',
                        ),
                        validator: (v) =>
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch((v ?? '').trim())
                            ? 'Ingresá un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ] else
                      Text('${usuario['nombre']}\n${usuario['email']}'),
                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: roles.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => cambiar(() => rol = v!),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Los accesos de cada rol se configuran en Matriz de Permisos. La cuenta tendrá acceso únicamente a este club.',
                    ),
                    if (usuario == null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Confirmé que el titular tiene acceso al correo.',
                        ),
                        value: confirmado,
                        onChanged: (v) => cambiar(() => confirmado = v == true),
                      ),
                    if (usuario != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Acceso activo al club'),
                        value: activo,
                        onChanged: (v) => cambiar(() => activo = v),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: usuario == null && !confirmado
                  ? null
                  : () {
                      if (form.currentState!.validate())
                        Navigator.pop(ctx, {
                          'rol': rol,
                          if (usuario == null) ...{
                            'nombre': nombre.text.trim(),
                            'email': email.text.trim().toLowerCase(),
                          } else ...{
                            'uid': usuario['uid'],
                            'activo': activo,
                          },
                        });
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    // El diálogo aún puede estar terminando su animación al resolver el Future.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    nombre.dispose();
    email.dispose();
    if (!mounted || datos == null) return;
    await _operar(() async {
      final r = await _api(
        usuario == null ? 'crearEquipo' : 'editarEquipo',
        datos,
      );
      if (mounted)
        setState(
          () => _mensaje = usuario == null
              ? (r['yaExistia'] == true
                    ? 'La cuenta ya existía. Revisá su rol y estado en el listado.'
                    : 'Cuenta creada. Usá Enviar enlace para que el titular establezca su contraseña.')
              : 'Acceso actualizado.',
        );
      await _leer();
    });
  }

  Future<void> _correo(Map<String, dynamic> usuario) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar enlace de contraseña'),
        content: Text(
          'Se enviará a ${usuario['email']} para que el titular establezca o recupere su contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (!mounted || si != true) return;
    await _operar(() async {
      await ServicioFirebaseTuSede.auth.sendPasswordResetEmail(
        email: usuario['email'].toString(),
      );
      if (mounted)
        setState(
          () => _mensaje = 'Solicitud de correo enviada. Revisá también Spam.',
        );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Usuarios · ${widget.nombreClub}'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _ocupado ? null : _cargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _ocupado || _error != null ? null : () => _formulario(),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Crear usuario'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const Text(
          'Equipo del club',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configurá primero la Matriz de Permisos. Las cuentas de administradores y las compartidas se muestran protegidas.',
        ),
        const SizedBox(height: 16),
        if (_ocupado) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_mensaje!),
          ),
        if (!_ocupado && _error == null && _usuarios.isEmpty)
          const Text('Todavía no hay usuarios asignados.'),
        for (final u in _usuarios)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u['nombre'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(u['email'].toString()),
                  Text(
                    '${roles[u['rol']] ?? u['rol']} · ${u['activo'] == true ? 'Activo' : 'Desactivado'}',
                  ),
                  if (u['editable'] == true)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _ocupado ? null : () => _formulario(u),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Rol y acceso'),
                        ),
                        TextButton.icon(
                          onPressed: _ocupado || u['activo'] != true
                              ? null
                              : () => _correo(u),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Enviar enlace'),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Cuenta protegida',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
