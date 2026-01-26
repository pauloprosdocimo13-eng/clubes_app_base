import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class InputImagen extends StatefulWidget {
  final String? urlInicial;
  final String carpeta; // Ej: 'socios_fotos', 'noticias', etc.
  final Function(String) alSubirImagen;

  const InputImagen({
    super.key,
    this.urlInicial,
    required this.carpeta,
    required this.alSubirImagen,
  });

  @override
  State<InputImagen> createState() => _InputImagenState();
}

class _InputImagenState extends State<InputImagen> {
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;

  Future<void> _seleccionarOrigen() async {
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
      // 1. Seleccionar/Tomar foto
      // imageQuality: 50 reduce el tamaño para no gastar tanto espacio en Firebase y subir rápido
      final XFile? imagen = await _picker.pickImage(source: origen, imageQuality: 50); 
      
      if (imagen == null) return;

      setState(() => _subiendo = true);

      // 2. Referencia en Storage
      // Usamos timestamp para que el nombre sea único
      final String nombreArchivo = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child(widget.carpeta)
          .child(nombreArchivo);

      // 3. Subir archivo
      final File archivo = File(imagen.path);
      await ref.putFile(archivo);

      // 4. Obtener URL pública
      final String urlDescarga = await ref.getDownloadURL();

      // 5. Avisar al formulario padre
      widget.alSubirImagen(urlDescarga);

    } catch (e) {
      print("Error subiendo imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir imagen: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos si hay imagen cargada (URL válida)
    final bool tieneImagen = widget.urlInicial != null && widget.urlInicial!.isNotEmpty;

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
                    ? null // Si tiene imagen, no mostramos ícono, solo la foto de fondo
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                            SizedBox(height: 5),
                            Text("Foto", style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
          ),
        ),
        if (tieneImagen && !_subiendo)
          TextButton(
            onPressed: _seleccionarOrigen, 
            child: const Text("Cambiar", style: TextStyle(fontSize: 12))
          )
      ],
    );
  }
}