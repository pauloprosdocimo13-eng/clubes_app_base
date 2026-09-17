import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../servicios/servicio_notificaciones_topics.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../pantalla_admin_avisos.dart';
import '../pantalla_admin_noticias.dart';

class PantallaPruebaContenidoAdmin4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaContenidoAdmin4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaContenidoAdmin4F> createState() =>
      _PantallaPruebaContenidoAdmin4FState();
}

class _PantallaPruebaContenidoAdmin4FState
    extends State<PantallaPruebaContenidoAdmin4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _procesando = false;
  bool _sesionActiva = false;
  String _estado =
      'Iniciá sesión con el usuario central de Horizonte.';
  String _resultado = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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
      _resultado = '';
      _estado = 'Autenticando contra TuSede Central...';
    });

    try {
      final credential =
          await ServicioFirebaseTuSede.auth
              .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception(
          'Authentication no devolvió usuario.',
        );
      }

      final perfil = await ServicioFirebaseTuSede.firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!perfil.exists || perfil.data() == null) {
        await ServicioFirebaseTuSede.auth.signOut();
        throw Exception('No existe el perfil central.');
      }

      final data = perfil.data()!;
      final rol = (data['rol'] ?? '').toString();
      final clubIdsRaw = data['clubIds'];

      final clubIds = clubIdsRaw is List
          ? clubIdsRaw
              .map((e) => e.toString())
              .toList()
          : <String>[];

      if (data['activo'] != true) {
        throw Exception('Usuario desactivado.');
      }

      if (rol != 'superadmin' &&
          !clubIds.contains(ContextoClub.clubId)) {
        throw Exception(
          'El usuario no tiene acceso al club.',
        );
      }

      ServicioDatosClub.validarAccesoOperativo();

      if (!mounted) return;

      setState(() {
        _sesionActiva = true;
        _estado =
            '✅ Sesión central correcta. '
            'Noticias y Avisos listos para probar.';
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

  Future<void> _verificar() async {
    setState(() {
      _procesando = true;
      _resultado = '';
    });

    try {
      final noticias =
          await ServicioDatosClub.noticias.limit(20).get();
      final avisos =
          await ServicioDatosClub.avisos.limit(20).get();

      if (!mounted) return;

      setState(() {
        _resultado =
            'Origen: ${ServicioDatosClub.origenDescripcion}\n'
            'Noticias: ${noticias.docs.length}\n'
            'Avisos: ${avisos.docs.length}\n'
            'Topic esperado: '
            '${ServicioNotificacionesTopics.topicGeneral(widget.config)}';

        _estado =
            '✅ Contenido central leído correctamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = '❌ $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TuSede · Prueba 4F-2I Admin',
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Noticias + Avisos multiclub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Club: ${ContextoClub.nombreClub}',
                    ),
                    Text(
                      'clubId: ${ContextoClub.clubId}',
                    ),
                    Text(
                      'Datos: '
                      '${ServicioDatosClub.origenDescripcion}',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      enabled:
                          !_sesionActiva && !_procesando,
                      decoration: const InputDecoration(
                        labelText: 'Email TuSede Central',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      enabled:
                          !_sesionActiva && !_procesando,
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
                            _procesando ? null : _login,
                        child: const Text(
                          '1. INICIAR SESIÓN CENTRAL',
                        ),
                      ),
                    if (_sesionActiva) ...[
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PantallaAdminNoticias(
                              config: widget.config,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.newspaper),
                        label: const Text(
                          '2. GESTIONAR NOTICIAS',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PantallaAdminAvisos(
                              config: widget.config,
                              deporteId: 'general',
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.notifications_active,
                        ),
                        label: const Text(
                          '3. GESTIONAR AVISOS '
                          '(deporteId: general)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _verificar,
                        icon: const Icon(Icons.fact_check),
                        label: const Text(
                          '4. VERIFICAR DATOS CENTRALES',
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      Text(_estado),
                    if (_resultado.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SelectableText(_resultado),
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
