import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:clubes_app_base/configuracion/configuracion_app.dart';

class InputImagen extends StatefulWidget {
  final String? urlInicial;
  final String carpeta;
  final Function(String) alSubirImagen;
  final Function(bool)? onCargando;
  final String? nombreArchivo; // <--- NUEVO: Para recibir el DNI

  const InputImagen({
    super.key,
    this.urlInicial,
    required this.carpeta,
    required this.alSubirImagen,
    this.onCargando,
    this.nombreArchivo, // <--- NUEVO
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
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
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
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Tomar Foto (Cámara)"),
              onTap: () {
                Navigator.pop(context);
                _procesarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Elegir de Galería"),
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
      if (widget.onCargando != null) widget.onCargando!(true);

      // --- ACÁ APLICAMOS TU IDEA DEL DNI ---
      // Obtenemos la extensión (ej: jpg, png)
      String extension = imagen.name.split('.').last;
      if (extension.isEmpty || extension.length > 4) extension = 'jpg';

      // Si nos pasaron el DNI, lo usamos. Si no, usamos el tiempo actual por las dudas.
      String nombreFinal =
          widget.nombreArchivo != null && widget.nombreArchivo!.isNotEmpty
          ? '${widget.nombreArchivo}.$extension'
          : 'socio_${DateTime.now().millisecondsSinceEpoch}.$extension';

      var uri = Uri.parse(ConfiguracionApp.actual.urlSubidaFoto);
      var request = http.MultipartRequest('POST', uri);

      // --- LA MAGIA MULTIPLATAFORMA ESTÁ ACÁ ---
      if (kIsWeb) {
        // En la Web no hay "rutas" de disco duro, leemos los bytes crudos a la memoria
        final bytes = await imagen.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('imagen', bytes, filename: nombreFinal),
        );
      } else {
        // En Celulares sí hay rutas físicas de archivos
        request.files.add(
          await http.MultipartFile.fromPath(
            'imagen',
            imagen.path,
            filename: nombreFinal, // <-- MANDAMOS EL DNI AL SERVIDOR
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final jsonResp = json.decode(respStr);

        if (jsonResp['status'] == 'ok') {
          // El servidor devuelve un link como: https://.../uploads/55692069.jpg
          // Le sumamos un parámetro de tiempo al final (?v=...) SOLO para engañar al celular
          // y obligarlo a refrescar la foto si el socio se sacó una foto nueva.
          String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String urlFinal = "${jsonResp['url']}?v=$timestamp";

          widget.alSubirImagen(urlFinal);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Foto subida al servidor"),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(
            jsonResp['message'] ?? "Error desconocido del servidor",
          );
        }
      } else {
        throw Exception("Error de conexión: ${response.statusCode}");
      }
    } catch (e) {
      print("Error subiendo imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al subir: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
      if (widget.onCargando != null) widget.onCargando!(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneImagen =
        widget.urlInicial != null && widget.urlInicial!.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: _subiendo ? null : _seleccionarOrigen,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[400]!),
              image: tieneImagen && !_subiendo
                  ? DecorationImage(
                      image: NetworkImage(widget.urlInicial!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _subiendo
                ? const Center(child: CircularProgressIndicator())
                : tieneImagen
                ? null
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                        SizedBox(height: 5),
                        Text(
                          "Foto",
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (tieneImagen && !_subiendo)
          TextButton(
            onPressed: _seleccionarOrigen,
            child: const Text("Cambiar", style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
