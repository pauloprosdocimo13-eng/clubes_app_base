import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../socios/pantalla_acceso_socio.dart';

class PantallaPruebaCarnet4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaCarnet4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaCarnet4F> createState() =>
      _PantallaPruebaCarnet4FState();
}

class _PantallaPruebaCarnet4FState
    extends State<PantallaPruebaCarnet4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _procesando = false;
  bool _sesionActiva = false;

  String _estado =
      'Primero autenticamos el entorno de prueba de Horizonte.';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesionCentral() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _estado = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      _procesando = true;
      _estado = 'Autenticando contra TuSede Central...';
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
        _estado =
            '✅ Sesión de prueba lista. '
            'Ahora probá el Carnet Digital real de Horizonte.';
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

  Future<void> _abrirCarnet() async {
    if (!_sesionActiva) {
      setState(() => _estado = 'Primero iniciá sesión central.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAccesoSocio(
          config: widget.config,
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await ServicioFirebaseTuSede.auth.signOut();

    if (!mounted) return;

    setState(() {
      _sesionActiva = false;
      _estado = 'Sesión central de prueba cerrada.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuSede · Prueba 4F-2F'),
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
                      'Carnet Digital multiclub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Club: ${ContextoClub.nombreClub}'),
                    Text('clubId: ${ContextoClub.clubId}'),
                    Text(
                      'Origen: ${ServicioDatosClub.origenDescripcion}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Esta etapa valida el Carnet real con las reglas '
                      'actuales sin volver pública la colección socios.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
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
                            _procesando ? null : _iniciarSesionCentral,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            const Text('1. INICIAR SESIÓN DE PRUEBA'),
                      ),
                    if (_sesionActiva) ...[
                      ElevatedButton.icon(
                        onPressed: _procesando ? null : _abrirCarnet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.badge),
                        label: const Text(
                          '2. ABRIR CARNET DIGITAL REAL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed:
                            _procesando ? null : _cerrarSesion,
                        child: const Text('CERRAR SESIÓN DE PRUEBA'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      Text(_estado),
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
