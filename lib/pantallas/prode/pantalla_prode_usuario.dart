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

  String? _deviceId;
  String? _fechaSeleccionadaId;
  bool _cargando = true;
  bool _enviando = false;

  final Map<String, Map<String, int>> _votosTemp = {};
  Map<String, dynamic>? _votosGuardados;
  int _puntosUsuario = 0;

  @override
  void initState() {
    super.initState();
    _inicializarUsuario();
  }

  Future<void> _inicializarUsuario() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('prode_device_id')) {
      String idGenerado =
          DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(999).toString();
      await prefs.setString('prode_device_id', idGenerado);
    }
    _deviceId = prefs.getString('prode_device_id');

    if (prefs.containsKey('prode_nombre_usuario')) {
      _nombreController.text = prefs.getString('prode_nombre_usuario')!;
    }

    await _buscarFechaActiva();
  }

  Future<void> _buscarFechaActiva() async {
    try {
      // MODIFICACIÓN: Ya no filtramos solo por 'ABIERTA'.
      // Traemos la última siempre, para que puedan ver los puntos el finde.
      final query = await FirebaseFirestore.instance
          .collection('prode_fechas')
          .orderBy('creada_el', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _fechaSeleccionadaId = query.docs.first.id;
        await _verificarVotoExistente();
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      print("Error buscando fecha: $e");
      setState(() => _cargando = false);
    }
  }

  Future<void> _verificarVotoExistente() async {
    if (_fechaSeleccionadaId == null || _deviceId == null) return;

    final votoQuery = await FirebaseFirestore.instance
        .collection('prode_votos')
        .where('fecha_id', isEqualTo: _fechaSeleccionadaId)
        .where('user_id', isEqualTo: _deviceId)
        .limit(1)
        .get();

    if (votoQuery.docs.isNotEmpty) {
      final data = votoQuery.docs.first.data();
      setState(() {
        _votosGuardados = data['predicciones'];
        _puntosUsuario = data['puntos'] ?? 0;
        _cargando = false;
      });
    } else {
      setState(() {
        _votosGuardados = null;
        _cargando = false;
      });
    }
  }

  Future<void> _enviarPronostico(int cantidadPartidos) async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, ingresá tu nombre y apellido."),
        ),
      );
      return;
    }
    if (_votosTemp.length < cantidadPartidos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aún te faltan partidos por pronosticar."),
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prode_nombre_usuario', nombre);

      await FirebaseFirestore.instance.collection('prode_votos').add({
        'fecha_id': _fechaSeleccionadaId,
        'user_id': _deviceId,
        'nombre_usuario': nombre,
        'predicciones': _votosTemp,
        'fecha_voto': FieldValue.serverTimestamp(),
        'puntos': 0,
      });

      await _verificarVotoExistente();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Pronóstico de goles enviado con éxito!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al enviar. Revisa tu conexión.")),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prode de Goles"),
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
                  const Text(
                    "No hay fechas activas por el momento.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('prode_fechas')
                  .doc(_fechaSeleccionadaId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final dataFecha = snapshot.data!.data() as Map<String, dynamic>;
                final partidos = List.from(dataFecha['partidos'] ?? []);
                partidos.sort(
                  (a, b) => a['categoria'].compareTo(b['categoria']),
                );
                final titulo = dataFecha['titulo'] ?? 'Fecha Actual';

                // --- LA MAGIA DEL BLOQUEO ESTÁ ACÁ ---
                bool prodeCerrado = dataFecha['bloqueado'] ?? false;
                // Entra en lectura si ya votó O si cerraste el prode desde el admin
                bool modoLectura = _votosGuardados != null || prodeCerrado;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: widget.config.colorPrimario,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // --- PANELES SUPERIORES DINÁMICOS ---
                      if (_votosGuardados != null)
                        Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "🏆 TU PUNTAJE:",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "$_puntosUsuario PUNTOS",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "Acierto Exacto = 3 pts | Acierto Ganador = 1 pt",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (prodeCerrado)
                        Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: Colors.red,
                                size: 30,
                              ),
                              SizedBox(height: 5),
                              Text(
                                "PRODE CERRADO",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                "Ya no se pueden ingresar pronósticos.\n¡Suerte a los que participaron!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            "Completá los goles de cada partido.\n¡El resultado exacto suma más puntos!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),

                      // INPUT NOMBRE (Solo visible si no está en modo lectura)
                      if (!modoLectura) ...[
                        TextField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: "Tu Nombre y Apellido",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // LISTA DE PARTIDOS CON INPUT DE GOLES
                      if (partidos.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text("No hay partidos en esta fecha."),
                          ),
                        )
                      else
                        ...partidos.map((p) {
                          String id = p['id'];
                          String cat = p['categoria'];
                          String local = p['local'];
                          String visitante = p['visitante'];

                          int? glReal = p['goles_local_real'];
                          int? gvReal = p['goles_visitante_real'];

                          int? glUsuario;
                          int? gvUsuario;

                          if (_votosGuardados != null) {
                            if (_votosGuardados![id] != null) {
                              glUsuario = _votosGuardados![id]['gl'];
                              gvUsuario = _votosGuardados![id]['gv'];
                            }
                          } else {
                            if (_votosTemp[id] != null) {
                              glUsuario = _votosTemp[id]!['gl'];
                              gvUsuario = _votosTemp[id]!['gv'];
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 15),
                            elevation: modoLectura ? 1 : 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cat,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),

                                  _IngresoGolesWidget(
                                    idPartido: id,
                                    local: local,
                                    visitante: visitante,
                                    glUsuario: glUsuario,
                                    gvUsuario: gvUsuario,
                                    glReal: glReal,
                                    gvReal: gvReal,
                                    modoLectura: modoLectura,
                                    onGolesCambiados: (gl, gv) {
                                      setState(() {
                                        _votosTemp[id] = {'gl': gl, 'gv': gv};
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),

                      const SizedBox(height: 20),

                      // BOTÓN ENVIAR (Desaparece si se bloquea el prode)
                      if (!modoLectura && partidos.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.config.colorPrimario,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _enviando
                                ? null
                                : () => _enviarPronostico(partidos.length),
                            child: _enviando
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "ENVIAR PRONÓSTICO",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

class _IngresoGolesWidget extends StatelessWidget {
  final String idPartido;
  final String local;
  final String visitante;
  final int? glUsuario;
  final int? gvUsuario;
  final int? glReal;
  final int? gvReal;
  final bool modoLectura;
  final Function(int, int) onGolesCambiados;

  const _IngresoGolesWidget({
    required this.idPartido,
    required this.local,
    required this.visitante,
    required this.glUsuario,
    required this.gvUsuario,
    required this.glReal,
    required this.gvReal,
    required this.modoLectura,
    required this.onGolesCambiados,
  });

  @override
  Widget build(BuildContext context) {
    bool partidoFinalizado = (glReal != null && gvReal != null);

    Color colorFondoLocal = Colors.white;
    Color colorFondoVisitante = Colors.white;
    String cartelAcierto = "";

    if (modoLectura &&
        partidoFinalizado &&
        glUsuario != null &&
        gvUsuario != null) {
      if (glReal == glUsuario && gvReal == gvUsuario) {
        colorFondoLocal = colorFondoVisitante = Colors.green[100]!;
        cartelAcierto = "¡+3 PTS! Resultado Exacto";
      } else {
        bool realLocalGana = glReal! > gvReal!;
        bool usuLocalGana = glUsuario! > gvUsuario!;
        bool realVisGana = gvReal! > glReal!;
        bool usuVisGana = gvUsuario! > glUsuario!;
        bool realEmpate = glReal == gvReal;
        bool usuEmpate = glUsuario == gvUsuario;

        if ((realLocalGana && usuLocalGana) ||
            (realVisGana && usuVisGana) ||
            (realEmpate && usuEmpate)) {
          colorFondoLocal = colorFondoVisitante = Colors.blue[50]!;
          cartelAcierto = "¡+1 PT! Acierto Ganador";
        } else {
          colorFondoLocal = colorFondoVisitante = Colors.red[50]!;
          cartelAcierto = "0 Pts. Incorrecto";
        }
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                local,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),

            SizedBox(
              width: 45,
              height: 45,
              child: TextFormField(
                readOnly: modoLectura,
                initialValue: glUsuario?.toString() ?? '',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: modoLectura ? colorFondoLocal : Colors.grey[100],
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  int gl = int.tryParse(val) ?? 0;
                  int gv = gvUsuario ?? 0;
                  onGolesCambiados(gl, gv);
                },
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "-",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.grey,
                ),
              ),
            ),

            SizedBox(
              width: 45,
              height: 45,
              child: TextFormField(
                readOnly: modoLectura,
                initialValue: gvUsuario?.toString() ?? '',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: modoLectura
                      ? colorFondoVisitante
                      : Colors.grey[100],
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  int gv = int.tryParse(val) ?? 0;
                  int gl = glUsuario ?? 0;
                  onGolesCambiados(gl, gv);
                },
              ),
            ),

            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                visitante,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),

        if (partidoFinalizado && modoLectura && cartelAcierto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              cartelAcierto,
              style: TextStyle(
                color: cartelAcierto.contains('+3')
                    ? Colors.green[700]
                    : (cartelAcierto.contains('+1')
                          ? Colors.blue[700]
                          : Colors.red),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          )
        else if (partidoFinalizado && modoLectura)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Resultado Real: $glReal - $gvReal",
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
