import 'package:flutter/material.dart';

import '../modelos/admin_inventario_tusede.dart';
import '../servicios/contexto_club.dart';
import '../servicios/servicio_inventario_admins_tusede.dart';
import '../servicios/servicio_preparacion_migracion_admin.dart';

class PantallaInventarioAdminsTuSede extends StatefulWidget {
  const PantallaInventarioAdminsTuSede({super.key});

  @override
  State<PantallaInventarioAdminsTuSede> createState() =>
      _PantallaInventarioAdminsTuSedeState();
}

class _PantallaInventarioAdminsTuSedeState
    extends State<PantallaInventarioAdminsTuSede> {
  bool _cargando = true;

  String? _error;

  final Set<String> _preparando = {};

  List<AdminInventarioTuSede> _usuarios = [];

  @override
  void initState() {
    super.initState();

    _cargar();
  }

  // ============================================================
  // CARGAR
  // ============================================================

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final resultado = await ServicioInventarioAdminsTuSede.cargar();

      if (!mounted) {
        return;
      }

      setState(() {
        _usuarios = resultado;
        _cargando = false;
      });
    } on InventarioAdminsTuSedeException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'No se pudo cargar el inventario: $e';

        _cargando = false;
      });
    }
  }

  // ============================================================
  // CONTADORES
  // ============================================================

  int get _cantidadVinculados {
    return _usuarios
        .where((u) => u.estado == EstadoMigracionAdmin.vinculado)
        .length;
  }

  int get _cantidadPendientes {
    return _usuarios
        .where((u) => u.estado == EstadoMigracionAdmin.soloLegacy)
        .length;
  }

  int get _cantidadPreparados {
    return _usuarios
        .where(
          (u) => u.migracionPreparada && u.preparacionValida && !u.existeTuSede,
        )
        .length;
  }

  int get _cantidadRevisar {
    return _usuarios
        .where((u) => u.estado == EstadoMigracionAdmin.revisar)
        .length;
  }

  // ============================================================
  // PREPARAR
  // ============================================================

  Future<void> _preparar(AdminInventarioTuSede usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Preparar migración'),
          content: Text(
            'Se preparará la migración de:\n\n'
            '${usuario.email}\n\n'
            'Rol actual: '
            '${usuario.rolLegacy.toUpperCase()}\n'
            'Rol TuSede: '
            '${usuario.rolSugeridoTuSede.toUpperCase()}\n\n'
            'Esto NO crea una cuenta nueva, '
            'NO cambia la contraseña y '
            'NO modifica los permisos actuales de Güemes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Preparar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _preparando.add(usuario.email);
    });

    try {
      await ServicioPreparacionMigracionAdmin.preparar(usuario);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Migración preparada para '
            '${usuario.email}.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _cargar();
    } on PreparacionMigracionAdminException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparando migración: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _preparando.remove(usuario.email);
        });
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: Colors.white,
        title: const Text('Migración de administradores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContenido(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),

            const SizedBox(height: 15),

            Text(_error!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey[200]!),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.blueGrey),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Preparar una migración solamente '
                    'crea una autorización interna de TuSede. '
                    'No crea cuentas, no guarda contraseñas '
                    'y no modifica los permisos de Güemes.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Club actual: '
            '${ContextoClub.nombreClub}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          Text(
            'clubId: '
            '${ContextoClub.clubId}',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResumenCard(
                titulo: 'Total',
                valor: _usuarios.length,
                icono: Icons.people,
                color: Colors.blueGrey,
              ),

              _ResumenCard(
                titulo: 'Vinculados',
                valor: _cantidadVinculados,
                icono: Icons.cloud_done,
                color: Colors.green,
              ),

              _ResumenCard(
                titulo: 'Pendientes',
                valor: _cantidadPendientes,
                icono: Icons.schedule,
                color: Colors.orange,
              ),

              _ResumenCard(
                titulo: 'Preparados',
                valor: _cantidadPreparados,
                icono: Icons.playlist_add_check_circle,
                color: Colors.teal,
              ),

              _ResumenCard(
                titulo: 'Revisar',
                valor: _cantidadRevisar,
                icono: Icons.warning_amber,
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 25),

          const Text(
            'Administradores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ..._usuarios.map(_buildUsuario),
        ],
      ),
    );
  }

  Widget _buildUsuario(AdminInventarioTuSede usuario) {
    final estado = _datosEstado(usuario.estado);

    final preparando = _preparando.contains(usuario.email);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: estado.color.withOpacity(0.15),
                  child: Icon(estado.icono, color: estado.color),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        usuario.email,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: estado.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estado.color),
                  ),
                  child: Text(
                    estado.texto,
                    style: TextStyle(
                      color: estado.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipDato(
                  titulo: 'Legacy',
                  valor: usuario.existeLegacy
                      ? usuario.rolLegacy.isEmpty
                            ? 'SIN ROL'
                            : usuario.rolLegacy.toUpperCase()
                      : 'NO',
                ),

                _ChipDato(
                  titulo: 'TuSede',
                  valor: usuario.existeTuSede
                      ? usuario.rolTuSede.isEmpty
                            ? 'SIN ROL'
                            : usuario.rolTuSede.toUpperCase()
                      : 'NO',
                ),

                if (usuario.existeLegacy &&
                    usuario.rolSugeridoTuSede.isNotEmpty)
                  _ChipDato(
                    titulo: 'Sugerido',
                    valor: usuario.rolSugeridoTuSede.toUpperCase(),
                    destacado: !usuario.existeTuSede,
                  ),

                if (usuario.migracionPreparada)
                  _ChipDato(
                    titulo: 'Preparación',
                    valor: usuario.preparacionValida ? 'LISTA' : 'REVISAR',
                    colorEspecial: usuario.preparacionValida
                        ? Colors.teal
                        : Colors.red,
                  ),
              ],
            ),

            if (usuario.migracionPreparada &&
                usuario.preparacionValida &&
                !usuario.existeTuSede) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Colors.teal, size: 18),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Migración autorizada y preparada. '
                        'La cuenta todavía NO fue creada '
                        'en Authentication TuSede.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (usuario.estado == EstadoMigracionAdmin.revisar &&
                usuario.motivoRevision.isNotEmpty) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  usuario.motivoRevision,
                  style: TextStyle(
                    color: Colors.red[900],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (usuario.puedePrepararse) ...[
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: preparando ? null : () => _preparar(usuario),
                  icon: preparando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check),
                  label: Text(
                    preparando ? 'PREPARANDO...' : 'PREPARAR MIGRACIÓN',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _DatosEstado _datosEstado(EstadoMigracionAdmin estado) {
    switch (estado) {
      case EstadoMigracionAdmin.vinculado:
        return const _DatosEstado(
          texto: 'VINCULADO',
          color: Colors.green,
          icono: Icons.verified_user,
        );

      case EstadoMigracionAdmin.soloLegacy:
        return const _DatosEstado(
          texto: 'PENDIENTE',
          color: Colors.orange,
          icono: Icons.schedule,
        );

      case EstadoMigracionAdmin.soloTuSede:
        return const _DatosEstado(
          texto: 'SOLO TUSEDE',
          color: Colors.blue,
          icono: Icons.cloud,
        );

      case EstadoMigracionAdmin.revisar:
        return const _DatosEstado(
          texto: 'REVISAR',
          color: Colors.red,
          icono: Icons.warning_amber,
        );
    }
  }
}

class _ResumenCard extends StatelessWidget {
  final String titulo;
  final int valor;
  final IconData icono;
  final Color color;

  const _ResumenCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 30),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$valor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  titulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipDato extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destacado;
  final Color? colorEspecial;

  const _ChipDato({
    required this.titulo,
    required this.valor,
    this.destacado = false,
    this.colorEspecial,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        colorEspecial ?? (destacado ? Colors.orange : Colors.blueGrey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$titulo: $valor',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DatosEstado {
  final String texto;
  final Color color;
  final IconData icono;

  const _DatosEstado({
    required this.texto,
    required this.color,
    required this.icono,
  });
}
