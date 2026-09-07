import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_firebase_tusede.dart';
import '../admin/pantalla_admin_asistencia.dart';
import '../admin/pantalla_admin_scanner.dart';

class PantallaPruebaAsistencias4F extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaPruebaAsistencias4F({
    super.key,
    required this.config,
  });

  @override
  State<PantallaPruebaAsistencias4F> createState() =>
      _PantallaPruebaAsistencias4FState();
}

class _PantallaPruebaAsistencias4FState
    extends State<PantallaPruebaAsistencias4F> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _socioIdCtrl = TextEditingController();

  bool _procesando = false;
  bool _sesionActiva = false;

  String _estado =
      'Iniciá sesión con el usuario central de Horizonte.';
  String _resultado = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _socioIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _estado = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      _procesando = true;
      _resultado = '';
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
      final rol = (data['rol'] ?? '').toString();
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
            '✅ Sesión central correcta. '
            'Asistencias y socios están listos para probar.';
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

  Future<void> _abrirAsistencia() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAdminAsistencia(
          config: widget.config,
        ),
      ),
    );
  }

  Future<void> _verificarAsistencias() async {
    if (!_sesionActiva) return;

    setState(() {
      _procesando = true;
      _resultado = '';
      _estado = 'Leyendo asistencias del club actual...';
    });

    try {
      final query = await ServicioDatosClub.asistencias
          .orderBy('fecha', descending: true)
          .limit(5)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        setState(() {
          _resultado =
              'No hay documentos en asistencias todavía.';
          _estado =
              '⚠️ Guardá una asistencia ficticia y volvé a verificar.';
        });
        return;
      }

      final lineas = <String>[];

      for (final doc in query.docs) {
        final data = doc.data();
        final presentesRaw = data['presentes'];
        final presentes = presentesRaw is List
            ? presentesRaw.length
            : 0;

        lineas.add(
          '${doc.id}\n'
          'Actividad: ${data['actividad'] ?? ''}\n'
          'Presentes: $presentes\n'
          'Grupo: ${data['grupo_etiqueta'] ?? ''}',
        );
      }

      setState(() {
        _resultado = lineas.join('\n\n');
        _estado =
            '✅ Asistencias leídas desde '
            '${ServicioDatosClub.origenDescripcion}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = '❌ Error verificando asistencias: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _validarSocioComoQr() async {
    final id = _socioIdCtrl.text.trim();

    if (id.isEmpty) {
      setState(() => _estado = 'Ingresá un ID de socio.');
      return;
    }

    setState(() {
      _procesando = true;
      _resultado = '';
      _estado = 'Validando ID como si viniera del QR...';
    });

    try {
      final doc = await ServicioDatosClub.socios.doc(id).get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _resultado = 'QR / ID no encontrado.';
          _estado = '✅ La validación rechazó un ID inexistente.';
        });
        return;
      }

      final data = doc.data()!;

      if (data['eliminado'] == true) {
        setState(() {
          _resultado = 'El socio está dado de baja.';
          _estado = '✅ La validación rechazó un socio eliminado.';
        });
        return;
      }

      final nombre =
          '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
      final estadoLegacy = (data['estado'] ?? '').toString();
      final bool? alDiaCentral =
          data['al_dia'] is bool ? data['al_dia'] as bool : null;

      final permitido = ServicioDatosClub.usaTuSedeCentral
          ? (alDiaCentral ??
              estadoLegacy.toLowerCase().contains('al d'))
          : (estadoLegacy.toLowerCase().contains('al d') ||
              estadoLegacy.toLowerCase() == 'al día');

      setState(() {
        _resultado =
            'Socio: $nombre\n'
            'ID: ${doc.id}\n'
            'Acceso: ${permitido ? 'PERMITIDO' : 'DENEGADO'}\n'
            'Origen: ${ServicioDatosClub.origenDescripcion}';
        _estado = '✅ Validación QR multiclub correcta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = '❌ Error validando socio: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _abrirScannerReal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAdminScanner(
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
      _resultado = '';
      _estado = 'Sesión central cerrada.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuSede · Prueba 4F-2G'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Asistencias + Scanner multiclub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Club: ${ContextoClub.nombreClub}'),
                    Text('clubId: ${ContextoClub.clubId}'),
                    Text(
                      'Datos: ${ServicioDatosClub.origenDescripcion}',
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
                    const SizedBox(height: 12),
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
                            _procesando ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            const Text('1. INICIAR SESIÓN CENTRAL'),
                      ),
                    if (_sesionActiva) ...[
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _abrirAsistencia,
                        icon: const Icon(Icons.fact_check),
                        label: const Text(
                          '2. ABRIR CONTROL DE ASISTENCIA REAL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _verificarAsistencias,
                        icon: const Icon(Icons.cloud_done),
                        label: const Text(
                          '3. VERIFICAR ASISTENCIAS CENTRALES',
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Prueba del QR sin usar cámara',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pegá el ID de un socio ficticio de Horizonte. '
                        'Es exactamente el valor que contiene el QR del carnet.',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _socioIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ID del socio / contenido QR',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed:
                            _procesando ? null : _validarSocioComoQr,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text(
                          '4. VALIDAR ID COMO QR',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed:
                            _procesando ? null : _abrirScannerReal,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text(
                          '5. ABRIR SCANNER REAL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed:
                            _procesando ? null : _cerrarSesion,
                        child: const Text('CERRAR SESIÓN CENTRAL'),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_estado),
                      ),
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
