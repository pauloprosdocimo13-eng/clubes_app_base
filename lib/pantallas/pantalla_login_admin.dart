import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../widgets/logo_club_tusede.dart';
import '../tusede/servicios/servicio_vinculo_tusede.dart';
import 'desktop/pantalla_admin_desktop.dart';
import 'pantalla_admin_dashboard.dart';

class PantallaLoginAdmin
    extends StatefulWidget {
  final ConfiguracionApp config;
  final String? deporteIdInicial;

  const PantallaLoginAdmin({
    super.key,
    required this.config,
    this.deporteIdInicial,
  });

  @override
  State<PantallaLoginAdmin> createState() =>
      _PantallaLoginAdminState();
}

class _PantallaLoginAdminState
    extends State<PantallaLoginAdmin> {
  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  bool _cargando = false;

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

  Future<void>
      _chequearSesionExistente() async {
    await Future.delayed(
      Duration.zero,
    );

    final usuarioLegacy =
        FirebaseAuth.instance.currentUser;

    if (!mounted) {
      return;
    }

    // ==========================================================
    // YA ESTABA LOGUEADO EN GÜEMES
    // ==========================================================
    //
    // Entramos inmediatamente.
    //
    // TuSede trabaja silenciosamente en segundo plano
    // y jamás condiciona el acceso al panel.

    if (usuarioLegacy != null) {
      unawaited(
        ServicioVinculoTuSede
            .intentarVincularSesionExistente(),
      );

      _navegarAlPanel();

      return;
    }

    if (mounted) {
      setState(() {
        _verificandoSesion = false;
      });
    }
  }

  // ============================================================
  // LOGIN LEGACY
  // ============================================================

  Future<void> _login() async {
    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text;

    if (email.isEmpty ||
        password.isEmpty) {
      _mostrarMensaje(
        'Completá el email y la contraseña.',
        Colors.orange,
      );

      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      // ========================================================
      // FIREBASE DEL CLUB SIGUE SIENDO LA AUTORIDAD
      // ========================================================

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // TUSEDE EN SEGUNDO PLANO
      // ========================================================

      unawaited(
        ServicioVinculoTuSede
            .intentarVincular(
          email: email,
          password: password,
        ),
      );

      // ========================================================
      // PANEL INMEDIATO
      // ========================================================

      _navegarAlPanel();
    } on FirebaseAuthException catch (e) {
      String mensaje =
          'Error de autenticación';

      if (e.code == 'user-not-found') {
        mensaje =
            'Usuario no encontrado';
      }

      if (e.code == 'wrong-password') {
        mensaje =
            'Contraseña incorrecta';
      }

      if (e.code ==
          'invalid-credential') {
        mensaje =
            'Usuario o contraseña incorrectos';
      }

      if (mounted) {
        _mostrarMensaje(
          mensaje,
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensaje(
          'Error al ingresar.',
          Colors.red,
        );
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
  // NAVEGACIÓN
  // ============================================================

  void _navegarAlPanel() {
    final ancho =
        MediaQuery.of(context)
            .size
            .width;

    final esEscritorio =
        ancho > 900;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (esEscritorio) {
            return PantallaAdminDesktop(
              config: widget.config,
            );
          }

          return PantallaAdminDashboard(
            config: widget.config,
            deporteIdInicial:
                widget.deporteIdInicial,
          );
        },
      ),
    );
  }

  // ============================================================
  // MENSAJES LEGACY
  // ============================================================

  void _mostrarMensaje(
    String mensaje,
    Color color,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(mensaje),
        backgroundColor:
            color,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color colorPrimario = ContextoClub.colorPrimario;

    if (_verificandoSesion) {
      return Scaffold(
        backgroundColor:
            Colors.white,
        body: Center(
          child:
              CircularProgressIndicator(
            color: colorPrimario,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.white,
      body: Center(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 400,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                LogoClubTuSede(
                  config: widget.config,
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Administración',
                  style:
                      TextStyle(
                    fontSize:
                        24,
                    fontWeight:
                        FontWeight.bold,
                    color: colorPrimario,
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                TextField(
                  controller:
                      _emailController,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Usuario (Email)',
                    border:
                        OutlineInputBorder(),
                    prefixIcon:
                        Icon(
                      Icons.person,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextField(
                  controller:
                      _passwordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Contraseña',
                    border:
                        OutlineInputBorder(),
                    prefixIcon:
                        Icon(
                      Icons.lock,
                    ),
                  ),
                  onSubmitted:
                      (_) =>
                          _login(),
                ),

                const SizedBox(
                  height: 30,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 50,
                  child:
                      ElevatedButton(
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor: colorPrimario,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                    ),
                    onPressed:
                        _cargando
                            ? null
                            : _login,
                    child: _cargando
                        ? const SizedBox(
                            width:
                                22,
                            height:
                                22,
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Text(
                            'INGRESAR AL PANEL',
                            style:
                                TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight.bold,
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