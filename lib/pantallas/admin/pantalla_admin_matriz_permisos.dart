import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../configuracion/configuracion_app.dart';
import '../../../configuracion/admin_permisos.dart';

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
    'Pizarra Táctica',
    'Consola en VIVO',
    'Configurar Streaming',
    'Gestión Prode',
    'Votación Figura',
    'Tienda Oficial',
    'Gestionar Rifas',
  ];

  Map<String, List<String>> _accesosActuales = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarMatriz();
  }

  Future<void> _cargarMatriz() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('permisos_roles')
          .get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data()!;
        data.forEach((rol, modulos) {
          _accesosActuales[rol] = List<String>.from(modulos);
        });
      } else {
        // Si nunca se configuró, iniciamos los arrays vacíos o con lo básico
        for (var rol in _roles) {
          _accesosActuales[rol] = [];
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarMatriz() async {
    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('permisos_roles')
          .set(_accesosActuales);
      await AdminPermisos.inicializarMatriz(); // Recargamos en memoria inmediatamente

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Permisos guardados correctamente. Los usuarios verán los cambios al reiniciar su app.",
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
        onPressed: _cargando ? null : _guardarMatriz,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text("GUARDAR CAMBIOS"),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
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
