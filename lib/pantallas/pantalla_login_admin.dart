import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_usuario_tusede.dart';
import '../tusede/servicios/servicio_sesion_tusede.dart';
import '../tusede/servicios/servicio_vinculo_tusede.dart';
import 'desktop/pantalla_admin_desktop.dart';
import 'pantalla_admin_dashboard.dart';

class PantallaLoginAdmin extends StatefulWidget {
  final ConfiguracionApp config;
  final String? deporteIdInicial;

  const PantallaLoginAdmin({
    super.key,
    required this.config,
    this.deporteIdInicial,
  });

  @override
  State<PantallaLoginAdmin> createState() => _PantallaLoginAdminState();
}

class _PantallaLoginAdminState extends State<PantallaLoginAdmin> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;
  bool _validandoTuSede = false;
  bool _verificandoSesion = true;

  @override
  void initState() {
    super.initState();

    _chequearSesionExistente();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // SESIÓN EXISTENTE
  // ============================================================

  Future<void> _chequearSesionExistente() async {
    await Future.delayed(Duration.zero);

    // Intentamos restaurar una sesión TuSede si existe.
    //
    // Pero esto NO decide si el usuario puede entrar al panel.
    // La autoridad continúa siendo Firebase Legacy de Güemes.
    try {
      await ServicioSesionTuSede.restaurarSesion();
    } catch (e) {
      debugPrint('No se pudo restaurar TuSede: $e');
    }

    final User? usuarioActual = FirebaseAuth.instance.currentUser;

    if (!mounted) {
      return;
    }

    // ==========================================================
    // IMPORTANTE
    // ==========================================================
    //
    // Solo entramos automáticamente si existe una sesión
    // válida en el Firebase Legacy del club.
    //
    // Una sesión TuSede por sí sola NO permite todavía
    // ingresar al panel administrativo.

    if (usuarioActual != null) {
      _navegarAlPanel();
    } else {
      setState(() {
        _verificandoSesion = false;
      });
    }
  }

  // ============================================================
  // NAVEGACIÓN PANEL
  // ============================================================

  void _navegarAlPanel() {
    final double ancho = MediaQuery.of(context).size.width;

    final bool esEscritorio = ancho > 900;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (esEscritorio) {
            return PantallaAdminDesktop(config: widget.config);
          }

          return PantallaAdminDashboard(
            config: widget.config,
            deporteIdInicial: widget.deporteIdInicial,
          );
        },
      ),
    );
  }

  // ============================================================
  // LOGIN LEGACY - SIGUE SIENDO LA AUTORIDAD
  // ============================================================

  Future<void> _login() async {
    final email = _emailController.text.trim();

    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Completá el email y la contraseña.', Colors.orange);

      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      // ========================================================
      // PASO 1
      // ========================================================
      //
      // Autenticación NORMAL del club.
      //
      // Este sigue siendo exactamente el requisito que existía
      // antes de comenzar la migración a TuSede.

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // PASO 2 - TUSEDE SHADOW
      // ========================================================
      //
      // Firebase Güemes YA aceptó al administrador.
      //
      // Por eso entramos al panel normalmente.
      //
      // En paralelo TuSede intenta reconocerlo.
      //
      // NO esperamos esta operación.
      // NO puede bloquear el panel.
      // NO modifica sus permisos actuales.

      unawaited(
        ServicioVinculoTuSede.intentarVincular(
          email: email,
          password: password,
        ),
      );

      // ========================================================
      // PASO 3
      // ========================================================
      //
      // El administrador entra exactamente como hasta hoy.

      _navegarAlPanel();
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error de autenticación';

      if (e.code == 'user-not-found') {
        mensaje = 'Usuario no encontrado';
      }

      if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta';
      }

      if (e.code == 'invalid-credential') {
        mensaje = 'Usuario o contraseña incorrectos';
      }

      if (mounted) {
        _mostrarMensaje(mensaje, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error al ingresar: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // ============================================================
  // BOTÓN TEMPORAL PARA PRUEBAS TUSEDE
  // ============================================================
  //
  // Por ahora lo conservamos en nuestra rama de desarrollo.
  //
  // NO forma parte todavía del login definitivo.

  Future<void> _validarCuentaTuSede() async {
    final email = _emailController.text.trim();

    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje(
        'Ingresá el email y contraseña '
        'de tu cuenta TuSede.',
        Colors.orange,
      );

      return;
    }

    setState(() {
      _validandoTuSede = true;
    });

    try {
      final usuario = await ServicioSesionTuSede.iniciarSesion(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      _mostrarMensaje(
        'TuSede conectado correctamente. '
        '${usuario.nombre} - ${usuario.rol}',
        Colors.green,
      );

      debugPrint(
        'Contexto TuSede activo: '
        '${ContextoUsuarioTuSede.usuarioActual}',
      );
    } on SesionTuSedeException catch (e) {
      if (mounted) {
        _mostrarMensaje(e.mensaje, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error validando TuSede: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _validandoTuSede = false;
        });
      }
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_verificandoSesion) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: widget.config.colorPrimario),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.config.rutaLogo.isNotEmpty)
                  Image.asset(widget.config.rutaLogo, height: 100)
                else
                  Icon(
                    Icons.admin_panel_settings,
                    size: 80,
                    color: widget.config.colorPrimario,
                  ),

                const SizedBox(height: 20),

                Text(
                  'Administración',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.config.colorPrimario,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Usuario (Email)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 30),

                // =================================================
                // LOGIN ACTUAL DEL CLUB
                // =================================================
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cargando ? null : _login,
                    child: _cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'INGRESAR AL PANEL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                // =================================================
                // BOTÓN TEMPORAL TUSEDE
                // =================================================
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _validandoTuSede ? null : _validarCuentaTuSede,
                    icon: _validandoTuSede
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_done),
                    label: Text(
                      _validandoTuSede
                          ? 'VALIDANDO...'
                          : 'VALIDAR CUENTA TUSEDE',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Botón temporal de desarrollo. '
                  'El acceso administrativo actual '
                  'del club continúa funcionando '
                  'de manera independiente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
