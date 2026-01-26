import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class BannerPublicidad extends StatefulWidget {
  const BannerPublicidad({super.key});

  @override
  State<BannerPublicidad> createState() => _BannerPublicidadState();
}

class _BannerPublicidadState extends State<BannerPublicidad> {
  final PageController _pageController = PageController();
  Timer? _timer;
  List<DocumentSnapshot> _sponsors = [];

  @override
  void initState() {
    super.initState();
    // Iniciamos el ciclo automático
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_sponsors.isEmpty || !_pageController.hasClients) return;

      // 1. Preguntamos al controlador en qué página estamos REALMENTE
      int paginaActual = _pageController.page?.round() ?? 0;
      int siguientePagina = paginaActual + 1;

      // 2. Si llegamos al final, volvemos al principio (0)
      if (siguientePagina >= _sponsors.length) {
        siguientePagina = 0;
      }

      // 3. Animación suave
      _pageController.animateToPage(
        siguientePagina,
        duration: const Duration(milliseconds: 800), // Más lento y elegante
        curve: Curves.easeInOut, // Movimiento más natural
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _abrirLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error al abrir link: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('publicidad')
            .where('activo', isEqualTo: true)
            .orderBy('orden')
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            // Si hay error, ocultamos el banner para no afear la app
            return const SizedBox.shrink();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          _sponsors = snapshot.data!.docs;

          return PageView.builder(
            controller: _pageController,
            itemCount: _sponsors.length,
            // Quitamos el onPageChanged innecesario para evitar conflictos
            itemBuilder: (context, index) {
              final data = _sponsors[index].data() as Map<String, dynamic>;
              final String imagenUrl = data['imagen_url'] ?? '';
              final String link = data['link'] ?? '';

              return GestureDetector(
                onTap: () => _abrirLink(link),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Sombra suave
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: imagenUrl.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(imagenUrl),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: Colors.white, // Fondo blanco por si la imagen es PNG transparente
                  ),
                  child: imagenUrl.isEmpty
                      ? Center(
                    child: Text(
                      data['nombre'] ?? 'Espacio Publicitario',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}