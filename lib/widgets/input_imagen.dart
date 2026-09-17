import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:clubes_app_base/configuracion/configuracion_app.dart';
import 'package:clubes_app_base/tusede/servicios/servicio_imagenes_tusede.dart';

class InputImagen extends StatefulWidget {
  final String? urlInicial;
  final String carpeta;
  final Function(String) alSubirImagen;
  final Function(bool)? onCargando;
  final String? nombreArchivo;

  /// Cuando es true:
  /// - NO usa urlSubidaFoto del flavor.
  /// - NO usa el PHP Legacy.
  /// - sube mediante la Cloud Function autenticada de TuSede Central.
  ///
  /// Cuando es false:
  /// - conserva exactamente el mecanismo histórico de Güemes/Legacy.
  final bool aislarPorClub;

  const InputImagen({
    super.key,
    this.urlInicial,
    required this.carpeta,
    required this.alSubirImagen,
    this.onCargando,
    this.nombreArchivo,
    this.aislarPorClub = false,
  });

  @override
  State<InputImagen> createState() => _InputImagenState();
}

class _InputImagenState extends State<InputImagen> {
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;

  Future<void> _seleccionarOrigen() async {
    bool esComputadora = false;

    if (!kIsWeb) {
      if (Platform.isWindows ||
          Platform.isMacOS ||
          Platform.isLinux) {
        esComputadora = true;
      }
    }

    if (kIsWeb || esComputadora) {
      _procesarImagen(ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: Colors.blue,
              ),
              title: const Text('Tomar Foto (Cámara)'),
              onTap: () {
                Navigator.pop(context);
                _procesarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Colors.green,
              ),
              title: const Text('Elegir de Galería'),
              onTap: () {
                Navigator.pop(context);
                _procesarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarImagen(ImageSource origen) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: origen,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (imagen == null) return;

      setState(() => _subiendo = true);
      widget.onCargando?.call(true);

      String extension = imagen.name.split('.').last.toLowerCase();

      if (extension.isEmpty || extension.length > 5) {
        extension = 'jpg';
      }

      // ==========================================================
      // TUSEDE CENTRAL
      // ==========================================================
      //
      // Solamente se usa cuando el módulo lo habilita explícitamente
      // con aislarPorClub=true.
      //
      // Ejemplo actual:
      // Noticias de Club Horizonte.
      //
      // Güemes NO entra en este bloque.
      if (widget.aislarPorClub) {
        final bytes = await imagen.readAsBytes();

        final url = await ServicioImagenesTuSede.subirImagen(
          bytes: bytes,
          carpeta: widget.carpeta,
          extension: extension,
          nombreBase: widget.nombreArchivo,
        );

        widget.alSubirImagen(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto subida a TuSede'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }

        return;
      }

      // ==========================================================
      // LEGACY
      // ==========================================================
      //
      // Se conserva el mecanismo histórico del proyecto.
      // Güemes sigue usando:
      // https://martinguemes.site/api/subir_foto.php
      //
      // Los demás flavors Legacy conservan su endpoint propio.
      final ahora = DateTime.now().millisecondsSinceEpoch;

      final nombreFinal =
          widget.nombreArchivo != null &&
                  widget.nombreArchivo!.trim().isNotEmpty
              ? '${widget.nombreArchivo!.trim()}.$extension'
              : 'socio_$ahora.$extension';

      final uri = Uri.parse(
        ConfiguracionApp.actual.urlSubidaFoto,
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      if (kIsWeb) {
        final bytes = await imagen.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            'imagen',
            bytes,
            filename: nombreFinal,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'imagen',
            imagen.path,
            filename: nombreFinal,
          ),
        );
      }

      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
          'Error de conexión: ${response.statusCode}',
        );
      }

      final respStr = await response.stream.bytesToString();
      final jsonResp = json.decode(respStr);

      if (jsonResp['status'] != 'ok') {
        throw Exception(
          jsonResp['message'] ??
              'Error desconocido del servidor',
        );
      }

      final timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();

      final urlFinal =
          "${jsonResp['url']}?v=$timestamp";

      widget.alSubirImagen(urlFinal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto subida al servidor'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _subiendo = false);
      }

      widget.onCargando?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneImagen =
        widget.urlInicial != null &&
        widget.urlInicial!.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap:
              _subiendo ? null : _seleccionarOrigen,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.grey[400]!,
              ),
              image:
                  tieneImagen && !_subiendo
                      ? DecorationImage(
                          image: NetworkImage(
                            widget.urlInicial!,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: _subiendo
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : tieneImagen
                    ? null
                    : const Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              color: Colors.grey,
                              size: 30,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Foto',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
        if (tieneImagen && !_subiendo)
          TextButton(
            onPressed: _seleccionarOrigen,
            child: const Text(
              'Cambiar',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
