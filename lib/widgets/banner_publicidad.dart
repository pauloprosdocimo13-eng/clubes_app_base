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
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_sponsors.isEmpty || !_pageController.hasClients) return;

      int paginaActual = _pageController.page?.round() ?? 0;
      int siguientePagina = paginaActual + 1;

      if (siguientePagina >= _sponsors.length) {
        siguientePagina = 0;
      }

      _pageController.animateToPage(
        siguientePagina,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN MEJORADA: CON MENSAJE PREDETERMINADO ---
  Future<void> _abrirLink(String? url) async {
    if (url == null || url.trim().isEmpty) return;

    String linkLimpio = url.trim();
    Uri? uriFinal;

    if (linkLimpio.startsWith('http://') ||
        linkLimpio.startsWith('https://') ||
        linkLimpio.startsWith('www.')) {
      if (linkLimpio.startsWith('www.')) {
        linkLimpio = 'https://$linkLimpio';
      }
      uriFinal = Uri.parse(linkLimpio);
    } else {
      String telefonoSoloNumeros = linkLimpio.replaceAll(RegExp(r'[^0-9]'), '');

      if (telefonoSoloNumeros.isNotEmpty) {
        if (!telefonoSoloNumeros.startsWith('54')) {
          if (telefonoSoloNumeros.startsWith('11') ||
              telefonoSoloNumeros.startsWith('15')) {
            telefonoSoloNumeros = '549$telefonoSoloNumeros';
          } else if (telefonoSoloNumeros.startsWith('0')) {
            telefonoSoloNumeros = '549${telefonoSoloNumeros.substring(1)}';
          } else {
            telefonoSoloNumeros = '549$telefonoSoloNumeros';
          }
        }

        // ACÁ AGREGAMOS EL TEXTO PREDETERMINADO
        String mensaje =
            "Hola, vi su anuncio en la App del club y quería hacer una consulta.";
        uriFinal = Uri.parse(
          "https://wa.me/$telefonoSoloNumeros?text=${Uri.encodeComponent(mensaje)}",
        );
      }
    }

    if (uriFinal != null) {
      try {
        await launchUrl(uriFinal, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Error al abrir link/whatsapp: $e");
      }
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
            return const SizedBox.shrink();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          _sponsors = snapshot.data!.docs;

          return PageView.builder(
            controller: _pageController,
            itemCount: _sponsors.length,
            itemBuilder: (context, index) {
              final data = _sponsors[index].data() as Map<String, dynamic>;
              final String imagenUrl = data['imagen_url'] ?? '';
              final String link = data['link'] ?? '';

              return GestureDetector(
                onTap: () => _abrirLink(link),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
                    color: Colors.white,
                  ),
                  child: imagenUrl.isEmpty
                      ? Center(
                          child: Text(
                            data['nombre'] ?? 'Espacio Publicitario',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.bold,
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
