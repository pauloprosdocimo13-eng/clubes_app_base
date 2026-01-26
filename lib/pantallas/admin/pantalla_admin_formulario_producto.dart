import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart'; // Reutilizamos tu widget de subir fotos

class PantallaAdminFormularioProducto extends StatefulWidget {
  final ConfiguracionApp config;
  final String? productoId; // Si es null, es NUEVO

  const PantallaAdminFormularioProducto({
    super.key,
    required this.config,
    this.productoId,
  });

  @override
  State<PantallaAdminFormularioProducto> createState() => _PantallaAdminFormularioProductoState();
}

class _PantallaAdminFormularioProductoState extends State<PantallaAdminFormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _imagenController = TextEditingController();

  bool _activo = true; // Para ocultar productos sin stock sin borrarlos

  @override
  void initState() {
    super.initState();
    if (widget.productoId != null) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('tienda').doc(widget.productoId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _tituloController.text = data['titulo'] ?? '';
        _precioController.text = data['precio']?.toString() ?? '';
        _descripcionController.text = data['descripcion'] ?? '';
        _imagenController.text = data['imagen_url'] ?? '';
        _activo = data['activo'] ?? true;
      }
    } catch (e) {
      print("Error cargando producto: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta la foto del producto")));
      return;
    }

    setState(() => _cargando = true);

    // Formateamos precio a número
    double precio = double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0.0;

    final datos = {
      'titulo': _tituloController.text.trim(),
      'precio': precio,
      'descripcion': _descripcionController.text.trim(),
      'imagen_url': _imagenController.text.trim(),
      'activo': _activo,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.productoId == null) {
        // Nuevo
        await FirebaseFirestore.instance.collection('tienda').add({
          ...datos,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
      } else {
        // Editar
        await FirebaseFirestore.instance.collection('tienda').doc(widget.productoId).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productoId == null ? "Nuevo Producto" : "Editar Producto"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarProducto)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // SWITCH ACTIVO/STOCK
            SwitchListTile(
              title: const Text("Producto Activo / En Stock"),
              subtitle: Text(_activo ? "Visible en la app" : "Oculto (Sin stock)"),
              value: _activo,
              activeColor: widget.config.colorPrimario,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const Divider(),

            // TÍTULO
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: "Nombre del Producto",
                hintText: "Ej: Camiseta Titular 2024",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            ),
            const SizedBox(height: 15),

            // PRECIO Y DETALLE
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Precio (\$)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) => v!.isEmpty ? "Falta precio" : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(
                      labelText: "Detalle corto",
                      hintText: "Ej: Talles S, M, L",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // FOTO
            const Text("Foto del Producto:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            InputImagen(
              urlInicial: _imagenController.text,
              carpeta: 'tienda', // Carpeta en Storage
              alSubirImagen: (url) => _imagenController.text = url,
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.colorPrimario,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _guardarProducto,
              child: const Text("GUARDAR EN TIENDA"),
            ),
          ],
        ),
      ),
    );
  }
}