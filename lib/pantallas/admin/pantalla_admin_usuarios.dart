import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../configuracion/configuracion_app.dart';

class PantallaAdminUsuarios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminUsuarios({super.key, required this.config});

  @override
  State<PantallaAdminUsuarios> createState() => _PantallaAdminUsuariosState();
}

class _PantallaAdminUsuariosState extends State<PantallaAdminUsuarios> {
  String _busqueda = "";
  bool _creandoUsuario = false;

  // --- FUNCIÓN PARA CAMBIAR ROL ---
  Future<void> _cambiarRol(String emailId, String nuevoRol) async {
    try {
      await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(emailId)
          .update({'rol': nuevoRol});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Rol de $emailId actualizado a $nuevoRol"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    }
  }

  // --- CREAR USUARIO EN AUTH Y EN PERMISOS_ADMIN ---
  Future<void> _crearNuevoUsuarioAuth(
    String nombre,
    String email,
    String password,
    String rolElegido,
  ) async {
    setState(() => _creandoUsuario = true);

    try {
      // 1. App Secundaria temporal para no desloguear al Admin
      FirebaseApp appTemporal = await Firebase.initializeApp(
        name: 'AppRegistroTemporal',
        options: Firebase.app().options,
      );

      // 2. Creamos en Authentication
      await FirebaseAuth.instanceFor(
        app: appTemporal,
      ).createUserWithEmailAndPassword(email: email, password: password);

      // 3. Guardamos en TU colección usando el EMAIL como Document ID
      await FirebaseFirestore.instance
          .collection('permisos_admin')
          .doc(email)
          .set({
            'email': email,
            'nombre': nombre,
            'rol': rolElegido,
            'creado_el': FieldValue.serverTimestamp(),
          });

      // 4. Destruimos la app temporal
      await appTemporal.delete();

      if (mounted) {
        Navigator.pop(context); // Cerramos el diálogo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Usuario creado con éxito!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al crear usuario";
      if (e.code == 'email-already-in-use') mensaje = "Este email ya existe.";
      if (e.code == 'weak-password')
        mensaje = "La contraseña es muy débil (mínimo 6 caracteres).";
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _creandoUsuario = false);
    }
  }

  // --- DIÁLOGO DE NUEVO USUARIO ---
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
              title: const Text("Crear Nuevo Usuario"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre y Apellido",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: "Contraseña (min 6)",
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: "Asignar Rol",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "admin",
                          child: Text("Súper Admin (Acceso Total)"),
                        ),
                        DropdownMenuItem(
                          value: "tesoreria",
                          child: Text("Tesorería (Dinero y Control)"),
                        ),
                        DropdownMenuItem(
                          value: "administracion",
                          child: Text("Administración (Secretaría)"),
                        ),
                        DropdownMenuItem(
                          value: "deportes",
                          child: Text("Deportes (Profes/DT)"),
                        ),
                        DropdownMenuItem(
                          value: "institucional",
                          child: Text("Institucional (Comisión)"),
                        ),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => rolSeleccionado = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _creandoUsuario
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text("Cancelar"),
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
                                content: Text("Completá todos los campos"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setState(() {});
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
                      : const Text("CREAR CUENTA"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text("Crear Usuario"),
        onPressed: _mostrarDialogoNuevoUsuario,
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar por email o nombre...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _busqueda = valor.toLowerCase()),
            ),
          ),

          // LISTA DE USUARIOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('permisos_admin')
                  .orderBy('creado_el', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final usuarios = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = (doc.id)
                      .toLowerCase(); // Ahora el ID del doc es el email
                  final nombre = (data['nombre'] ?? '')
                      .toString()
                      .toLowerCase();
                  return email.contains(_busqueda) ||
                      nombre.contains(_busqueda);
                }).toList();

                if (usuarios.isEmpty)
                  return const Center(
                    child: Text("No se encontraron usuarios."),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String email =
                        doc.id; // En tu sistema, el doc.id es el email
                    final String nombre = data['nombre'] ?? 'Sin nombre';
                    final String rolActual = data['rol'] ?? 'usuario';

                    // Colores visuales
                    Color colorRol = Colors.blueGrey;
                    if (rolActual == 'admin') colorRol = Colors.red[900]!;
                    if (rolActual == 'tesoreria') colorRol = Colors.green[800]!;
                    if (rolActual == 'administracion')
                      colorRol = Colors.orange[800]!;
                    if (rolActual == 'deportes') colorRol = Colors.blue[800]!;
                    if (rolActual == 'institucional')
                      colorRol = Colors.purple[800]!;

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
                          onSelected: (nuevoRol) =>
                              _cambiarRol(email, nuevoRol),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: "admin",
                              child: Text("Súper Admin"),
                            ),
                            PopupMenuItem(
                              value: "tesoreria",
                              child: Text("Tesorería"),
                            ),
                            PopupMenuItem(
                              value: "administracion",
                              child: Text("Administración"),
                            ),
                            PopupMenuItem(
                              value: "deportes",
                              child: Text("Deportes"),
                            ),
                            PopupMenuItem(
                              value: "institucional",
                              child: Text("Institucional"),
                            ),
                          ],
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
