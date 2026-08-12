import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/pantallas/pantalla_inventario_admins_tusede.dart';
import '../../tusede/servicios/contexto_usuario_tusede.dart';
import '../../tusede/servicios/servicio_sesion_tusede.dart';

class PantallaAdminUsuarios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminUsuarios({super.key, required this.config});

  @override
  State<PantallaAdminUsuarios> createState() => _PantallaAdminUsuariosState();
}

class _PantallaAdminUsuariosState extends State<PantallaAdminUsuarios> {
  String _busqueda = '';

  bool _creandoUsuario = false;

  bool _esSuperAdminTuSede = false;

  @override
  void initState() {
    super.initState();

    _verificarAccesoTuSede();
  }

  // ============================================================
  // VERIFICAR SUPERADMIN TUSEDE
  // ============================================================

  Future<void> _verificarAccesoTuSede() async {
    // Damos tiempo al modo Shadow para completar
    // la vinculación después del login Legacy.
    await Future.delayed(const Duration(milliseconds: 600));

    var usuario = ContextoUsuarioTuSede.usuarioActualNullable;

    if (usuario == null) {
      try {
        usuario = await ServicioSesionTuSede.restaurarSesion();
      } catch (_) {
        usuario = null;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _esSuperAdminTuSede = usuario?.esSuperAdmin == true;
    });
  }

  // ============================================================
  // ABRIR INVENTARIO TUSEDE
  // ============================================================

  void _abrirInventarioTuSede() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PantallaInventarioAdminsTuSede()),
    );
  }

  // ============================================================
  // CAMBIAR ROL LEGACY
  // ============================================================

  Future<void> _cambiarRol(String emailId, String nuevoRol) async {
    try {
      await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(emailId)
          .update({'rol': nuevoRol});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rol de $emailId '
              'actualizado a $nuevoRol',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================================
  // CREAR USUARIO LEGACY
  // ============================================================

  Future<void> _crearNuevoUsuarioAuth(
    String nombre,
    String email,
    String password,
    String rolElegido,
  ) async {
    setState(() {
      _creandoUsuario = true;
    });

    FirebaseApp? appTemporal;

    try {
      // App secundaria temporal para no cerrar
      // la sesión del administrador actual.
      appTemporal = await Firebase.initializeApp(
        name: 'AppRegistroTemporal_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      await FirebaseAuth.instanceFor(
        app: appTemporal,
      ).createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(email)
          .set({
            'email': email,
            'nombre': nombre,
            'rol': rolElegido,
            'creado_el': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Usuario creado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al crear usuario';

      if (e.code == 'email-already-in-use') {
        mensaje = 'Este email ya existe.';
      }

      if (e.code == 'weak-password') {
        mensaje =
            'La contraseña es muy débil '
            '(mínimo 6 caracteres).';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (appTemporal != null) {
        try {
          await appTemporal.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _creandoUsuario = false;
        });
      }
    }
  }

  // ============================================================
  // DIÁLOGO NUEVO USUARIO
  // ============================================================

  void _mostrarDialogoNuevoUsuario() {
    final nombreCtrl = TextEditingController();

    final emailCtrl = TextEditingController();

    final passCtrl = TextEditingController();

    String rolSeleccionado = 'administracion';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Crear Nuevo Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y Apellido',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),

                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña (min 6)',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Asignar Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(
                            'Súper Admin '
                            '(Acceso Total)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'tesoreria',
                          child: Text(
                            'Tesorería '
                            '(Dinero y Control)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'administracion',
                          child: Text(
                            'Administración '
                            '(Secretaría)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'deportes',
                          child: Text(
                            'Deportes '
                            '(Profes/DT)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'institucional',
                          child: Text(
                            'Institucional '
                            '(Comisión)',
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            rolSeleccionado = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _creandoUsuario
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _creandoUsuario
                      ? null
                      : () {
                          if (nombreCtrl.text.isEmpty ||
                              emailCtrl.text.isEmpty ||
                              passCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Completá todos '
                                  'los campos',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );

                            return;
                          }

                          _crearNuevoUsuarioAuth(
                            nombreCtrl.text.trim(),
                            emailCtrl.text.trim().toLowerCase(),
                            passCtrl.text.trim(),
                            rolSeleccionado,
                          );
                        },
                  child: _creandoUsuario
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('CREAR CUENTA'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,

        // El acceso al inventario TuSede
        // solamente aparece para el
        // superadministrador central.
        actions: [
          if (_esSuperAdminTuSede)
            IconButton(
              tooltip: 'Estado migración TuSede',
              onPressed: _abrirInventarioTuSede,
              icon: const Icon(Icons.cloud_sync),
            ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Crear Usuario'),
        onPressed: _mostrarDialogoNuevoUsuario,
      ),
      body: Column(
        children: [
          // ====================================================
          // BARRA DE BÚSQUEDA
          // ====================================================
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Buscar por email '
                    'o nombre...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) {
                setState(() {
                  _busqueda = valor.toLowerCase();
                });
              },
            ),
          ),

          // ====================================================
          // LISTA LEGACY
          // ====================================================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('permisos_admin')
                  .orderBy('creado_el', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usuarios = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final email = doc.id.toLowerCase();

                  final nombre = (data['nombre'] ?? '')
                      .toString()
                      .toLowerCase();

                  return email.contains(_busqueda) ||
                      nombre.contains(_busqueda);
                }).toList();

                if (usuarios.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron '
                      'usuarios.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];

                    final data = doc.data() as Map<String, dynamic>;

                    final String email = doc.id;

                    final String nombre =
                        data['nombre']?.toString() ?? 'Sin nombre';

                    final String rolActual =
                        data['rol']?.toString() ?? 'usuario';

                    Color colorRol = Colors.blueGrey;

                    if (rolActual == 'admin') {
                      colorRol = Colors.red[900]!;
                    }

                    if (rolActual == 'tesoreria') {
                      colorRol = Colors.green[800]!;
                    }

                    if (rolActual == 'administracion') {
                      colorRol = Colors.orange[800]!;
                    }

                    if (rolActual == 'deportes') {
                      colorRol = Colors.blue[800]!;
                    }

                    if (rolActual == 'institucional') {
                      colorRol = Colors.purple[800]!;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorRol,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(email),
                        trailing: PopupMenuButton<String>(
                          onSelected: (nuevoRol) {
                            _cambiarRol(email, nuevoRol);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'admin',
                              child: Text('Súper Admin'),
                            ),
                            PopupMenuItem(
                              value: 'tesoreria',
                              child: Text('Tesorería'),
                            ),
                            PopupMenuItem(
                              value: 'administracion',
                              child: Text('Administración'),
                            ),
                            PopupMenuItem(
                              value: 'deportes',
                              child: Text('Deportes'),
                            ),
                            PopupMenuItem(
                              value: 'institucional',
                              child: Text('Institucional'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorRol.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorRol),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  rolActual.toUpperCase(),
                                  style: TextStyle(
                                    color: colorRol,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
