import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../../configuracion/configuracion_app.dart';

class PantallaProdeUsuario extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaProdeUsuario({super.key, required this.config});

  @override
  State<PantallaProdeUsuario> createState() => _PantallaProdeUsuarioState();
}

class _PantallaProdeUsuarioState extends State<PantallaProdeUsuario> {
  final _nombreController = TextEditingController();
  
  // Variables de Estado
  String? _deviceId; // ID único del celular
  String? _fechaSeleccionadaId; // ID de la fecha activa
  bool _cargando = true;
  bool _enviando = false;

  // Mapa de votos TEMPORALES (lo que toco ahora)
  final Map<String, String> _votosTemp = {};
  
  // Mapa de votos GUARDADOS (si ya voté antes)
  Map<String, dynamic>? _votosGuardados; 
  int _puntosUsuario = 0;

  @override
  void initState() {
    super.initState();
    _inicializarUsuario();
  }

  // 1. Configuración inicial del usuario
  Future<void> _inicializarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generar ID único si no existe (Huella del dispositivo)
    if (!prefs.containsKey('prode_device_id')) {
      String idGenerado = DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString();
      await prefs.setString('prode_device_id', idGenerado); 
    }
    _deviceId = prefs.getString('prode_device_id');
    
    // Autocompletar nombre si ya jugó antes
    if (prefs.containsKey('prode_nombre_usuario')) {
      _nombreController.text = prefs.getString('prode_nombre_usuario')!;
    }

    await _buscarFechaActiva();
  }

  // 2. Buscamos qué fecha se está jugando ahora
  Future<void> _buscarFechaActiva() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('prode_fechas')
          .where('estado', isEqualTo: 'ABIERTA')
          .orderBy('creada_el', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _fechaSeleccionadaId = query.docs.first.id;
        // 3. Chequeamos si este usuario YA votó en esta fecha
        await _verificarVotoExistente();
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      print("Error buscando fecha: $e");
      setState(() => _cargando = false);
    }
  }

  // 3. Verificar si ya votó
  Future<void> _verificarVotoExistente() async {
    if (_fechaSeleccionadaId == null || _deviceId == null) return;

    final votoQuery = await FirebaseFirestore.instance
        .collection('prode_votos')
        .where('fecha_id', isEqualTo: _fechaSeleccionadaId)
        .where('user_id', isEqualTo: _deviceId)
        .limit(1)
        .get();

    if (votoQuery.docs.isNotEmpty) {
      // YA VOTÓ: Recuperamos datos
      final data = votoQuery.docs.first.data();
      setState(() {
        _votosGuardados = data['predicciones'];
        _puntosUsuario = data['puntos'] ?? 0;
        _cargando = false;
      });
    } else {
      // NO VOTÓ
      setState(() {
        _votosGuardados = null;
        _cargando = false;
      });
    }
  }

  // 4. Enviar Voto
  Future<void> _enviarPronostico() async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, ingresá tu nombre.")));
      return;
    }
    if (_votosTemp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes pronosticar al menos un partido.")));
      return;
    }

    setState(() => _enviando = true);

    try {
      // Guardar nombre localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prode_nombre_usuario', nombre);

      await FirebaseFirestore.instance.collection('prode_votos').add({
        'fecha_id': _fechaSeleccionadaId,
        'user_id': _deviceId,
        'nombre_usuario': nombre,
        'predicciones': _votosTemp, 
        'fecha_voto': FieldValue.serverTimestamp(),
        'puntos': 0, // Inicia en 0, se calcula desde Admin
      });

      // Recargar para mostrar estado "Ya votaste"
      await _verificarVotoExistente();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Pronóstico enviado con éxito!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar. Intenta de nuevo.")));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prode del Club"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator())
          : _fechaSeleccionadaId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("No hay fechas activas por el momento.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('prode_fechas').doc(_fechaSeleccionadaId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final dataFecha = snapshot.data!.data() as Map<String, dynamic>;
                    final partidos = List.from(dataFecha['partidos'] ?? []);
                    final titulo = dataFecha['titulo'] ?? 'Fecha Actual';

                    // MODO LECTURA: Si ya votó, mostramos resultados
                    bool modoLectura = _votosGuardados != null;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // HEADER DE ESTADO
                          Text(titulo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.config.colorPrimario), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          
                          if (modoLectura)
                            Container(
                              padding: const EdgeInsets.all(15),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                              child: Column(
                                children: [
                                  const Text("🏆 TU PUNTAJE:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  Text("$_puntosUsuario PUNTOS", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 30)),
                                  const SizedBox(height: 5),
                                  const Text("Ya enviaste tu pronóstico.", style: TextStyle(color: Colors.green, fontSize: 12)),
                                ],
                              ),
                            )
                          else
                            const Text("¡Jugá y ganá! Adiviná los resultados.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          
                          const SizedBox(height: 10),

                          // INPUT NOMBRE (Solo visible si no votó)
                          if (!modoLectura) ...[
                            TextField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                labelText: "Tu Nombre y Apellido",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person)
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // LISTA DE PARTIDOS
                          if (partidos.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No hay partidos cargados en esta fecha.")))
                          else
                            ...partidos.map((p) {
                              String id = p['id'];
                              String cat = p['categoria'];
                              String local = p['local'];
                              String visitante = p['visitante'];
                              String? resultadoReal = p['resultado_real']; // L, E, V (Oficial)

                              // Recuperamos qué votó (si ya jugó) o qué está tocando (si está jugando)
                              String? votoUsuario = modoLectura ? _votosGuardados![id] : _votosTemp[id];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 15),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    children: [
                                      // Etiqueta Categoría
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                        child: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      // Equipos
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Expanded(child: Text(local, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          const Text(" VS ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                          Expanded(child: Text(visitante, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      
                                      // BOTONES DE OPCIÓN (L - E - V)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _BotonOpcion(
                                            txt: "LOCAL", val: "L", 
                                            voto: votoUsuario, real: resultadoReal, active: !modoLectura, 
                                            onTap: () => setState(() => _votosTemp[id] = "L")
                                          ),
                                          const SizedBox(width: 5),
                                          _BotonOpcion(
                                            txt: "EMPATE", val: "E", 
                                            voto: votoUsuario, real: resultadoReal, active: !modoLectura,
                                            onTap: () => setState(() => _votosTemp[id] = "E")
                                          ),
                                          const SizedBox(width: 5),
                                          _BotonOpcion(
                                            txt: "VISITA", val: "V", 
                                            voto: votoUsuario, real: resultadoReal, active: !modoLectura,
                                            onTap: () => setState(() => _votosTemp[id] = "V")
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                          const SizedBox(height: 20),

                          // BOTÓN ENVIAR
                          if (!modoLectura && partidos.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.config.colorPrimario,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _enviando ? null : _enviarPronostico,
                                child: _enviando
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text("ENVIAR PRONÓSTICO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// WIDGET AUXILIAR INTELIGENTE (COLORES VERDE/ROJO)
class _BotonOpcion extends StatelessWidget {
  final String txt;
  final String val;
  final String? voto;     // Lo que votó el usuario
  final String? real;     // El resultado oficial (si existe)
  final bool active;      // Si se puede votar o no
  final VoidCallback onTap;

  const _BotonOpcion({
    required this.txt, required this.val, 
    required this.voto, required this.real, 
    required this.active, required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // Definimos colores por defecto
    Color colorFondo = Colors.white;
    Color colorBorde = Colors.grey[300]!;
    Color colorTexto = Colors.black;
    IconData? icono;

    bool esLoQueVoto = (voto == val);
    bool esElGanador = (real == val);

    if (active) {
      // --- MODO VOTACIÓN (AZUL) ---
      if (esLoQueVoto) {
        colorFondo = Colors.blue;
        colorTexto = Colors.white;
        colorBorde = Colors.blue;
      }
    } else {
      // --- MODO RESULTADO (VERDE/ROJO) ---
      if (esElGanador) {
        // Esta opción era la correcta: SIEMPRE VERDE
        colorFondo = Colors.green;
        colorTexto = Colors.white;
        colorBorde = Colors.green;
        if (esLoQueVoto) icono = Icons.check; // Y encima la votaste!
      } else if (esLoQueVoto) {
        // Votaste esto pero NO era la correcta: ROJO
        colorFondo = Colors.red;
        colorTexto = Colors.white;
        colorBorde = Colors.red;
        icono = Icons.close;
      } else if (esLoQueVoto && real == null) {
        // Votaste esto pero aun no se jugó: AZUL
        colorFondo = Colors.blue;
        colorTexto = Colors.white;
        colorBorde = Colors.blue;
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: colorBorde),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[
                Icon(icono, color: Colors.white, size: 16), 
                const SizedBox(width: 4)
              ],
              Text(
                txt, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: colorTexto, 
                  fontSize: 12
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}