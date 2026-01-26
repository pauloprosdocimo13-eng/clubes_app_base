import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_galeria.dart';

class PantallaAdminGaleria extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaAdminGaleria({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaAdminGaleria> createState() => _PantallaAdminGaleriaState();
}

class _PantallaAdminGaleriaState extends State<PantallaAdminGaleria> {
  String _categoriaSeleccionada = 'General';
  List<String> _categorias = [];
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _cargarCategoriasDelDeporte();
  }

  // --- LÓGICA DINÁMICA (Igual que en el formulario) ---
  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes = List.from(data['menu_deportes'] ?? []);

        final deporteData = menuDeportes.firstWhere(
                (e) => e['id'] == widget.deporteId,
            orElse: () => null
        );

        if (deporteData != null && deporteData['categorias'] != null) {
          categoriasEncontradas = List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      print("Error config: $e");
    }

    if (categoriasEncontradas.isEmpty) {
      _generarCategoriasLegacy();
    } else {
      _categorias = categoriasEncontradas;
    }

    // Siempre agregamos General para fotos del club
    if (!_categorias.contains('General')) {
      _categorias.add('General');
    }

    // Validamos que la selección actual exista, sino reset a General
    if (!_categorias.contains(_categoriaSeleccionada)) {
      _categoriaSeleccionada = 'General';
    }

    if (mounted) {
      setState(() => _cargandoCategorias = false);
    }
  }

  void _generarCategoriasLegacy() {
    _categorias = [];
    if (!widget.deporteId.contains('baby')) {
      _categorias = ['Primera', 'Reserva', 'General'];
    } else {
      final int anioActual = DateTime.now().year;
      for (int i = anioActual - 13; i <= anioActual - 7; i++) {
        _categorias.add(i.toString());
      }
      _categorias.add('General');
    }
  }
  // ----------------------------------------------------

  void _borrarFoto(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar foto?"),
        content: const Text("Se eliminará del álbum."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('galeria').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Borrar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Galería"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.config.colorPrimario,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaAdminFormularioGaleria(
                config: widget.config,
                deporteId: widget.deporteId,
              ),
            ),
          ).then((_) {
            // Al volver, recargamos por si se agregó una categoría nueva (aunque es raro en galería)
            _cargarCategoriasDelDeporte();
          });
        },
      ),
      body: Column(
        children: [
          // FILTRO DE ÁLBUM
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ver álbum:", style: TextStyle(fontWeight: FontWeight.bold)),

                _cargandoCategorias
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : DropdownButton<String>(
                  value: _categoriaSeleccionada,
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _categoriaSeleccionada = v);
                  },
                ),
              ],
            ),
          ),

          // GRILLA DE FOTOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('galeria')
                  .where('deporte_id', isEqualTo: widget.deporteId)
                  .where('categoria', isEqualTo: _categoriaSeleccionada)
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_album_outlined, size: 50, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text("Álbum '$_categoriaSeleccionada' vacío"),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final url = data['imagen_url'] ?? '';

                    return Stack(
                      children: [
                        // LA FOTO
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: url.isNotEmpty
                                ? Image.network(url, fit: BoxFit.cover)
                                : Container(color: Colors.grey[300]),
                          ),
                        ),
                        // BOTÓN BORRAR
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _borrarFoto(id),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                              ),
                              child: const Icon(Icons.delete, color: Colors.red, size: 18),
                            ),
                          ),
                        ),
                        // TÍTULO (Abajo)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              data['titulo'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
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