import 'package:flutter/material.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../configuracion/configuracion_app.dart';
import '../../configuracion/admin_permisos.dart';

class PantallaAdminMatrizPermisos extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminMatrizPermisos({super.key, required this.config});

  @override
  State<PantallaAdminMatrizPermisos> createState() =>
      _PantallaAdminMatrizPermisosState();
}

class _PantallaAdminMatrizPermisosState
    extends State<PantallaAdminMatrizPermisos> {
  final List<String> _roles = [
    'tesoreria',
    'administracion',
    'deportes',
    'institucional',
    if (ServicioDatosClub.usaTuSedeCentral) 'ingreso',
  ];

  // Lista exacta de todos los botones que existen en tu menú
  final List<String> _todosLosModulos = [
    'Tomar Asistencia',
    'Caja y Finanzas',
    'Escanear Ingreso',
    'Padrón Socios',
    'Config. Precios',
    'Configurar Pagos',
    'Agenda / Reservas',
    'Configurar Espacios',
    'Gestionar Partidos',
    'Rivales y Ubicaciones',
    'Gestionar Plantel',
    'Avisos Urgentes',
    'Publicar Noticia',
    'Configurar Pop-up',
    'Subir Fotos',
    'Publicidad',
    'Configurar Tiras',
    'Configuración Club',
    if (!ServicioDatosClub.usaTuSedeCentral) 'Pizarra Táctica',
    'Consola en VIVO',
    if (!ServicioDatosClub.usaTuSedeCentral) 'Configurar Streaming',
    if (!ServicioDatosClub.usaTuSedeCentral) 'Gestión Prode',
    if (!ServicioDatosClub.usaTuSedeCentral) 'Votación Figura',
    'Tienda Oficial',
    'Gestionar Rifas',
  ];

  Map<String, List<String>> _accesosActuales = {};
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarMatriz();
  }

  Future<void> _cargarMatriz() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      if (ServicioDatosClub.usaTuSedeCentral &&
          await AdminPermisos.obtenerRol() != AdminPermisos.admin) {
        throw Exception(
          'Solo el administrador del club puede editar la matriz.',
        );
      }
      _accesosActuales = {for (final rol in _roles) rol: <String>[]};
      final doc = await ServicioDatosClub.configuracionDoc(
        'permisos_roles',
      ).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data()!;
        data.forEach((rol, modulos) {
          if (_roles.contains(rol) && modulos is List) {
            _accesosActuales[rol] = modulos
                .whereType<String>()
                .where(_todosLosModulos.contains)
                .toList();
          }
        });
      } else {
        // Si nunca se configuró, iniciamos los arrays vacíos o con lo básico
        for (var rol in _roles) {
          _accesosActuales[rol] =
              (ServicioDatosClub.usaTuSedeCentral
                      ? (AdminPermisos.predeterminadosCentral[rol] ?? [])
                      : <String>[])
                  .where(_todosLosModulos.contains)
                  .toList();
        }
      }
    } catch (e) {
      _errorCarga = 'No se pudo cargar la matriz: $e';
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarMatriz() async {
    if (_cargando || _errorCarga != null) return;
    setState(() => _cargando = true);
    try {
      await ServicioDatosClub.configuracionDoc(
        'permisos_roles',
      ).set(_accesosActuales);
      await AdminPermisos.inicializarMatriz(); // Recargamos en memoria inmediatamente

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Permisos guardados correctamente. Los permisos se aplican en el servidor; volvé a entrar al panel para actualizar los botones.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Matriz de Permisos"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargando || _errorCarga != null ? null : _guardarMatriz,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text("GUARDAR CAMBIOS"),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorCarga!),
                  TextButton(
                    onPressed: _cargarMatriz,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 10),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                String rol = _roles[index];
                List<String> modulosPermitidos = _accesosActuales[rol] ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  child: ExpansionTile(
                    collapsedBackgroundColor: Colors.white,
                    backgroundColor: Colors.blue[50],
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.blue,
                    ),
                    title: Text(
                      rol.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${modulosPermitidos.length} módulos habilitados",
                    ),
                    children: _todosLosModulos.map((modulo) {
                      bool tieneAcceso = modulosPermitidos.contains(modulo);
                      return CheckboxListTile(
                        title: Text(
                          modulo,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: tieneAcceso,
                        activeColor: Colors.blue,
                        dense: true,
                        onChanged: (bool? valor) {
                          setState(() {
                            if (valor == true) {
                              _accesosActuales[rol]!.add(modulo);
                            } else {
                              _accesosActuales[rol]!.remove(modulo);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
