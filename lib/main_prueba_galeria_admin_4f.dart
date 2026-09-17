import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'pantallas/pantalla_admin_galeria.dart';
import 'tusede/servicios/contexto_club.dart';
import 'tusede/servicios/firestore_tusede.dart';
import 'tusede/servicios/servicio_datos_club.dart';
import 'tusede/servicios/servicio_firebase_tusede.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const sabor = 'generico';
  final config = RegistroFlavors.configDe(sabor);

  await Firebase.initializeApp(
    options: RegistroFlavors.firebaseOptionsDe(sabor),
  );

  ConfiguracionApp.actual = config;
  ContextoClub.inicializarDesdeConfiguracion(config);

  final inicializado = await ServicioFirebaseTuSede.inicializar();

  if (!inicializado) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No se pudo iniciar TuSede Central.'),
          ),
        ),
      ),
    );
    return;
  }

  final club = await FirestoreTuSede.cargarClubActual();

  if (club == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No existe clubes/generico.'),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _PruebaGaleriaAdmin(
        config: config,
      ),
    ),
  );
}

class _PruebaGaleriaAdmin extends StatefulWidget {
  final ConfiguracionApp config;

  const _PruebaGaleriaAdmin({
    required this.config,
  });

  @override
  State<_PruebaGaleriaAdmin> createState() =>
      _PruebaGaleriaAdminState();
}

class _PruebaGaleriaAdminState extends State<_PruebaGaleriaAdmin> {
  final _emailCtrl = TextEditingController(
    text: 'admin@horizonte.test',
  );
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
            'Galería lista para probar.';
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
      final fotos =
          await ServicioDatosClub.galeria.limit(50).get();

      if (!mounted) return;

      setState(() {
        _resultado =
            'Club: ${ContextoClub.nombreClub}\n'
            'clubId: ${ContextoClub.clubId}\n'
            'Origen: ${ServicioDatosClub.origenDescripcion}\n'
            'Fotos encontradas: ${fotos.docs.length}\n'
            'Ruta esperada: clubes/${ContextoClub.clubId}/galeria';

        _estado =
            '✅ Galería central leída correctamente.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = '❌ $e';
      });
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
          'TuSede · Prueba 4F-2J Admin',
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
                      'Galería multiclub',
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
                                PantallaAdminGaleria(
                              config: widget.config,
                              deporteId: 'general',
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.photo_library,
                        ),
                        label: const Text(
                          '2. GESTIONAR GALERÍA '
                          '(deporteId: general)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _verificar,
                        icon: const Icon(Icons.fact_check),
                        label: const Text(
                          '3. VERIFICAR DATOS CENTRALES',
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
