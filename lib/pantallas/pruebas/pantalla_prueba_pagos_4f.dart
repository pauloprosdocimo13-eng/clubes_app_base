import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../admin/pantalla_admin_pagos_config.dart';

class PantallaPruebaPagos4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaPagos4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaPagos4F> createState() =>
      _PantallaPruebaPagos4FState();
}

class _PantallaPruebaPagos4FState extends State<PantallaPruebaPagos4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _procesando = false;
  bool _sesionActiva = false;

  String _estado =
      'Iniciá sesión con el usuario central de Horizonte.';
  String _perfil = '';
  String _datosPagos = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
      _estado = 'Autenticando contra TuSede Central...';
      _perfil = '';
      _datosPagos = '';
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

      if (rol != 'superadmin' &&
          !clubIds.contains(ContextoClub.clubId)) {
        await ServicioFirebaseTuSede.auth.signOut();
        throw Exception(
          'El usuario no tiene acceso a ${ContextoClub.clubId}.',
        );
      }

      ServicioDatosClub.validarAccesoOperativo();

      if (!mounted) return;

      setState(() {
        _sesionActiva = true;
        _estado = '✅ Sesión central correcta.';
        _perfil =
            'Rol: $rol\n'
            'Club: ${ContextoClub.nombreClub}\n'
            'clubId: ${ContextoClub.clubId}\n'
            'Datos: ${ServicioDatosClub.origenDescripcion}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sesionActiva = false;
        _estado = '❌ $e';
      });
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _abrirConfigPagos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAdminPagosConfig(
          config: widget.config,
        ),
      ),
    );

    await _verificarConfiguracion();
  }

  Future<void> _verificarConfiguracion() async {
    if (!_sesionActiva) return;

    setState(() {
      _procesando = true;
      _estado = 'Leyendo configuración de pagos del club actual...';
    });

    try {
      final doc = await ServicioDatosClub.pagosConfiguracion.get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _datosPagos = 'No existe configuracion/pagos todavía.';
          _estado = '⚠️ No se encontró configuración de pagos.';
        });
        return;
      }

      final data = doc.data()!;

      setState(() {
        _datosPagos =
            'Ruta lógica: ${ServicioDatosClub.origenDescripcion}\n'
            'link_mp: ${data['link_mp'] ?? ''}\n'
            'alias_cbu: ${data['alias_cbu'] ?? ''}\n'
            'actualizado_por_email: '
            '${data['actualizado_por_email'] ?? ''}';
        _estado = '✅ 4F-2E: configuración leída correctamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = '❌ Error verificando pagos: $e');
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
      _sesionActiva = false;
      _perfil = '';
      _datosPagos = '';
      _estado = 'Sesión central cerrada.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuSede · Prueba 4F-2E'),
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
                    const Text(
                      'Configuración de pagos multiclub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Club: ${ContextoClub.nombreClub}'),
                    Text('clubId: ${ContextoClub.clubId}'),
                    Text(
                      'Origen previsto: '
                      '${ServicioDatosClub.origenDescripcion}',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      enabled: !_sesionActiva && !_procesando,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email TuSede Central',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      enabled: !_sesionActiva && !_procesando,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_sesionActiva)
                      ElevatedButton(
                        onPressed:
                            _procesando ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            const Text('1. INICIAR SESIÓN CENTRAL'),
                      ),
                    if (_sesionActiva) ...[
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _abrirConfigPagos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.account_balance),
                        label: const Text(
                          '2. ABRIR CONFIGURAR PAGOS REAL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _verificarConfiguracion,
                        icon: const Icon(Icons.fact_check),
                        label: const Text(
                          '3. VERIFICAR DATOS CENTRALES',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed:
                            _procesando ? null : _cerrarSesion,
                        child: const Text('CERRAR SESIÓN CENTRAL'),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_estado),
                      ),
                    if (_perfil.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SelectableText(_perfil),
                    ],
                    if (_datosPagos.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(_datosPagos),
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
