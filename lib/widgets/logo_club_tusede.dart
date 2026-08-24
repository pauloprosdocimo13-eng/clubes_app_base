import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';

/// Logo institucional de TuSede.
///
/// Prioridad:
/// 1. identidad.logoUrl de TuSede Central.
/// 2. rutaLogo de ConfiguracionApp (Legacy).
///
/// Si la URL remota está vacía, tarda en cargar o falla,
/// nunca dejamos la interfaz sin logo: se muestra el asset Legacy.
class LogoClubTuSede extends StatelessWidget {
  final ConfiguracionApp config;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool circular;
  final EdgeInsetsGeometry padding;

  const LogoClubTuSede({
    super.key,
    required this.config,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.circular = false,
    this.padding = EdgeInsets.zero,
  });

  Widget _logoLegacy() {
    return Image.asset(
      config.rutaLogo,
      width: width,
      height: height,
      fit: fit,
    );
  }

  Widget _logoRemoto(String url) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,

      // Flutter Web intenta por defecto descargar los bytes de la imagen.
      // Eso queda sujeto a CORS. Al usar un elemento HTML en Web,
      // el navegador puede mostrar imágenes públicas de Hostinger aunque
      // estén en otro dominio. En Android/iOS esta opción no cambia nada.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        // Mientras llega Hostinger mostramos el logo Legacy,
        // evitando parpadeos o espacios vacíos.
        return _logoLegacy();
      },
      errorBuilder: (context, error, stackTrace) {
        // Si Hostinger, la URL o CORS fallan, Güemes/club actual
        // conserva automáticamente su logo Legacy.
        return _logoLegacy();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String logoUrl = '';

    if (ContextoClub.estaInicializado) {
      logoUrl = ContextoClub.logoUrlCentral.trim();
    }

    Widget contenido = logoUrl.isEmpty
        ? _logoLegacy()
        : _logoRemoto(logoUrl);

    contenido = Padding(
      padding: padding,
      child: contenido,
    );

    if (!circular) {
      return contenido;
    }

    return ClipOval(
      child: SizedBox(
        width: width,
        height: height,
        child: contenido,
      ),
    );
  }
}
