import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminEspacios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminEspacios({super.key, required this.config});

  @override
  State<PantallaAdminEspacios> createState() => _PantallaAdminEspaciosState();
}

class _PantallaAdminEspaciosState extends State<PantallaAdminEspacios> {

  // --- NUEVA FUNCIÓN: CONFIGURAR TELÉFONO WHATSAPP ---
  void _configurarTelefono() {
    final TextEditingController _telCtrl = TextEditingController();

    // Mostramos un diálogo para cargar el número
    showDialog(
      context: context,
      builder: (context) {
        // Usamos FutureBuilder para leer el número actual si ya existe
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('configuracion').doc('reservas').get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            // Si ya hay un número guardado, lo ponemos en el campo
            if (_telCtrl.text.isEmpty && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              _telCtrl.text = data['telefono_wsp'] ?? '';
            }

            return AlertDialog(
              title: const Text("Teléfono de Reservas"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Ingresá el número al cual llegarán los pedidos de reserva (con código de país, sin +)."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Ej: 5491122334455",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat, color: Colors.green),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    // Guardamos en Firebase
                    await FirebaseFirestore.instance.collection('configuracion').doc('reservas').set({
                      'telefono_wsp': _telCtrl.text.trim(),
                    }, SetOptions(merge: true));

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teléfono actualizado")));
                    }
                  },
                  child: const Text("Guardar"),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- FORMULARIO DE ESPACIOS (Igual que antes) ---
  void _mostrarFormulario({String? id, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormularioEspacio(config: widget.config, id: id, data: data),
    );
  }

  void _borrarEspacio(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar espacio?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('espacios').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Borrar", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Espacios"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          // BOTÓN DE CONFIGURACIÓN DE TELÉFONO
          IconButton(
            icon: const Icon(Icons.phone_iphone),
            tooltip: "Configurar WhatsApp de Reservas",
            onPressed: _configurarTelefono,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.config.colorPrimario,
        child: const Icon(Icons.add),
        onPressed: () => _mostrarFormulario(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('espacios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay espacios cargados (Canchas, Salones, etc.)"));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (data['foto_url'] != null && data['foto_url'] != '')
                      Image.network(data['foto_url'], height: 150, width: double.infinity, fit: BoxFit.cover),
                    ListTile(
                      title: Text(data['titulo'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${data['descripcion'] ?? ''}\nPrecio: \$${data['precio'] ?? '0'}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(id: doc.id, data: data)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _borrarEspacio(doc.id)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET DEL FORMULARIO ---
class _FormularioEspacio extends StatefulWidget {
  final ConfiguracionApp config;
  final String? id;
  final Map<String, dynamic>? data;

  const _FormularioEspacio({required this.config, this.id, this.data});

  @override
  State<_FormularioEspacio> createState() => _FormularioEspacioState();
}

class _FormularioEspacioState extends State<_FormularioEspacio> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _fotoCtrl = TextEditingController();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tituloCtrl.text = widget.data!['titulo'] ?? '';
      _descCtrl.text = widget.data!['descripcion'] ?? '';
      _precioCtrl.text = widget.data!['precio'] ?? '';
      _fotoCtrl.text = widget.data!['foto_url'] ?? '';
    }
  }

  Future<void> _guardar() async {
    setState(() => _cargando = true);
    final datos = {
      'titulo': _tituloCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'precio': _precioCtrl.text.trim(),
      'foto_url': _fotoCtrl.text.trim(),
    };

    if (widget.id == null) {
      await FirebaseFirestore.instance.collection('espacios').add(datos);
    } else {
      await FirebaseFirestore.instance.collection('espacios').doc(widget.id).update(datos);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.id == null ? "Nuevo Espacio" : "Editar Espacio", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          InputImagen(urlInicial: _fotoCtrl.text, carpeta: 'espacios', alSubirImagen: (url) => _fotoCtrl.text = url),
          const SizedBox(height: 10),
          TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: "Nombre (ej: Cancha 5)", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Descripción (ej: Techada, con luz)", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio x Hora (aprox)", border: OutlineInputBorder(), prefixText: "\$ ")),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _cargando ? null : _guardar, child: const Text("GUARDAR"))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}