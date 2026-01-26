import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminGestionNumeros extends StatefulWidget {
  final ConfiguracionApp config;
  final String sorteoId;
  final String tituloSorteo;
  final int cantidadNumeros;

  const PantallaAdminGestionNumeros({
    super.key,
    required this.config,
    required this.sorteoId,
    required this.tituloSorteo,
    required this.cantidadNumeros,
  });

  @override
  State<PantallaAdminGestionNumeros> createState() => _PantallaAdminGestionNumerosState();
}

class _PantallaAdminGestionNumerosState extends State<PantallaAdminGestionNumeros> {
  // Usamos un MAPA: Clave = Número (String), Valor = Nombre Comprador
  Map<String, String> _compradores = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).get();
      if (doc.exists) {
        final data = doc.data()!;

        // RECUPERAMOS LOS COMPRADORES
        // Si ya existía la estructura vieja (lista), la convertimos visualmente o usamos el mapa nuevo
        if (data.containsKey('compradores')) {
          Map<String, dynamic> rawMap = data['compradores'];
          setState(() {
            _compradores = rawMap.map((key, value) => MapEntry(key, value.toString()));
            _cargando = false;
          });
        } else if (data.containsKey('numeros_vendidos')) {
          // Migración visual rápida para datos viejos sin nombre
          List<dynamic> listaVieja = data['numeros_vendidos'];
          for (var num in listaVieja) {
            _compradores[num.toString()] = "Anónimo";
          }
          setState(() => _cargando = false);
        } else {
          setState(() => _cargando = false);
        }
      }
    } catch (e) {
      print("Error cargando números: $e");
      setState(() => _cargando = false);
    }
  }

  // AL TOCAR UN NÚMERO
  void _gestionarNumero(int numero) {
    String key = numero.toString();
    bool estaVendido = _compradores.containsKey(key);

    if (estaVendido) {
      // SI ESTÁ VENDIDO: MOSTRAR INFO Y OPCIÓN DE BORRAR
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Número $numero"),
          content: Text("Comprador: ${_compradores[key]}"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar")),
            TextButton(
              onPressed: () {
                setState(() {
                  _compradores.remove(key);
                });
                Navigator.pop(ctx);
              },
              child: const Text("Liberar Número", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      // SI ESTÁ LIBRE: PEDIR NOMBRE
      TextEditingController nombreController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Vender Número $numero"),
          content: TextField(
            controller: nombreController,
            decoration: const InputDecoration(labelText: "Nombre del Comprador", hintText: "Ej: Familia Gomez"),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (nombreController.text.isNotEmpty) {
                  setState(() {
                    _compradores[key] = nombreController.text.trim();
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Marcar Vendido"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _guardando = true);
    try {
      // Guardamos DOS cosas:
      // 1. El mapa con nombres (para saber quién compró)
      // 2. La lista simple de números (para mantener compatibilidad con otras pantallas y búsquedas rápidas)

      List<int> listaNumeros = _compradores.keys.map((k) => int.parse(k)).toList();
      listaNumeros.sort();

      await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).update({
        'compradores': _compradores,
        'numeros_vendidos': listaNumeros, // Mantenemos la lista sincronizada
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cambios guardados correctamente")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Control de Números", style: TextStyle(fontSize: 16)),
            Text(widget.tituloSorteo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          _guardando
              ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white))
              : IconButton(icon: const Icon(Icons.save), onPressed: _guardarCambios)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _referencia(Colors.green[100]!, Colors.green, "Libre"),
                const SizedBox(width: 20),
                _referencia(Colors.red, Colors.red[900]!, "Vendido"),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: widget.cantidadNumeros,
              itemBuilder: (context, index) {
                final numero = index;
                final key = numero.toString();
                final estaVendido = _compradores.containsKey(key);
                final numeroFormateado = numero.toString().padLeft(widget.cantidadNumeros > 100 ? 3 : 2, '0');

                return InkWell(
                  onTap: () => _gestionarNumero(numero), // <--- NUEVA LÓGICA
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: estaVendido ? Colors.red : Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: estaVendido ? Colors.red[900]! : Colors.green,
                          width: 2
                      ),
                    ),
                    child: Center(
                      child: Text(
                        numeroFormateado,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: estaVendido ? Colors.white : Colors.green[900],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _referencia(Color fondo, Color borde, String texto) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(4), border: Border.all(color: borde, width: 2)),
        ),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}