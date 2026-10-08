import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_datos_club.dart';
import '../tusede/servicios/servicio_firebase_tusede.dart';
import '../tusede/servicios/servicio_sesion_tusede.dart';
import '../tusede/servicios/servicio_vinculo_tusede.dart';
import '../widgets/logo_club_tusede.dart';
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
  bool _verificandoSesion = true;

  bool get _usaCentral => ServicioDatosClub.usaTuSedeCentral;

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

  Future<void> _chequearSesionExistente() async {
    await Future.delayed(Duration.zero);

    if (_usaCentral) {
      await _chequearSesionCentralExistente();
      return;
    }

    await _chequearSesionLegacyExistente();
  }

  Future<void> _chequearSesionCentralExistente() async {
    try {
      if (!ServicioFirebaseTuSede.estaInicializado) {
        final iniciado = await ServicioFirebaseTuSede.inicializar();

        if (!iniciado) {
          if (mounted) {
            setState(() {
              _verificandoSesion = false;
            });
          }
          return;
        }
      }

      final usuario = await ServicioSesionTuSede.restaurarSesion();

      if (!mounted) {
        return;
      }

      if (usuario != null) {
        _navegarAlPanel();
        return;
      }
    } catch (_) {
      // Si no se pudo restaurar una sesión central,
      // mostramos el formulario de acceso.
    }

    if (mounted) {
      setState(() {
        _verificandoSesion = false;
      });
    }
  }

  Future<void> _chequearSesionLegacyExistente() async {
    final usuarioLegacy = FirebaseAuth.instance.currentUser;

    if (!mounted) {
      return;
    }

    if (usuarioLegacy != null) {
      unawaited(ServicioVinculoTuSede.intentarVincularSesionExistente());

      _navegarAlPanel();
      return;
    }

    setState(() {
      _verificandoSesion = false;
    });
  }

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
      if (_usaCentral) {
        await _loginCentral(email: email, password: password);
      } else {
        await _loginLegacy(email: email, password: password);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _loginCentral({
    required String email,
    required String password,
  }) async {
    try {
      await ServicioSesionTuSede.iniciarSesion(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      _navegarAlPanel();
    } on SesionTuSedeException catch (e) {
      if (mounted) {
        _mostrarMensaje(e.mensaje, Colors.red);
      }
    } catch (_) {
      if (mounted) {
        _mostrarMensaje('Error al ingresar a TuSede Central.', Colors.red);
      }
    }
  }

  Future<void> _loginLegacy({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      unawaited(
        ServicioVinculoTuSede.intentarVincular(
          email: email,
          password: password,
        ),
      );

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
    } catch (_) {
      if (mounted) {
        _mostrarMensaje('Error al ingresar.', Colors.red);
      }
    }
  }

  void _navegarAlPanel() {
    final ancho = MediaQuery.of(context).size.width;
    final esEscritorio = ancho > 900;

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

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final Color colorPrimario = ContextoClub.colorPrimario;

    if (_verificandoSesion) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: colorPrimario)),
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
                LogoClubTuSede(
                  config: widget.config,
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  'Administración',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorPrimario,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _usaCentral
                      ? 'Acceso TuSede Central'
                      : 'Acceso administrativo',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimario,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
