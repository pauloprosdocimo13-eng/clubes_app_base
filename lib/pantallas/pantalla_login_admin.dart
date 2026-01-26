import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_admin_dashboard.dart'; // Dashboard Móvil
import 'desktop/pantalla_admin_desktop.dart'; // Dashboard Escritorio

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

  @override
  void initState() {
    super.initState();
    _chequearSesionExistente();
  }

  void _chequearSesionExistente() async {
    await Future.delayed(Duration.zero);
    User? usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual != null) {
      _navegarAlPanel();
    } else {
      setState(() => _verificandoSesion = false);
    }
  }

  // --- LÓGICA DE DETECCIÓN DE PLATAFORMA ---
  void _navegarAlPanel() {
    // Obtenemos el ancho de la pantalla
    double ancho = MediaQuery.of(context).size.width;

    // Si es mayor a 900px, asumimos que es PC/Web Escritorio
    bool esEscritorio = ancho > 900; 

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => esEscritorio
            ? PantallaAdminDesktop(config: widget.config) // VAMOS AL DESKTOP
            : PantallaAdminDashboard( // VAMOS AL MÓVIL
                config: widget.config,
                deporteIdInicial: widget.deporteIdInicial,
              ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _cargando = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Si sale bien, navegamos
      _navegarAlPanel();
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error de autenticación";
      if (e.code == 'user-not-found') mensaje = "Usuario no encontrado";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red));
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoSesion) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: widget.config.colorPrimario)),
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
                  Icon(Icons.admin_panel_settings, size: 80, color: widget.config.colorPrimario),
                const SizedBox(height: 20),
                Text(
                  "Administración",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.config.colorPrimario),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Usuario (Email)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _cargando ? null : _login,
                    child: _cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("INGRESAR AL PANEL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}