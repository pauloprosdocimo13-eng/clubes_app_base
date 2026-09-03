import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../admin/pantalla_admin_socios.dart';

class PantallaPruebaCobros4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaCobros4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaCobros4F> createState() =>
      _PantallaPruebaCobros4FState();
}

class _PantallaPruebaCobros4FState extends State<PantallaPruebaCobros4F> {
  final _emailCtrl = TextEditingController(text: 'admin@horizonte.test');
  final _passwordCtrl = TextEditingController();
  final _cuotaSocialCtrl = TextEditingController(text: '5000');
  final _babyCtrl = TextEditingController(text: '8000');

  bool _procesando = false;
  bool _autenticado = false;
  String _estado = 'Iniciá sesión con el usuario central de Horizonte.';
  String _detalle = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _cuotaSocialCtrl.dispose();
    _babyCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _estado = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      _procesando = true;
      _estado = 'Autenticando en TuSede Central...';
      _detalle = '';
    });

    try {
      final credential =
          await ServicioFirebaseTuSede.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Authentication no devolvió usuario.');
      }

      final perfil = await ServicioFirebaseTuSede.firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!perfil.exists || perfil.data() == null) {
        await ServicioFirebaseTuSede.auth.signOut();
        throw Exception('No existe el perfil central del usuario.');
      }

      final data = perfil.data()!;
      final activo = data['activo'] == true;
      final rol = data['rol']?.toString() ?? '';
      final clubIdsRaw = data['clubIds'];
      final clubIds = clubIdsRaw is List
          ? clubIdsRaw.map((e) => e.toString()).toList()
          : <String>[];

      if (!activo) {
        await ServicioFirebaseTuSede.auth.signOut();
        throw Exception('El usuario está desactivado.');
      }

      if (rol != 'superadmin' && !clubIds.contains(ContextoClub.clubId)) {
        await ServicioFirebaseTuSede.auth.signOut();
        throw Exception(
          'El usuario no tiene acceso a ${ContextoClub.clubId}.',
        );
      }

      ServicioDatosClub.validarAccesoOperativo();

      if (!mounted) return;

      setState(() {
        _autenticado = true;
        _estado = '✅ Sesión central correcta.';
        _detalle =
            'Origen operativo: ${ServicioDatosClub.origenDescripcion}\n'
            'Ruta precios: clubes/${ContextoClub.clubId}/configuracion/precios\n'
            'Ruta cobros: clubes/${ContextoClub.clubId}/movimientos';
      });

      await _cargarPrecios();
    } catch (e) {
      if (mounted) {
        setState(() {
          _autenticado = false;
          _estado = '❌ $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _cargarPrecios() async {
    if (!_autenticado) return;

    try {
      final doc = await ServicioDatosClub.precios.get();
      final data = doc.data() ?? <String, dynamic>{};
      final raw = data['precios_cuotas'];
      final precios = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      if (precios['Cuota Social'] != null) {
        _cuotaSocialCtrl.text = precios['Cuota Social'].toString();
      }

      if (precios['Baby'] != null) {
        _babyCtrl.text = precios['Baby'].toString();
      }

      if (mounted) {
        setState(() {
          _detalle =
              'Origen operativo: ${ServicioDatosClub.origenDescripcion}\n'
              'Cuota Social: ${precios['Cuota Social'] ?? 'sin configurar'}\n'
              'Baby: ${precios['Baby'] ?? 'sin configurar'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = '⚠️ Sesión correcta, pero no se pudieron leer precios.';
          _detalle = e.toString();
        });
      }
    }
  }

  Future<void> _guardarPrecios() async {
    final cuotaSocial = double.tryParse(
      _cuotaSocialCtrl.text.trim().replaceAll(',', '.'),
    );
    final baby = double.tryParse(
      _babyCtrl.text.trim().replaceAll(',', '.'),
    );

    if (cuotaSocial == null || cuotaSocial < 0 || baby == null || baby < 0) {
      setState(() {
        _estado = 'Ingresá importes válidos para los precios.';
      });
      return;
    }

    setState(() {
      _procesando = true;
      _estado = 'Guardando precios de Horizonte...';
    });

    try {
      final user = ServicioDatosClub.usuarioAuthActual;

      await ServicioDatosClub.precios.set({
        'precios_cuotas': {
          'Cuota Social': cuotaSocial,
          'Baby': baby,
        },
        'fecha_actualizacion': FieldValue.serverTimestamp(),
        'actualizado_por_email': user?.email ?? 'Desconocido',
        'actualizado_por_uid': user?.uid ?? '',
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _estado = '✅ Precios guardados en TuSede Central.';
          _detalle =
              'clubes/${ContextoClub.clubId}/configuracion/precios\n'
              'Cuota Social: \$${cuotaSocial.toStringAsFixed(0)}\n'
              'Baby: \$${baby.toStringAsFixed(0)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = '❌ No se pudieron guardar los precios.';
          _detalle = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _abrirPadron() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAdminSocios(config: widget.config),
      ),
    );
  }

  Future<void> _verificarCobros() async {
    setState(() {
      _procesando = true;
      _estado = 'Consultando movimientos centrales...';
    });

    try {
      final query = await ServicioDatosClub.movimientos
          .orderBy('fecha', descending: true)
          .limit(5)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _estado = '⚠️ Todavía no hay cobros en Horizonte.';
          _detalle =
              'Después de cobrar una cuota desde el padrón, volvé y tocá este botón.';
        });
        return;
      }

      final lineas = <String>[];
      for (final doc in query.docs) {
        final data = doc.data();
        final monto = data['monto'];
        final socio = (data['socio_nombre'] ?? data['socio_id'] ?? '').toString();
        final categoria = (data['categoria'] ?? '').toString();
        final concepto = (data['concepto'] ?? '').toString();
        lineas.add(
          '${doc.id}\n'
          '  Socio: $socio\n'
          '  Monto: \$$monto\n'
          '  Categoría: $categoria\n'
          '  $concepto',
        );
      }

      if (mounted) {
        setState(() {
          _estado = '✅ Cobros encontrados en TuSede Central.';
          _detalle = lineas.join('\n\n');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = '❌ No se pudieron consultar los cobros.';
          _detalle = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await ServicioFirebaseTuSede.auth.signOut();
    if (!mounted) return;

    setState(() {
      _autenticado = false;
      _estado = 'Sesión central cerrada.';
      _detalle = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuSede · Prueba 4F-2C'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Club: ${ContextoClub.nombreClub}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'clubId: ${ContextoClub.clubId}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      enabled: !_autenticado && !_procesando,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email TuSede Central',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      enabled: !_autenticado && !_procesando,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_autenticado)
                      ElevatedButton(
                        onPressed: _procesando ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('1. INICIAR SESIÓN CENTRAL'),
                      ),
                    if (_autenticado) ...[
                      const Divider(height: 32),
                      const Text(
                        'Precios de prueba de Horizonte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cuotaSocialCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cuota Social',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _babyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Baby',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _procesando ? null : _guardarPrecios,
                        icon: const Icon(Icons.price_change),
                        label: const Text('2. GUARDAR PRECIOS CENTRALES'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _procesando ? null : _abrirPadron,
                        icon: const Icon(Icons.groups),
                        label: const Text('3. ABRIR PADRÓN Y COBRAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _procesando ? null : _verificarCobros,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('4. VERIFICAR COBROS CENTRALES'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _procesando ? null : _cerrarSesion,
                        child: const Text('CERRAR SESIÓN CENTRAL'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_procesando)
                      const Center(child: CircularProgressIndicator())
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_estado),
                      ),
                    if (_detalle.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(_detalle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
