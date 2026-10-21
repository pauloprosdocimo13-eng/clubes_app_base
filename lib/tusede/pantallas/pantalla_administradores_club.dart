import 'package:flutter/material.dart';

import '../servicios/servicio_firebase_tusede.dart';
import '../servicios/servicio_plataforma_tusede.dart';

class PantallaAdministradoresClub extends StatefulWidget {
  final String clubId;
  final String nombreClub;
  const PantallaAdministradoresClub({
    super.key,
    required this.clubId,
    required this.nombreClub,
  });

  @override
  State<PantallaAdministradoresClub> createState() => _AdministradoresState();
}

class _AdministradoresState extends State<PantallaAdministradoresClub> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  bool _ocupado = false;
  bool _correoConfirmado = false;
  bool _listadoCargado = false;
  String? _error;
  String? _mensaje;
  List<Map<String, dynamic>> _administradores = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _leerListado() async {
    final respuesta = await ServicioPlataformaTuSede.ejecutar(
      'listarAdministradores',
      {'clubId': widget.clubId},
    );
    if (!mounted) return;
    setState(() {
      _administradores = (respuesta['administradores'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _listadoCargado = true;
    });
  }

  Future<void> _cargar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _leerListado();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _listadoCargado = false;
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _asignar() async {
    if (_ocupado || !_correoConfirmado || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
      _mensaje = null;
    });
    try {
      final respuesta =
          await ServicioPlataformaTuSede.ejecutar('asignarAdministrador', {
            'clubId': widget.clubId,
            'nombre': _nombre.text.trim(),
            'email': _email.text.trim().toLowerCase(),
          });
      if (!mounted) return;
      final admin = respuesta['administrador'] as Map;
      setState(() {
        _mensaje = admin['yaExistia'] == true
            ? 'Esta cuenta ya está asignada al club. Podés enviarle el enlace para establecer su contraseña.'
            : 'Administrador asignado. Enviá el enlace desde su ficha para que establezca su contraseña.';
        _correoConfirmado = false;
      });
      _nombre.clear();
      _email.clear();
      // El alta ya está confirmada aunque una recarga posterior falle.
      await _leerListado();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarEnlace(String email) async {
    if (_ocupado) return;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar enlace de contraseña'),
        content: Text(
          'Firebase enviará un correo a $email para establecer o restablecer su contraseña. ¿Enviar ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar correo'),
          ),
        ],
      ),
    );
    if (!mounted || aceptar != true) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await ServicioFirebaseTuSede.auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(
          () => _mensaje =
              'Solicitud enviada para $email. Pedile que revise también Spam. Luego debe entrar desde el catálogo a ${widget.nombreClub} → Administración.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo solicitar el correo. La cuenta sigue asignada; podés reintentar el envío más tarde.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Administradores · ${widget.nombreClub}')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_ocupado) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_mensaje != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_mensaje!),
              ),
            TextButton(
              onPressed: _ocupado ? null : _cargar,
              child: const Text('Actualizar administradores'),
            ),
            if (_listadoCargado && _administradores.isEmpty)
              const Text(
                'Este club todavía no tiene administradores asignados.',
              ),
            for (final admin in _administradores)
              Card(
                child: ListTile(
                  title: Text(admin['nombre'].toString()),
                  subtitle: Text(
                    '${admin['email']} · ${admin['activo'] == true ? 'Activo' : 'Inactivo'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Enviar enlace para establecer contraseña',
                    icon: const Icon(Icons.mail_outline),
                    onPressed: _ocupado || admin['activo'] != true
                        ? null
                        : () => _enviarEnlace(admin['email'].toString()),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Nuevo administrador',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tendrá acceso administrativo únicamente a ${widget.nombreClub}. Usá un correo nuevo en TuSede y accesible por su titular.',
            ),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombre,
                    enabled: !_ocupado,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y apellido',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().length < 2 ||
                            (v ?? '').trim().length > 100
                        ? 'Ingresá entre 2 y 100 caracteres.'
                        : null,
                  ),
                  TextFormField(
                    controller: _email,
                    enabled: !_ocupado,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo real del administrador',
                    ),
                    onChanged: (_) {
                      if (_correoConfirmado) {
                        setState(() => _correoConfirmado = false);
                      }
                    },
                    validator: (v) =>
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch((v ?? '').trim())
                        ? 'Ingresá un correo válido.'
                        : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Confirmé que el titular tiene acceso a este correo.',
                    ),
                    value: _correoConfirmado,
                    onChanged: _ocupado
                        ? null
                        : (v) => setState(() => _correoConfirmado = v == true),
                  ),
                  FilledButton(
                    onPressed:
                        _ocupado || !_correoConfirmado || !_listadoCargado
                        ? null
                        : _asignar,
                    child: const Text('Asignar administrador'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
