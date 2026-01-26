import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminRealizarSorteo extends StatefulWidget {
  final ConfiguracionApp config;
  final String sorteoId;
  final String tituloSorteo;
  final int cantidadNumeros;

  const PantallaAdminRealizarSorteo({
    super.key,
    required this.config,
    required this.sorteoId,
    required this.tituloSorteo,
    required this.cantidadNumeros,
  });

  @override
  State<PantallaAdminRealizarSorteo> createState() => _PantallaAdminRealizarSorteoState();
}

class _PantallaAdminRealizarSorteoState extends State<PantallaAdminRealizarSorteo> {
  // ESTADO DEL SORTEO
  int _numeroActualVisual = 0;
  bool _sorteando = false;
  Timer? _timer;

  // PREMIOS GUARDADOS
  List<Map<String, dynamic>> _ganadores = [];
  Map<String, String> _compradoresData = {}; // Para saber el nombre del ganador

  @override
  void initState() {
    super.initState();
    _cargarGanadoresPrevios();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarGanadoresPrevios() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).get();
      if (doc.exists) {
        final data = doc.data()!;

        // Cargamos nombres de compradores (VENDIDOS)
        if (data.containsKey('compradores')) {
          Map<String, dynamic> raw = data['compradores'];
          setState(() {
            _compradoresData = raw.map((k, v) => MapEntry(k, v.toString()));
          });
        }

        // Cargamos premios ya sorteados
        if (data.containsKey('ganadores_lista')) {
          setState(() {
            _ganadores = List<Map<String, dynamic>>.from(data['ganadores_lista']);
          });
        }
      }
    } catch (e) {
      print("Error cargando ganadores: $e");
    }
  }

  // LÓGICA DE ANIMACIÓN
  void _iniciarSorteo() {
    // 1. VALIDACIÓN ANTES DE GIRAR
    if (_compradoresData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ No hay números vendidos. ¡Vendé algunos antes de sortear!"))
      );
      return;
    }

    setState(() => _sorteando = true);

    // Timer para efecto visual (aquí sí mostramos cualquier número para "suspenso")
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _numeroActualVisual = Random().nextInt(widget.cantidadNumeros);
      });
    });
  }

  // LÓGICA DE SELECCIÓN (CORREGIDA)
  void _detenerSorteo() {
    _timer?.cancel();

    // 2. ELEGIR GANADOR SOLO ENTRE LOS VENDIDOS
    // Convertimos las claves del mapa (que son los números vendidos) en una lista
    List<String> listaVendidos = _compradoresData.keys.toList();

    if (listaVendidos.isEmpty) {
      // Por seguridad doble, aunque ya validamos al iniciar
      setState(() => _sorteando = false);
      return;
    }

    final random = Random();
    // Elegimos un índice al azar DE LA LISTA DE VENDIDOS
    int indiceGanador = random.nextInt(listaVendidos.length);

    // Obtenemos el número real
    int ganador = int.parse(listaVendidos[indiceGanador]);

    setState(() {
      _numeroActualVisual = ganador;
      _sorteando = false;
    });

    _mostrarDialogoGanador(ganador);
  }

  void _mostrarDialogoGanador(int numeroGanador) {
    String nombreGanador = _compradoresData[numeroGanador.toString()] ?? "Desconocido";
    TextEditingController premioController = TextEditingController(text: "${_ganadores.length + 1}° Premio");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("🎉 ¡TENEMOS GANADOR! 🎉", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numeroGanador.toString().padLeft(widget.cantidadNumeros > 100 ? 3 : 2, '0'),
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            Text("Pertenece a: $nombreGanador", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: premioController,
              decoration: const InputDecoration(labelText: "Nombre del Premio", hintText: "Ej: TV 50'"),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Cancelar
              Navigator.pop(ctx);
            },
            child: const Text("Descartar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.config.colorPrimario, foregroundColor: Colors.white),
            onPressed: () {
              _guardarGanador(numeroGanador, nombreGanador, premioController.text);
              Navigator.pop(ctx);
            },
            child: const Text("CONFIRMAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarGanador(int numero, String nombre, String premio) async {
    final nuevoGanador = {
      'numero': numero,
      'nombre': nombre,
      'premio': premio,
      'fecha': Timestamp.now(),
    };

    setState(() {
      _ganadores.add(nuevoGanador);
    });

    // Guardar en Firebase
    await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).update({
      'ganadores_lista': _ganadores,
    });
  }

  @override
  Widget build(BuildContext context) {
    String numeroStr = _numeroActualVisual.toString().padLeft(widget.cantidadNumeros > 100 ? 3 : 2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sala de Sorteo"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ZONA DE BOLILLERO
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("SORTEO EN CURSO", style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0,5))],
                      border: Border.all(color: widget.config.colorPrimario, width: 3),
                    ),
                    child: Text(
                      numeroStr,
                      style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: _sorteando ? Colors.grey : Colors.black,
                          fontFamily: 'monospace'
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // BOTÓN DE ACCIÓN
                  SizedBox(
                    width: 200,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _sorteando ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sorteando ? _detenerSorteo : _iniciarSorteo,
                      child: Text(
                        _sorteando ? "DETENER" : "GIRAR BOLILLERO",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          const Divider(thickness: 2),

          // LISTA DE GANADORES
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("GANADORES REGISTRADOS", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: _ganadores.isEmpty
                        ? const Center(child: Text("Aún no hay ganadores.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                      itemCount: _ganadores.length,
                      itemBuilder: (context, index) {
                        final g = _ganadores[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Text("${g['numero']}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                          title: Text("Premio: ${g['premio']}"),
                          subtitle: Text("Ganador: ${g['nombre']}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () async {
                              setState(() => _ganadores.removeAt(index));
                              await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).update({'ganadores_lista': _ganadores});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}