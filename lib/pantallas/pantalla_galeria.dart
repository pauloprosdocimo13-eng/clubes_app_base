import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <--- IMPORTANTE: Librería de Caché
import '../configuracion/configuracion_app.dart';

class PantallaGaleria extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaGaleria({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  State<PantallaGaleria> createState() => _PantallaGaleriaState();
}

class _PantallaGaleriaState extends State<PantallaGaleria> {
  String _categoriaSeleccionada = 'General';
  List<String> _categorias = [];
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _cargarCategoriasDelDeporte();
  }

  // --- LÓGICA DINÁMICA: Leer categorías reales de Firebase ---
  Future<void> _cargarCategoriasDelDeporte() async {
    List<String> categoriasEncontradas = [];

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        final menuDeportes = List.from(data['menu_deportes'] ?? []);

        final deporteData = menuDeportes.firstWhere(
                (element) => element['id'] == widget.deporteId,
            orElse: () => <String, dynamic>{}
        );

        if (deporteData is Map && deporteData.containsKey('categorias')) {
          categoriasEncontradas = List<String>.from(deporteData['categorias']);
        }
      }
    } catch (e) {
      print("Error cargando categorías galería: $e");
    }

    if (!categoriasEncontradas.contains('General')) {
      categoriasEncontradas.insert(0, 'General');
    }

    if (mounted) {
      setState(() {
        _categorias = categoriasEncontradas;
        _cargandoCategorias = false;
        _categoriaSeleccionada = _categorias.first;
      });
    }
  }

  // Visualizar foto en pantalla completa (CON ZOOM MEJORADO) 🔍
  void _verFotoGrande(String url, String titulo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(titulo),
          ),
          // CORRECCIÓN: El InteractiveViewer ahora es el PADRE que ocupa toda la pantalla
          body: InteractiveViewer(
            panEnabled: true, // Moverse por la foto
            boundaryMargin: const EdgeInsets.all(0), // Sin márgenes extraños
            minScale: 0.5,
            maxScale: 4.0,
            child: Center( // Centramos la imagen en el espacio disponible
              child: Hero(
                tag: url,
                child: CachedNetworkImage( 
                  imageUrl: url,
                  // IMPORTANTE: Hacemos que la imagen ocupe todo el espacio posible
                  // para que el área táctil del zoom sea toda la pantalla.
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain, 
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // FILTRO DE CATEGORÍAS (TIPO CHIPS)
          if (!_cargandoCategorias)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.grey[100],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  final cat = _categorias[index];
                  final seleccionado = cat == _categoriaSeleccionada;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: seleccionado,
                      selectedColor: widget.config.colorPrimario,
                      labelStyle: TextStyle(
                          color: seleccionado ? Colors.white : Colors.black
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _categoriaSeleccionada = cat);
                      },
                    ),
                  );
                },
              ),
            ),

          // GRILLA DE FOTOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('galeria')
                  .where('deporte_id', isEqualTo: widget.deporteId)
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var fotos = snapshot.data!.docs;

                // FILTRADO EN MEMORIA
                if (_categoriaSeleccionada != 'General') {
                  fotos = fotos.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['categoria'] == _categoriaSeleccionada;
                  }).toList();
                }

                if (fotos.isEmpty) {
                  return const Center(child: Text("No hay fotos en esta categoría"));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 columnas
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                    childAspectRatio: 1, // Cuadradas
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (context, index) {
                    final data = fotos[index].data() as Map<String, dynamic>;
                    final url = data['imagen_url'] ?? '';
                    final titulo = data['titulo'] ?? '';

                    return GestureDetector(
                      onTap: () => _verFotoGrande(url, titulo),
                      child: Hero(
                        tag: url,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            // Placeholder liviano mientras carga
                            placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            ),
                            // Si falla la carga (ej: link roto)
                            errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, size: 30, color: Colors.grey)
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