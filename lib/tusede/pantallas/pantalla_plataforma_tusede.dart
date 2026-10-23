import '../diseno/identidad_tusede.dart';
import '../diseno/tarjeta_gestion_tusede.dart';
import 'dart:convert';
import 'pantalla_eliminar_club.dart';
import 'paleta_color_club.dart';
import 'pantalla_catalogo_tusede.dart';
import 'pantalla_administradores_club.dart';
import '../servicios/contexto_usuario_tusede.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../configuracion/modulos_tusede.dart';
import '../servicios/servicio_firebase_tusede.dart';
import '../servicios/servicio_plataforma_tusede.dart';

class PantallaPlataformaTuSede extends StatefulWidget {
  const PantallaPlataformaTuSede({super.key});
  @override
  State<PantallaPlataformaTuSede> createState() => _PlataformaState();
}

class _PlataformaState extends State<PantallaPlataformaTuSede> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocupado = false;
  bool _autorizado = false;
  String? _error;
  List<Map<String, dynamic>> _clubes = [];

  @override
  void initState() {
    super.initState();
    if (ServicioFirebaseTuSede.auth.currentUser != null) _cargar();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final resultado = await ServicioPlataformaTuSede.ejecutar('listar', {});
      if (!mounted) return;
      setState(() {
        _clubes = (resultado['clubes'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _autorizado = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await ServicioFirebaseTuSede.auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      ContextoUsuarioTuSede.limpiar();
      _password.clear();
      if (mounted) await _cargar();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo iniciar sesión. Revisá tus credenciales de TuSede.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salir() async {
    await ServicioFirebaseTuSede.auth.signOut();
    ContextoUsuarioTuSede.limpiar();
    if (mounted) {
      setState(() {
        _autorizado = false;
        _clubes = [];
        _error = null;
      });
    }
  }

  Future<void> _nuevoClub() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _AltaClub()));
    if (mounted) await _cargar();
  }

  Future<void> _activarClub(Map<String, dynamic> club) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activar club'),
        content: Text(
          '¿Publicar ${club['nombre']} en TuSede? Aparecerá en el catálogo y podrá recibir visitas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await ServicioPlataformaTuSede.ejecutar('activar', {
        'clubId': club['id'],
      });
      if (mounted) await _cargar();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _ocupado = false;
        });
      }
    }
  }

  Future<void> _eliminarClub(Map<String, dynamic> club) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaEliminarClub(
          clubId: club['id'].toString(),
          nombre: club['nombre'].toString(),
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _editarClub(Map<String, dynamic> club) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _AltaClub(club: club)));
    if (mounted) await _cargar();
  }

  Future<void> _logo(Map<String, dynamic> club) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final archivo = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (archivo == null) return;
      final bytes = archivo.files.single.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        throw Exception('Elegí una imagen PNG o JPG de hasta 4 MB.');
      }
      final resultado = await ServicioPlataformaTuSede.ejecutar('logo', {
        'clubId': club['id'],
        'base64': base64Encode(bytes),
      });
      final url = resultado['logoUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('El servidor no devolvió la dirección del logo.');
      }
      if (!mounted) return;
      setState(() {
        club['identidad'] = {...?(club['identidad'] as Map?), 'logoUrl': url};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo guardado correctamente.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo subir el logo: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo subir el logo: $e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _tarjetaClub(Map<String, dynamic> club) {
    final central = club['origenDatos'] == 'central';
    final borrador = club['estado'] == 'borrador';
    final activo = club['activo'] == true;
    return TarjetaGestionTuSede(
      club: club,
      ocupado: _ocupado,
      onAbrir: borrador
          ? () => _editarClub(club)
          : activo && (central || club['id'] == 'generico')
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PantallaEspacioClub(club: club),
              ),
            )
          : null,
      onEditar: central && (borrador || (club['estado'] == 'activo' && activo))
          ? () => _editarClub(club)
          : null,
      onAdministradores:
          (central || club['id'] == 'generico') && (borrador || activo)
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PantallaAdministradoresClub(
                  clubId: club['id'].toString(),
                  nombreClub: club['nombre'].toString(),
                ),
              ),
            )
          : null,
      onLogo: borrador ? () => _logo(club) : null,
      onActivar: borrador ? () => _activarClub(club) : null,
      onEliminar:
          central &&
              ![
                'guemes',
                'fatima',
                'laloma',
                'generico',
                'tusede',
              ].contains(club['id'])
          ? () => _eliminarClub(club)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conectado = ServicioFirebaseTuSede.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: const MarcaTuSede(),
        actions: [
          if (conectado)
            IconButton(
              onPressed: _ocupado ? null : _salir,
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
            ),
        ],
      ),
      floatingActionButton: _autorizado
          ? FloatingActionButton.extended(
              onPressed: _ocupado ? null : _nuevoClub,
              icon: const Icon(Icons.add),
              label: const Text('Crear club'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CabeceraTuSede(
                  etiqueta: _autorizado
                      ? 'TuSede / Administración'
                      : 'Acceso a la plataforma',
                  titulo: _autorizado
                      ? 'Un lugar para\ntodos tus clubes.'
                      : 'Hagamos crecer\ntu comunidad.',
                  descripcion: _autorizado
                      ? 'Creá, personalizá y acompañá a cada club desde acá.'
                      : 'Ingresá con tu cuenta de superadmin para gestionar TuSede.',
                  pie: _autorizado
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            EtiquetaTuSede(
                              '${_clubes.length} ${_clubes.length == 1 ? 'club' : 'clubes'}',
                              oscura: true,
                            ),
                            EtiquetaTuSede(
                              '${_clubes.where((c) => c['estado'] == 'borrador').length} borradores',
                              oscura: true,
                            ),
                          ],
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                if (_ocupado) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (!_autorizado && !conectado) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email superadmin',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) {
                      if (!_ocupado) _entrar();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ocupado ? null : _entrar,
                    child: const Text('Ingresar'),
                  ),
                ],
                if (conectado)
                  TextButton(
                    onPressed: _ocupado ? null : _cargar,
                    child: const Text('Actualizar listado'),
                  ),
                if (_autorizado) ...[
                  Text(
                    'Tus clubes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text('Los borradores se publican cuando los activás.'),
                  const SizedBox(height: 20),
                  if (_clubes.isEmpty) const Text('Todavía no hay clubes.'),
                  for (final club in _clubes) _tarjetaClub(club),
                  const SizedBox(height: 80),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AltaClub extends StatefulWidget {
  final Map<String, dynamic>? club;
  const _AltaClub({this.club});
  @override
  State<_AltaClub> createState() => _AltaClubState();
}

class _AltaClubState extends State<_AltaClub> {
  final _form = GlobalKey<FormState>();
  final _campos = {
    for (final key in [
      'id',
      'nombre',
      'nombreCorto',
      'lema',
      'colorPrimario',
      'colorSecundario',
    ])
      key: TextEditingController(),
  };
  final _modulos = <String>{'socios', 'deportes', 'noticias', 'avisos'};
  bool _ocupado = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _campos['colorPrimario']!.text = '#1565C0';
    _campos['colorSecundario']!.text = '#FFC107';
    final club = widget.club;
    if (club != null) {
      final identidad = Map<String, dynamic>.from(
        club['identidad'] as Map? ?? {},
      );
      for (final key in _campos.keys) {
        _campos[key]!.text =
            (key == 'id' || key == 'nombre' ? club[key] : identidad[key])
                ?.toString() ??
            '';
      }
      _modulos.clear();
      final modulos = club['modulos'] as Map? ?? {};
      _modulos.addAll(ModulosTuSede.todos.where((key) => modulos[key] == true));
    }
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await ServicioPlataformaTuSede.ejecutar(
        widget.club == null ? 'crear' : 'editar',
        {
          'club': {
            for (final entry in _campos.entries)
              entry.key: entry.value.text.trim(),
            'modulos': _modulos.toList(),
          },
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Color _colorVista(String key, Color fallback) {
    final texto = _campos[key]!.text.trim();
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(texto)) return fallback;
    return Color(int.parse('FF${texto.substring(1)}', radix: 16));
  }

  Future<void> _elegirColor(String key) async {
    if (_ocupado) return;
    final color = await elegirColorClub(
      context,
      _colorVista(
        key,
        key == 'colorPrimario'
            ? const Color(0xFF1565C0)
            : const Color(0xFFFFC107),
      ),
    );
    if (!mounted || color == null) return;
    setState(() {
      _campos[key]!.text =
          '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    });
  }

  Widget _vistaPrevia() {
    final primario = _colorVista('colorPrimario', const Color(0xFF1565C0));
    final secundario = _colorVista('colorSecundario', const Color(0xFFFFC107));
    final logo =
        (widget.club?['identidad'] as Map?)?['logoUrl']?.toString() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primario, secundario]),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: logo.isEmpty
                      ? Icon(Icons.groups, size: 40, color: primario)
                      : ClipOval(
                          child: Image.network(
                            logo,
                            width: 72,
                            height: 72,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            errorBuilder: (_, error, stack) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _campos['nombre']!.text.trim().isEmpty
                            ? 'Nombre del club'
                            : _campos['nombre']!.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_campos['lema']!.text.trim().isNotEmpty)
                        Text(
                          _campos['lema']!.text.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final modulo in ModulosTuSede.todos.where(
                  _modulos.contains,
                ))
                  Chip(label: Text(modulo)),
                if (_modulos.isEmpty) const Text('Sin módulos seleccionados'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.club == null ? 'Crear club' : 'Editar club'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              Text(
                'La identidad de tu club',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Elegí cómo se presenta tu comunidad en TuSede.'),
              const SizedBox(height: 24),
              for (final campo in _campos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: campo.value,
                    readOnly: campo.key.startsWith('color'),
                    onTap: campo.key.startsWith('color')
                        ? () => _elegirColor(campo.key)
                        : null,
                    enabled:
                        !_ocupado && (campo.key != 'id' || widget.club == null),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: campo.key.startsWith('color')
                          ? Icon(
                              Icons.circle,
                              color: _colorVista(campo.key, Colors.grey),
                            )
                          : null,
                      suffixIcon: campo.key.startsWith('color')
                          ? IconButton(
                              tooltip: 'Elegir color',
                              onPressed: _ocupado
                                  ? null
                                  : () => _elegirColor(campo.key),
                              icon: const Icon(Icons.palette_outlined),
                            )
                          : null,
                      helperText: campo.key.startsWith('color')
                          ? 'Tocá para abrir la paleta'
                          : null,
                      labelText: {
                        'id': 'Identificador único (ej. club-san-martin)',
                        'nombre': 'Nombre del club',
                        'nombreCorto': 'Nombre corto',
                        'lema': 'Lema',
                        'colorPrimario': 'Color principal',
                        'colorSecundario': 'Color secundario',
                      }[campo.key],
                    ),
                    validator: (valor) {
                      final texto = (valor ?? '').trim();
                      if (campo.key == 'id' &&
                          !RegExp(
                            r'^[a-z0-9][a-z0-9_-]{1,39}$',
                          ).hasMatch(texto)) {
                        return 'Usá entre 2 y 40 letras minúsculas, números o guiones.';
                      }
                      if (campo.key == 'nombre' &&
                          (texto.length < 2 || texto.length > 100)) {
                        return 'Ingresá un nombre de entre 2 y 100 caracteres.';
                      }
                      if (campo.key.startsWith('color') &&
                          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(texto)) {
                        return 'Ingresá un color con formato #RRGGBB.';
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Módulos del club',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Activá o desactivá módulos. Desactivarlos no borra los datos cargados.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final modulo in ModulosTuSede.todos)
                    FilterChip(
                      label: Text(modulo),
                      selected: _modulos.contains(modulo),
                      onSelected: _ocupado
                          ? null
                          : (valor) => setState(() {
                              if (valor) {
                                _modulos.add(modulo);
                              } else {
                                _modulos.remove(modulo);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Vista previa de identidad'),
              const SizedBox(height: 8),
              _vistaPrevia(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _ocupado ? null : _guardar,
                child: Text(
                  _ocupado
                      ? 'Guardando…'
                      : widget.club == null
                      ? 'Crear borrador'
                      : 'Guardar cambios',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
