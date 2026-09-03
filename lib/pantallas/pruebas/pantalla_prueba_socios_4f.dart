import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../admin/pantalla_admin_socios.dart';

class PantallaPruebaSocios4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaSocios4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaSocios4F> createState() =>
      _PantallaPruebaSocios4FState();
}

class _PantallaPruebaSocios4FState extends State<PantallaPruebaSocios4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _procesando = false;
  String _estado = 'Iniciá sesión con el usuario central de Horizonte.';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _estado = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      _procesando = true;
      _estado = 'Autenticando...';
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
        throw Exception('El usuario no tiene acceso a ${ContextoClub.clubId}.');
      }

      ServicioDatosClub.validarAccesoOperativo();

      if (!mounted) return;

      setState(() {
        _estado =
            '✅ Sesión correcta. Datos: ${ServicioDatosClub.origenDescripcion}';
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaAdminSocios(config: widget.config),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _estado = '❌ $e');
      }
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
        title: const Text('TuSede · Prueba 4F-2'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                    const SizedBox(height: 6),
                    Text('clubId: ${ContextoClub.clubId}'),
                    const SizedBox(height: 6),
                    Text(
                      'Origen previsto: ${ServicioDatosClub.origenDescripcion}',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email TuSede Central',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _procesando ? null : _entrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ENTRAR AL PADRÓN REAL'),
                    ),
                    const SizedBox(height: 20),
                    if (_procesando)
                      const Center(child: CircularProgressIndicator())
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
