import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'configuracion/configuracion_app.dart';
import 'configuracion/registro_flavors.dart';
import 'pantallas/admin/pantalla_admin_tienda.dart';
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

  final centralOk =
      await ServicioFirebaseTuSede.inicializar();

  if (centralOk) {
    await FirestoreTuSede.cargarClubActual();
  }

  runApp(
    _PruebaTiendaAdminApp(
      config: config,
      centralOk: centralOk,
    ),
  );
}

class _PruebaTiendaAdminApp
    extends StatelessWidget {
  final ConfiguracionApp config;
  final bool centralOk;

  const _PruebaTiendaAdminApp({
    required this.config,
    required this.centralOk,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '4F-2K Tienda Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.colorPrimario,
        ),
      ),
      home: _PruebaTiendaAdmin(
        config: config,
        centralOk: centralOk,
      ),
    );
  }
}

class _PruebaTiendaAdmin
    extends StatefulWidget {
  final ConfiguracionApp config;
  final bool centralOk;

  const _PruebaTiendaAdmin({
    required this.config,
    required this.centralOk,
  });

  @override
  State<_PruebaTiendaAdmin> createState() =>
      _PruebaTiendaAdminState();
}

class _PruebaTiendaAdminState
    extends State<_PruebaTiendaAdmin> {
  final _emailCtrl = TextEditingController(
    text: 'admin@horizonte.test',
  );
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  String _resultado = '';

  bool get _logueado =>
      ServicioFirebaseTuSede.estaInicializado &&
      ServicioFirebaseTuSede.auth.currentUser !=
          null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!widget.centralOk) {
      setState(() {
        _resultado =
            'TuSede Central no pudo inicializarse.';
      });
      return;
    }

    if (_passwordCtrl.text.isEmpty) {
      setState(() {
        _resultado =
            'Ingresá la contraseña del usuario de prueba.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _resultado = '';
    });

    try {
      await ServicioFirebaseTuSede.auth
          .signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (mounted) {
        setState(() {
          _resultado =
              'Sesión central iniciada correctamente.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado = 'Error de login: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _verificar() async {
    if (!_logueado) {
      setState(() {
        _resultado =
            'Primero iniciá sesión en TuSede Central.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _resultado = '';
    });

    try {
      final snapshot =
          await ServicioDatosClub.productos.get();

      final activos = snapshot.docs.where((doc) {
        return doc.data()['activo'] == true;
      }).length;

      if (mounted) {
        setState(() {
          _resultado =
              'Club: ${ContextoClub.nombreClub}\n'
              'clubId: ${ContextoClub.clubId}\n'
              'Datos: ${ServicioDatosClub.origenDescripcion}\n'
              'Productos encontrados: ${snapshot.docs.length}\n'
              'Productos activos: $activos\n'
              'Ruta esperada: '
              'clubes/${ContextoClub.clubId}/productos';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado =
              'Error verificando productos: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _gestionarTienda() {
    if (!_logueado) {
      setState(() {
        _resultado =
            'Primero iniciá sesión en TuSede Central.';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAdminTienda(
          config: widget.config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.config.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prueba 4F-2K - Tienda Admin',
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        ContextoClub.nombreClub,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'clubId: '
                        '${ContextoClub.clubId}',
                      ),
                      Text(
                        'Datos: '
                        '${ServicioDatosClub.origenDescripcion}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.centralOk
                            ? 'TuSede Central inicializado'
                            : 'TuSede Central NO inicializado',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_logueado) ...[
                TextField(
                  controller: _emailCtrl,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email central',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Contraseña',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      _cargando ? null : _login,
                  icon:
                      const Icon(Icons.login),
                  label: const Text(
                    '1. INICIAR SESIÓN CENTRAL',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed:
                    _cargando
                        ? null
                        : _gestionarTienda,
                icon: const Icon(Icons.store),
                label: const Text(
                  '2. GESTIONAR TIENDA',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    _cargando
                        ? null
                        : _verificar,
                icon:
                    const Icon(Icons.fact_check),
                label: const Text(
                  '3. VERIFICAR DATOS CENTRALES',
                ),
              ),
              const SizedBox(height: 20),
              if (_cargando)
                const Center(
                  child:
                      CircularProgressIndicator(),
                ),
              if (_resultado.isNotEmpty)
                Card(
                  color: Colors.blueGrey[50],
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: SelectableText(
                      _resultado,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
