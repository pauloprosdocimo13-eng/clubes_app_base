import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminFormularioJugador extends StatefulWidget {
  final ConfiguracionApp config;
  final String deporteId; // Tira SUGERIDA
  final String? jugadorId; // null = Nuevo

  const PantallaAdminFormularioJugador({
    super.key,
    required this.config,
    required this.deporteId,
    this.jugadorId,
  });

  @override
  State<PantallaAdminFormularioJugador> createState() => _PantallaAdminFormularioJugadorState();
}

class _PantallaAdminFormularioJugadorState extends State<PantallaAdminFormularioJugador> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _dorsalController = TextEditingController();
  final TextEditingController _posicionController = TextEditingController();
  final TextEditingController _golesController = TextEditingController(text: "0");
  final TextEditingController _asistenciasController = TextEditingController(text: "0"); // <--- NUEVO
  final TextEditingController _fotoController = TextEditingController();

  String _categoria = '2015'; // Valor por defecto, se actualizará
  List<String> _categoriasDisponibles = [];

  String? _deporteSeleccionadoId;
  List<Map<String, dynamic>> _deportesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _deporteSeleccionadoId = widget.deporteId;
    _cargarConfiguracion();
  }

  // 1. Cargar configuración (Categorías y Deportes)
  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        
        // Cargar Deportes
        final menu = List.from(data['menu_deportes'] ?? []);
        setState(() {
          _deportesDisponibles = menu.map((e) => e as Map<String, dynamic>).toList();
        });

        // Cargar Categorías del deporte seleccionado
        _actualizarCategoriasSegunDeporte();

        // Si estamos editando, cargar datos del jugador
        if (widget.jugadorId != null) {
          _cargarDatosJugador();
        }
      }
    } catch (e) {
      print("Error config: $e");
    }
  }

  void _actualizarCategoriasSegunDeporte() {
    if (_deporteSeleccionadoId == null) return;
    
    final deporte = _deportesDisponibles.firstWhere(
      (d) => d['id'] == _deporteSeleccionadoId, 
      orElse: () => {}
    );

    if (deporte.isNotEmpty && deporte.containsKey('categorias')) {
      setState(() {
        _categoriasDisponibles = List<String>.from(deporte['categorias']);
        if (_categoriasDisponibles.isNotEmpty) {
          // Si la categoría actual no está en la lista nueva, ponemos la primera
          if (!_categoriasDisponibles.contains(_categoria)) {
            _categoria = _categoriasDisponibles.first;
          }
        }
      });
    }
  }

  Future<void> _cargarDatosJugador() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('jugadores').doc(widget.jugadorId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = data['nombre'];
        _apellidoController.text = data['apellido'];
        _dorsalController.text = data['dorsal'].toString();
        _posicionController.text = data['posicion'];
        _golesController.text = (data['goles'] ?? 0).toString();
        _asistenciasController.text = (data['asistencias'] ?? 0).toString(); // <--- NUEVO
        _fotoController.text = data['foto'] ?? '';
        
        setState(() {
          _categoria = data['categoria'];
          _deporteSeleccionadoId = data['deporte_id'];
        });
        
        // Actualizamos las categorías por si cambió de deporte
        _actualizarCategoriasSegunDeporte();
        // Forzamos la categoría correcta después de actualizar la lista
        if (_categoriasDisponibles.contains(data['categoria'])) {
           setState(() => _categoria = data['categoria']);
        }
      }
    } catch (e) {
      print("Error cargando jugador: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarJugador() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final datos = {
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'dorsal': int.tryParse(_dorsalController.text) ?? 0,
        'posicion': _posicionController.text.trim(),
        'goles': int.tryParse(_golesController.text) ?? 0,
        'asistencias': int.tryParse(_asistenciasController.text) ?? 0, // <--- NUEVO
        'foto': _fotoController.text.trim(),
        'categoria': _categoria,
        'deporte_id': _deporteSeleccionadoId,
        'nombre_busqueda': _apellidoController.text.trim().toLowerCase(), // Para buscar fácil
      };

      if (widget.jugadorId == null) {
        await FirebaseFirestore.instance.collection('jugadores').add(datos);
      } else {
        await FirebaseFirestore.instance.collection('jugadores').doc(widget.jugadorId).update(datos);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jugadorId == null ? "Nuevo Jugador" : "Editar Jugador"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Selectores
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _deporteSeleccionadoId,
                          decoration: const InputDecoration(labelText: "Tira / Deporte", border: OutlineInputBorder()),
                          items: _deportesDisponibles.map((d) {
                            return DropdownMenuItem<String>(
                              value: d['id'],
                              child: Text(d['titulo']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _deporteSeleccionadoId = val);
                            _actualizarCategoriasSegunDeporte();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _categoriasDisponibles.contains(_categoria) ? _categoria : null,
                          decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
                          items: _categoriasDisponibles.map((c) {
                            return DropdownMenuItem<String>(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) => setState(() => _categoria = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Datos Personales
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _apellidoController,
                          decoration: const InputDecoration(labelText: "Apellido", border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dorsalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "N° Camiseta", border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _posicionController,
                          decoration: const InputDecoration(labelText: "Posición (ej: ARQ)", border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ESTADÍSTICAS (Goles y Asistencias)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _golesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Goles ⚽", 
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sports_soccer)
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _asistenciasController, // <--- CAMPO ASISTENCIAS
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Asistencias 👟", 
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.hiking) // Icono representativo de pase
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  InputImagen(
                    urlInicial: _fotoController.text,
                    carpeta: 'jugadores',
                    alSubirImagen: (url) {
                      _fotoController.text = url;
                    },
                  ),
                  
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: widget.config.colorPrimario,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50)
                    ),
                    onPressed: _guardarJugador,
                    child: const Text("GUARDAR JUGADOR"),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}