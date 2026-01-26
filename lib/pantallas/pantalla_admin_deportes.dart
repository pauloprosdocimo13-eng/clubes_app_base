import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminDeportes extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminDeportes({super.key, required this.config});

  @override
  State<PantallaAdminDeportes> createState() => _PantallaAdminDeportesState();
}

class _PantallaAdminDeportesState extends State<PantallaAdminDeportes> {
  final _tituloController = TextEditingController();
  final _idController = TextEditingController();
  final _categoriasManualController = TextEditingController();

  String _plantillaSeleccionada = 'baby_fefi';
  bool _mostrarManual = false;
  bool _cargando = false;
  List<dynamic> _deportes = [];

  // DEFINICIÓN DE PLANTILLAS
  final Map<String, Map<String, dynamic>> _plantillas = {
    'baby_fefi': {
      'label': 'Baby Fútbol (FEFI)',
      'tipo': 'competencia',
      'categorias': ['2013', '2014', '2015', '2016', '2017', '2018', '2019']
    },
    'futsal': {
      'label': 'Futsal (Inferiores y Primera)',
      'tipo': 'competencia',
      'categorias': ['Primera', '3ra', '4ta', '5ta']
    },
    'veteranos': {
      'label': 'Veteranos / Senior',
      'tipo': 'competencia',
      'categorias': ['Senior +35', 'Master +42']
    },
    'femenino_std': {
      'label': 'Femenino (Estándar)',
      'tipo': 'competencia',
      'categorias': ['Primera', 'Reserva'] 
    },
    'actividad': {
      'label': 'Actividad (Patín/Danza)',
      'tipo': 'actividad',
      'categorias': ['General', 'Infantil', 'Juvenil', 'Adultos', 'Competencia']
    },
    'personalizado': {
      'label': 'Personalizado (Escribir a mano)',
      'tipo': 'competencia',
      'categorias': []
    }
  };

  @override
  void initState() {
    super.initState();
    _cargarDeportes();
  }

  Future<void> _cargarDeportes() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists && doc.data()!.containsKey('menu_deportes')) {
        setState(() {
          _deportes = List.from(doc.data()!['menu_deportes']);
        });
      }
    } catch (e) {
      print("Error cargando deportes: $e");
    }
  }

  void _mostrarDialogo({Map<String, dynamic>? deporteEditar, int? indexEditar}) {
    bool esEdicion = deporteEditar != null;

    if (esEdicion) {
      _tituloController.text = deporteEditar['titulo'];
      _idController.text = deporteEditar['id'];
      
      _plantillaSeleccionada = 'personalizado';
      List cats = deporteEditar['categorias'] ?? [];
      _categoriasManualController.text = cats.join(', ');
      _mostrarManual = true;

    } else {
      _tituloController.clear();
      _idController.clear();
      _plantillaSeleccionada = 'baby_fefi';
      _mostrarManual = false;
      _categoriasManualController.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(esEdicion ? "Editar Tira/Actividad" : "Nueva Tira/Actividad"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: "Título (ej: Baby Letra A)", 
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (!esEdicion) {
                          setStateDialog(() {
                            _idController.text = val.toLowerCase().replaceAll(' ', '_').replaceAll('ñ', 'n');
                          });
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _idController,
                    readOnly: esEdicion, 
                    decoration: InputDecoration(
                      labelText: "ID Interno", 
                      border: const OutlineInputBorder(),
                      filled: esEdicion,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text("Formato de Categorías:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _plantillaSeleccionada,
                        isExpanded: true,
                        items: _plantillas.entries.map((entry) {
                          return DropdownMenuItem(value: entry.key, child: Text(entry.value['label']));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() {
                              _plantillaSeleccionada = val;
                              _mostrarManual = (val == 'personalizado');
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  if (_mostrarManual) ...[
                    const SizedBox(height: 15),
                    const Text("Escribe las categorías separadas por coma:", style: TextStyle(fontSize: 12, color: Colors.blue)),
                    TextField(
                      controller: _categoriasManualController,
                      maxLines: 2,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Ej: Primera, Reserva, Sub-20"),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Se crearán estas categorías:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text(
                            (_plantillas[_plantillaSeleccionada]!['categorias'] as List).join(', '),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () {
                  if (_tituloController.text.isNotEmpty && _idController.text.isNotEmpty) {
                    _guardarDeporte(esEdicion ? indexEditar : null);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("GUARDAR"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _guardarDeporte(int? indexEditar) async {
    setState(() => _cargando = true);
    
    List<String> categoriasFinales = [];
    String tipoFinal = 'competencia';

    if (_plantillaSeleccionada == 'personalizado') {
      final texto = _categoriasManualController.text;
      if (texto.isNotEmpty) {
        categoriasFinales = texto.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } else {
      final plantilla = _plantillas[_plantillaSeleccionada]!;
      categoriasFinales = List<String>.from(plantilla['categorias']);
      tipoFinal = plantilla['tipo'];
    }

    final nuevoDeporte = {
      'id': _idController.text.trim(),
      'titulo': _tituloController.text.trim(),
      'tipo': tipoFinal,
      'categorias': categoriasFinales,
    };

    List<dynamic> nuevaLista = List.from(_deportes);

    if (indexEditar != null) {
      if (_plantillaSeleccionada == 'personalizado') {
         nuevoDeporte['tipo'] = _deportes[indexEditar]['tipo']; 
      }
      nuevaLista[indexEditar] = nuevoDeporte;
    } else {
      nuevaLista.add(nuevoDeporte);
    }

    try {
      await FirebaseFirestore.instance.collection('configuracion').doc('general').update({
        'menu_deportes': nuevaLista
      });
      await _cargarDeportes(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Guardado: ${_tituloController.text}"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  // --- LÓGICA DE BORRADO SEGURA ---
  Future<void> _borrarDeporte(int index) async {
    setState(() => _cargando = true);
    
    final deporte = _deportes[index];
    final String idDeporte = deporte['id'];
    final String titulo = deporte['titulo'];

    try {
      // 1. VERIFICAR INTEGRIDAD REFERENCIAL
      // Contamos cuántos jugadores hay asociados a este deporte
      final queryJugadores = await FirebaseFirestore.instance
          .collection('jugadores')
          .where('deporte_id', isEqualTo: idDeporte)
          .count()
          .get();

      // Contamos cuántos partidos hay asociados
      final queryPartidos = await FirebaseFirestore.instance
          .collection('partidos')
          .where('deporte_id', isEqualTo: idDeporte)
          .count()
          .get();

      final int cantJugadores = queryJugadores.count ?? 0;
      final int cantPartidos = queryPartidos.count ?? 0;

      setState(() => _cargando = false); // Dejamos de cargar para mostrar el diálogo

      if (cantJugadores > 0 || cantPartidos > 0) {
        // --- BLOQUEAMOS EL BORRADO ---
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("⚠️ No se puede eliminar"),
            content: Text(
              "La tira '$titulo' contiene datos activos:\n\n"
              "• $cantJugadores Jugadores\n"
              "• $cantPartidos Partidos\n\n"
              "Por seguridad, debes eliminar primero los jugadores y partidos asociados, o moverlos a otra tira antes de eliminar esta sección."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("ENTENDIDO")
              ),
            ],
          ),
        );
        return; // Salimos sin borrar
      }

      // 2. SI ESTÁ VACÍA, PEDIMOS CONFIRMACIÓN FINAL
      if (!mounted) return;
      final confirm = await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar Tira Vacía?"),
          content: Text("Se eliminará '$titulo' del menú. Como no tiene datos asociados, es seguro continuar."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
          ],
        )
      );

      if (confirm == true) {
        setState(() => _cargando = true);
        List<dynamic> nuevaLista = List.from(_deportes);
        nuevaLista.removeAt(index);
        
        await FirebaseFirestore.instance.collection('configuracion').doc('general').update({
          'menu_deportes': nuevaLista
        });
        await _cargarDeportes();
        setState(() => _cargando = false);
      }

    } catch (e) {
      print(e);
      setState(() => _cargando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al verificar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Tiras y Actividades"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("Nueva Tira"),
        icon: const Icon(Icons.add),
        backgroundColor: widget.config.colorPrimario,
        onPressed: () => _mostrarDialogo(),
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _deportes.length,
            itemBuilder: (context, index) {
              final d = _deportes[index];
              final String tipo = d['tipo'] ?? 'competencia'; 
              final List cats = d['categorias'] ?? [];
              
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: tipo == 'competencia' ? Colors.green[100] : Colors.purple[100],
                    child: Icon(
                      tipo == 'competencia' ? Icons.sports_soccer : Icons.sports_gymnastics,
                      color: tipo == 'competencia' ? Colors.green[800] : Colors.purple[800],
                    ),
                  ),
                  title: Text(d['titulo'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("ID: ${d['id']} • Tipo: ${tipo.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("Categorías (${cats.length}): ${cats.join(', ')}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _mostrarDialogo(deporteEditar: d, indexEditar: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarDeporte(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}