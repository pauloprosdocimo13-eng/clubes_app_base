import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart'; // Importante para detectar si es Web (kIsWeb)
import '../configuracion/configuracion_app.dart';

class PantallaPosicionesWeb extends StatefulWidget {
  final ConfiguracionApp config;
  final String url;
  final String titulo;

  const PantallaPosicionesWeb({
    super.key,
    required this.config,
    required this.url,
    required this.titulo,
  });

  @override
  State<PantallaPosicionesWeb> createState() => _PantallaPosicionesWebState();
}

class _PantallaPosicionesWebState extends State<PantallaPosicionesWeb> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController();

    if (kIsWeb) {
      // Si estamos en Chrome (Web), apagamos la ruedita de carga directo 
      // porque la web no soporta NavigationDelegate
      _cargando = false;
    } else {
      // Si estamos en el Celular (Android/iOS), activamos JS y el espía de carga
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _cargando = false;
              });
            }
          },
        ),
      );
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_cargando)
            Center(
              child: CircularProgressIndicator(
                color: widget.config.colorPrimario,
              ),
            ),
        ],
      ),
    );
  }
}