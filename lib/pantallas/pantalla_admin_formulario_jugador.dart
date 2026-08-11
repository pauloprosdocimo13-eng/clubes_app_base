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
  State<PantallaAdminFormularioJugador> createState() =>
      _PantallaAdminFormularioJugadorState();
}

class _PantallaAdminFormularioJugadorState
    extends State<PantallaAdminFormularioJugador> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _dorsalController = TextEditingController();
  final TextEditingController _posicionController = TextEditingController();
  final TextEditingController _fotoController = TextEditingController();
  
  final TextEditingController _fechaNacimientoController = TextEditingController();
  String _piernaHabil = 'Derecha';
  final List<String> _opcionesPierna = ['Derecha', 'Izquierda', 'Ambidiestro'];

  // --- NUEVO CAMPO: ROL ---
  String _rol = 'Jugador';
  final List<String> _opcionesRol = ['Jugador', 'DT'];

  // --- VARIABLES PARA EL NUEVO SISTEMA DE SUMA ---
  int _golesActuales = 0;
  int _asistenciasActuales = 0;
  final TextEditingController _nuevosGolesCtrl = TextEditingController();
  final TextEditingController _nuevasAsistenciasCtrl = TextEditingController();

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

  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();
      if (doc.exists) {
        final data = doc.data()!;

        final menu = List.from(data['menu_deportes'] ?? []);
        setState(() {
          _deportesDisponibles = menu
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });

        _actualizarCategoriasSegunDeporte();

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
      orElse: () => {},
    );

    if (deporte.isNotEmpty && deporte.containsKey('categorias')) {
      setState(() {
        _categoriasDisponibles = List<String>.from(deporte['categorias']);
        if (_categoriasDisponibles.isNotEmpty) {
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
      final doc = await FirebaseFirestore.instance
          .collection('jugadores')
          .doc(widget.jugadorId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = data['nombre'] ?? '';
        _apellidoController.text = data['apellido'] ?? '';
        _dorsalController.text = data['dorsal']?.toString() ?? '0';
        _posicionController.text = data['posicion'] ?? '';
        _fotoController.text = data['foto'] ?? '';
        
        _fechaNacimientoController.text = data['fecha_nacimiento'] ?? '';
        if (data['pierna_habil'] != null && _opcionesPierna.contains(data['pierna_habil'])) {
          _piernaHabil = data['pierna_habil'];
        }
        
        // Cargamos el rol si existe
        if (data['rol'] != null && _opcionesRol.contains(data['rol'])) {
          _rol = data['rol'];
        }

        setState(() {
          _golesActuales = data['goles'] ?? 0;
          _asistenciasActuales = data['asistencias'] ?? 0;

          _categoria = data['categoria'] ?? 'General';
          _deporteSeleccionadoId = data['deporte_id'];
        });

        _actualizarCategoriasSegunDeporte();
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

    int golesPendientes = int.tryParse(_nuevosGolesCtrl.text) ?? 0;
    int asistenciasPendientes = int.tryParse(_nuevasAsistenciasCtrl.text) ?? 0;

    int golesFinales = _golesActuales + golesPendientes;
    int asistenciasFinales = _asistenciasActuales + asistenciasPendientes;

    try {
      final datos = {
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'dorsal': int.tryParse(_dorsalController.text) ?? 0,
        'posicion': _posicionController.text.trim(),
        'fecha_nacimiento': _fechaNacimientoController.text.trim(),
        'pierna_habil': _piernaHabil,
        'goles': _rol == 'DT' ? 0 : golesFinales, // Si es DT, no guardamos goles
        'asistencias': _rol == 'DT' ? 0 : asistenciasFinales,
        'foto': _fotoController.text.trim(),
        'categoria': _categoria,
        'deporte_id': _deporteSeleccionadoId,
        'rol': _rol,
        'nombre_busqueda': _apellidoController.text.trim().toLowerCase(), 
      };

      if (widget.jugadorId == null) {
        await FirebaseFirestore.instance.collection('jugadores').add(datos);
      } else {
        await FirebaseFirestore.instance
            .collection('jugadores')
            .doc(widget.jugadorId)
            .update(datos);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al guardar")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _buildCajaSuma(
    String titulo,
    int actuales,
    TextEditingController nuevosCtrl,
    VoidCallback onSumar,
    VoidCallback onRestar,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text("Actuales", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 5),
                    Container(
                      height: 45,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        actuales.toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("+", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text("Últimos", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 45,
                      child: TextField(
                        controller: nuevosCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                          hintText: "0",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  InkWell(
                    onTap: onSumar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: onRestar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
                      child: const Icon(Icons.remove, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.jugadorId == null ? "Nuevo Registro" : "Editar Registro",
        ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selectores de Categoría
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

                    // Rol y Posición
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _rol,
                            decoration: const InputDecoration(labelText: "Rol", border: OutlineInputBorder()),
                            items: _opcionesRol.map((r) {
                              return DropdownMenuItem<String>(value: r, child: Text(r));
                            }).toList(),
                            onChanged: (val) => setState(() => _rol = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _posicionController,
                            decoration: const InputDecoration(labelText: "Posición / Función", border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // Nacimiento
                    TextFormField(
                      controller: _fechaNacimientoController,
                      decoration: const InputDecoration(labelText: "Nacimiento (ej: 15/04/1990)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),

                    // --- SECCIÓN EXCLUSIVA PARA JUGADORES ---
                    if (_rol == 'Jugador') ...[
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
                            child: DropdownButtonFormField<String>(
                              value: _piernaHabil,
                              decoration: const InputDecoration(labelText: "Pierna Hábil", border: OutlineInputBorder()),
                              items: _opcionesPierna.map((p) {
                                return DropdownMenuItem<String>(value: p, child: Text(p));
                              }).toList(),
                              onChanged: (val) => setState(() => _piernaHabil = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      const Text("ESTADÍSTICAS DEL JUGADOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),

                      _buildCajaSuma(
                        "⚽ Goles",
                        _golesActuales,
                        _nuevosGolesCtrl,
                        () {
                          int sumar = int.tryParse(_nuevosGolesCtrl.text) ?? 0;
                          if (sumar > 0) {
                            setState(() {
                              _golesActuales += sumar;
                              _nuevosGolesCtrl.clear();
                            });
                          }
                        },
                        () {
                          int restar = int.tryParse(_nuevosGolesCtrl.text) ?? 0;
                          if (restar > 0) {
                            setState(() {
                              _golesActuales -= restar;
                              if (_golesActuales < 0) _golesActuales = 0;
                              _nuevosGolesCtrl.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),

                      _buildCajaSuma(
                        "👟 Asistencias",
                        _asistenciasActuales,
                        _nuevasAsistenciasCtrl,
                        () {
                          int sumar = int.tryParse(_nuevasAsistenciasCtrl.text) ?? 0;
                          if (sumar > 0) {
                            setState(() {
                              _asistenciasActuales += sumar;
                              _nuevasAsistenciasCtrl.clear();
                            });
                          }
                        },
                        () {
                          int restar = int.tryParse(_nuevasAsistenciasCtrl.text) ?? 0;
                          if (restar > 0) {
                            setState(() {
                              _asistenciasActuales -= restar;
                              if (_asistenciasActuales < 0) _asistenciasActuales = 0;
                              _nuevasAsistenciasCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 25),

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
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _guardarJugador,
                      child: const Text("GUARDAR DATOS"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}