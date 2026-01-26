import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminRivales extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAdminRivales({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaAdminRivales> createState() => _PantallaAdminRivalesState();
}

class _PantallaAdminRivalesState extends State<PantallaAdminRivales> {

  void _mostrarFormulario({String? id, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Importante para que el teclado empuje
      builder: (context) => _FormularioRival(
          config: widget.config,
          deporteId: widget.deporteId,
          id: id,
          data: data
      ),
    );
  }

  void _borrarRival(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar Club?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('rivales').doc(id).delete();
                Navigator.pop(ctx);
              },
              child: const Text("BORRAR", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Rivales"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.config.colorPrimario,
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rivales')
            .where('deporte_id', isEqualTo: widget.deporteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay rivales cargados."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final nombre = data['nombre'] ?? 'Sin Nombre';
              final direccion = data['direccion'] ?? '';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shield),
                  title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(direccion),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _mostrarFormulario(id: id, data: data)
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _borrarRival(id)
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- FORMULARIO (CORREGIDO PARA TECLADO) ---
class _FormularioRival extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;
  final String? id;
  final Map<String, dynamic>? data;

  const _FormularioRival({
    required this.config,
    required this.deporteId,
    this.id,
    this.data
  });

  @override
  State<_FormularioRival> createState() => _FormularioRivalState();
}

class _FormularioRivalState extends State<_FormularioRival> {
  final _nombreCtrl = TextEditingController();
  final _direcCtrl = TextEditingController();
  final _mapaCtrl = TextEditingController();
  final _escudoCtrl = TextEditingController();
  bool _esTechado = false;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _nombreCtrl.text = widget.data!['nombre'] ?? '';
      _direcCtrl.text = widget.data!['direccion'] ?? '';
      _mapaCtrl.text = widget.data!['mapa_url'] ?? '';
      _escudoCtrl.text = widget.data!['escudo_url'] ?? '';
      _esTechado = widget.data!['es_techado'] ?? false;
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.isEmpty) return;
    setState(() => _cargando = true);

    final datos = {
      'deporte_id': widget.deporteId,
      'nombre': _nombreCtrl.text.trim(),
      'direccion': _direcCtrl.text.trim(),
      'mapa_url': _mapaCtrl.text.trim(),
      'escudo_url': _escudoCtrl.text.trim(),
      'es_techado': _esTechado,
    };

    if (widget.id == null) {
      await FirebaseFirestore.instance.collection('rivales').add(datos);
    } else {
      await FirebaseFirestore.instance.collection('rivales').doc(widget.id).update(datos);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN CLAVE: Padding basado en viewInsets (Teclado) + Scroll
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Levanta el form al salir el teclado
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView( // Permite scrollear si la pantalla es chica
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [
            Text(
              widget.id == null ? "Nuevo Rival" : "Editar Rival",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: _escudoCtrl.text.isNotEmpty
                      ? Image.network(_escudoCtrl.text, errorBuilder: (c,o,s) => const Icon(Icons.error))
                      : const Icon(Icons.shield),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputImagen(
                    urlInicial: _escudoCtrl.text,
                    carpeta: 'escudos_rivales',
                    alSubirImagen: (url) => setState(() => _escudoCtrl.text = url),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: "Nombre del Club", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _direcCtrl,
              decoration: const InputDecoration(labelText: "Dirección escrita (Ej: Cavia 2, ...)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mapaCtrl,
              decoration: const InputDecoration(
                  labelText: "Link de Google Maps (Opcional)",
                  hintText: "Si lo dejas vacío, se usará la dirección escrita",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map)
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("¿Es cancha Techada?"),
              value: _esTechado,
              onChanged: (v) => setState(() => _esTechado = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.colorPrimario,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _cargando ? null : _guardar,
                child: _cargando ? const CircularProgressIndicator(color: Colors.white) : const Text("GUARDAR"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}