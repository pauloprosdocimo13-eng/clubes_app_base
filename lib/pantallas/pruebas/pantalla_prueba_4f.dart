import 'package:flutter/material.dart';

import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../../tusede/servicios/servicio_prueba_datos_multiclub.dart';

class PantallaPrueba4F extends StatefulWidget {
  const PantallaPrueba4F({super.key});

  @override
  State<PantallaPrueba4F> createState() => _PantallaPrueba4FState();
}

class _PantallaPrueba4FState extends State<PantallaPrueba4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _procesando = false;
  bool _sesionCentralActiva = false;

  String _estado = 'Sin iniciar sesión en TuSede Central.';
  String _perfil = '';

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
      setState(() {
        _estado = 'Completá email y contraseña.';
      });
      return;
    }

    setState(() {
      _procesando = true;
      _estado = 'Autenticando contra TuSede Central...';
      _perfil = '';
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

      final perfilSnapshot = await ServicioFirebaseTuSede.firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!perfilSnapshot.exists || perfilSnapshot.data() == null) {
        await ServicioFirebaseTuSede.auth.signOut();

        throw Exception(
          'Authentication fue correcto, pero no existe usuarios/${user.uid}.',
        );
      }

      final data = perfilSnapshot.data()!;

      final activo = data['activo'] == true;
      final rol = data['rol']?.toString() ?? '';
      final clubPrincipal = data['clubPrincipal']?.toString() ?? '';

      final clubIdsRaw = data['clubIds'];

      final clubIds = clubIdsRaw is List
          ? clubIdsRaw.map((e) => e.toString()).toList()
          : <String>[];

      final tieneAcceso =
          clubIds.contains(ContextoClub.clubId) || rol == 'superadmin';

      if (!activo) {
        await ServicioFirebaseTuSede.auth.signOut();

        throw Exception(
          'El usuario central está desactivado.',
        );
      }

      if (!tieneAcceso) {
        await ServicioFirebaseTuSede.auth.signOut();

        throw Exception(
          'El usuario no tiene acceso al club ${ContextoClub.clubId}.',
        );
      }

      setState(() {
        _sesionCentralActiva = true;

        _estado =
            '✅ Sesión central autenticada correctamente.';

        _perfil =
            'UID: ${user.uid}\n'
            'Email: ${user.email}\n'
            'Rol: $rol\n'
            'Club principal: $clubPrincipal\n'
            'Clubes permitidos: ${clubIds.join(', ')}';
      });
    } catch (e) {
      setState(() {
        _sesionCentralActiva = false;

        _estado =
            '❌ Error de sesión central:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _crearSocioPrueba() async {
    setState(() {
      _procesando = true;
      _estado = 'Intentando crear socio ficticio...';
    });

    try {
      await ServicioPruebaDatosMulticlub.crearSocioPrueba();

      setState(() {
        _estado =
            '✅ 4F-1B OK\n'
            'Se creó clubes/generico/socios/prueba_001';
      });
    } catch (e) {
      setState(() {
        _estado =
            '❌ La escritura fue rechazada o falló:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _probarBloqueoGuemes() async {
    setState(() {
      _procesando = true;
      _estado =
          'Intentando acceder a datos protegidos de Güemes...';
    });

    try {
      await ServicioFirebaseTuSede.firestore
          .collection('clubes')
          .doc('guemes')
          .collection('socios')
          .doc('prueba_aislamiento_4f')
          .get();

      setState(() {
        _estado =
            '❌ ALERTA DE SEGURIDAD\n'
            'Horizonte pudo consultar una subcolección de Güemes.\n'
            'NO continuar con 4F.';
      });
    } catch (e) {
      final texto = e.toString().toLowerCase();

      if (texto.contains('permission-denied') ||
          texto.contains('missing or insufficient permissions')) {
        setState(() {
          _estado =
              '✅ 4F-1C OK\n'
              'Firestore bloqueó correctamente el acceso de '
              'Horizonte a Güemes.';
        });
      } else {
        setState(() {
          _estado =
              '⚠️ La prueba falló por otro motivo:\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await ServicioFirebaseTuSede.auth.signOut();

    if (!mounted) {
      return;
    }

    setState(() {
      _sesionCentralActiva = false;
      _perfil = '';
      _estado = 'Sesión central cerrada.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TuSede · Prueba 4F-1B / 4F-1C',
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Club cargado: ${ContextoClub.nombreClub}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'clubId: ${ContextoClub.clubId}',
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _emailCtrl,
                      enabled:
                          !_sesionCentralActiva &&
                          !_procesando,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email TuSede Central',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordCtrl,
                      enabled:
                          !_sesionCentralActiva &&
                          !_procesando,
                      obscureText: true,
                      decoration:
                          const InputDecoration(
                        labelText: 'Contraseña',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (!_sesionCentralActiva)
                      ElevatedButton(
                        onPressed:
                            _procesando
                                ? null
                                : _iniciarSesionCentral,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          '1. INICIAR SESIÓN CENTRAL',
                        ),
                      ),

                    if (_sesionCentralActiva) ...[
                      ElevatedButton(
                        onPressed:
                            _procesando
                                ? null
                                : _crearSocioPrueba,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          '2. CREAR SOCIO FICTICIO',
                        ),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed:
                            _procesando
                                ? null
                                : _probarBloqueoGuemes,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.red.shade700,
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          '3. PROBAR BLOQUEO A GÜEMES',
                        ),
                      ),

                      const SizedBox(height: 10),

                      OutlinedButton(
                        onPressed:
                            _procesando
                                ? null
                                : _cerrarSesion,
                        child: const Text(
                          'CERRAR SESIÓN CENTRAL',
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    if (_procesando)
                      const Center(
                        child:
                            CircularProgressIndicator(),
                      ),

                    if (!_procesando)
                      Container(
                        padding:
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: 0.04,
                          ),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(_estado),
                      ),

                    if (_perfil.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SelectableText(_perfil),
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