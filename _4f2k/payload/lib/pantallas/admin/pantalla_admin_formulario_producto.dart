import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminFormularioProducto extends StatefulWidget {
  final ConfiguracionApp config;
  final String? productoId;

  const PantallaAdminFormularioProducto({
    super.key,
    required this.config,
    this.productoId,
  });

  @override
  State<PantallaAdminFormularioProducto> createState() =>
      _PantallaAdminFormularioProductoState();
}

class _PantallaAdminFormularioProductoState
    extends State<PantallaAdminFormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _tituloController =
      TextEditingController();
  final TextEditingController _precioController =
      TextEditingController();
  final TextEditingController _descripcionController =
      TextEditingController();
  final TextEditingController _imagenController =
      TextEditingController();

  bool _activo = true;

  @override
  void initState() {
    super.initState();

    if (widget.productoId != null) {
      _cargarDatos();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    _imagenController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    try {
      final doc = await ServicioDatosClub.productos
          .doc(widget.productoId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _tituloController.text =
            (data['titulo'] ?? '').toString();
        _precioController.text =
            data['precio']?.toString() ?? '';
        _descripcionController.text =
            (data['descripcion'] ?? '').toString();
        _imagenController.text =
            (data['imagen_url'] ?? '').toString();
        _activo = data['activo'] != false;
      }
    } catch (e) {
      debugPrint('Error cargando producto: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imagenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta la foto del producto'),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    final precio = double.tryParse(
          _precioController.text
              .trim()
              .replaceAll(',', '.'),
        ) ??
        0.0;

    final datos = <String, dynamic>{
      'titulo': _tituloController.text.trim(),
      'precio': precio,
      'descripcion': _descripcionController.text.trim(),
      'imagen_url': _imagenController.text.trim(),
      'activo': _activo,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.productoId == null) {
        await ServicioDatosClub.productos.add({
          ...datos,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
      } else {
        await ServicioDatosClub.productos
            .doc(widget.productoId)
            .update(datos);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usaCentral =
        ServicioDatosClub.usaTuSedeCentral;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productoId == null
              ? 'Nuevo Producto'
              : 'Editar Producto',
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _cargando
                ? null
                : _guardarProducto,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Producto Activo / En Stock',
                    ),
                    subtitle: Text(
                      _activo
                          ? 'Visible en la app'
                          : 'Oculto (Sin stock)',
                    ),
                    value: _activo,
                    activeColor:
                        widget.config.colorPrimario,
                    onChanged: (v) {
                      setState(() => _activo = v);
                    },
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Producto',
                      hintText:
                          'Ej: Camiseta Titular 2024',
                      border: OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.shopping_bag),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Campo obligatorio'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller:
                              _precioController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText: 'Precio (\$)',
                            border:
                                OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.attach_money,
                            ),
                          ),
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'Falta precio';
                            }

                            final numero =
                                double.tryParse(
                              v.trim().replaceAll(
                                    ',',
                                    '.',
                                  ),
                            );

                            if (numero == null ||
                                numero < 0) {
                              return 'Precio inválido';
                            }

                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller:
                              _descripcionController,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Detalle corto',
                            hintText:
                                'Ej: Talles S, M, L',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Foto del Producto:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  InputImagen(
                    urlInicial:
                        _imagenController.text,
                    carpeta: usaCentral
                        ? 'productos'
                        : 'tienda',
                    aislarPorClub: usaCentral,
                    alSubirImagen: (url) {
                      if (mounted) {
                        setState(() {
                          _imagenController.text = url;
                        });
                      } else {
                        _imagenController.text = url;
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(
                        double.infinity,
                        50,
                      ),
                    ),
                    onPressed: _guardarProducto,
                    child: const Text(
                      'GUARDAR EN TIENDA',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
