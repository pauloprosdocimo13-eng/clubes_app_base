import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminPrecios extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminPrecios({super.key, required this.config});

  @override
  State<PantallaAdminPrecios> createState() => _PantallaAdminPreciosState();
}

class _PantallaAdminPreciosState extends State<PantallaAdminPrecios> {
  Map<String, dynamic> _precios = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPrecios();
  }

  // Carga inicial desde Firebase
  Future<void> _cargarPrecios() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        setState(() {
          // Buscamos el campo 'precios_cuotas'
          _precios = doc.data()?['precios_cuotas'] ?? {};
          _cargando = false;
        });
      } else {
        // Si no existe, sugerimos valores iniciales para que no esté vacío
        setState(() {
          _precios = {
            'Socio Pleno': 5000,
            'Fútbol': 8500,
            'Patín': 7000,
            'Basket': 8000,
          };
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Guardar cambio (Agregar o Editar)
  Future<void> _guardarCambio(String actividad, double precio) async {
    // 1. Actualizar estado local para feedback inmediato
    setState(() {
      _precios[actividad] = precio;
    });

    // 2. Guardar en Firebase
    try {
      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .set({
            'precios_cuotas': _precios, // Guardamos todo el mapa actualizado
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error guardando: $e")));
    }
  }

  // Borrar actividad
  Future<void> _borrarActividad(String actividad) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("¿Borrar Actividad?"),
            content: Text("Se eliminará '$actividad' de la lista."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  "BORRAR",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() {
      _precios.remove(actividad);
    });

    await FirebaseFirestore.instance
        .collection('configuracion')
        .doc('precios')
        .set({'precios_cuotas': _precios}, SetOptions(merge: true));
  }

  // Diálogo para Agregar/Editar
  void _mostrarDialogoEditar(String actividadInicial, double precioInicial) {
    final nombreCtrl = TextEditingController(text: actividadInicial);
    final precioCtrl = TextEditingController(
      text: precioInicial > 0 ? precioInicial.toStringAsFixed(0) : '',
    );
    bool esNuevo = actividadInicial.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esNuevo ? "Nueva Actividad" : "Editar Precio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esNuevo)
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: "Nombre (ej: Taekwondo)",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            if (!esNuevo)
              Text(
                actividadInicial,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

            const SizedBox(height: 15),
            TextField(
              controller: precioCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Valor Cuota Mensual",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.config.colorPrimario,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              final precio = double.tryParse(precioCtrl.text) ?? 0;

              if (nombre.isNotEmpty && precio > 0) {
                _guardarCambio(nombre, precio);
                Navigator.pop(ctx);
              }
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ordenamos la lista alfabéticamente para mostrarla prolija
    final listaOrdenada = _precios.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Precios"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.config.colorPrimario,
        icon: const Icon(Icons.add),
        label: const Text("NUEVA ACTIVIDAD"),
        onPressed: () => _mostrarDialogoEditar("", 0),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner informativo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  color: Colors.blueGrey[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blueGrey[800]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Estas actividades aparecerán automáticamente en el alta de socios y se usarán para calcular el total a pagar.",
                          style: TextStyle(
                            color: Colors.blueGrey[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(15),
                    itemCount: listaOrdenada.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = listaOrdenada[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                "\$${(entry.value as num).toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _mostrarDialogoEditar(
                                entry.key,
                                (entry.value as num).toDouble(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _borrarActividad(entry.key),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 80), // Espacio para el FAB
              ],
            ),
    );
  }
}
