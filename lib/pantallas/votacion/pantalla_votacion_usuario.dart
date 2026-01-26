import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaVotacionUsuario extends StatelessWidget {
  final ConfiguracionApp config;
  const PantallaVotacionUsuario({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Votación de Figuras"),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('votaciones')
            .where('estado', isEqualTo: 'ABIERTA') // Solo las activas
            .orderBy('creada_el', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_vote, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text("No hay votaciones activas.", style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber,
                    radius: 25,
                    child: const Icon(Icons.star, color: Colors.white),
                  ),
                  title: Text(data['titulo'] ?? 'Votación', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Categoría: ${data['categoria'] ?? 'General'}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _PantallaVotarDetalle(
                          config: config,
                          votacionId: id,
                          titulo: data['titulo'] ?? 'Votación',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- PANTALLA INTERNA: DETALLE Y ACCIÓN DE VOTAR ---
class _PantallaVotarDetalle extends StatefulWidget {
  final ConfiguracionApp config;
  final String votacionId;
  final String titulo;

  const _PantallaVotarDetalle({required this.config, required this.votacionId, required this.titulo});

  @override
  State<_PantallaVotarDetalle> createState() => _PantallaVotarDetalleState();
}

class _PantallaVotarDetalleState extends State<_PantallaVotarDetalle> {
  bool _yaVoto = false;

  @override
  void initState() {
    super.initState();
    _chequearVotoLocal();
  }

  // Revisamos si ya existe la marca en el celular
  Future<void> _chequearVotoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final votoGuardado = prefs.getBool('voto_emitido_${widget.votacionId}') ?? false;
    if (mounted) setState(() => _yaVoto = votoGuardado);
  }

  Future<void> _votar(Map<String, dynamic> candidato, List<dynamic> listaCompleta) async {
    if (_yaVoto) return;

    // 1. Actualización visual optimista (para que se sienta rápido)
    int index = listaCompleta.indexOf(candidato);
    if (index == -1) return;

    Map<String, dynamic> candidatoModificado = Map.from(candidato);
    candidatoModificado['votos'] = (candidatoModificado['votos'] ?? 0) + 1;
    listaCompleta[index] = candidatoModificado;

    try {
      // 2. Guardar en Firebase
      await FirebaseFirestore.instance.collection('votaciones').doc(widget.votacionId).update({
        'candidatos': listaCompleta,
        'total_votos': FieldValue.increment(1)
      });

      // 3. Guardar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voto_emitido_${widget.votacionId}', true);

      setState(() => _yaVoto = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("¡Voto registrado para ${candidato['nombre']}!"), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al registrar el voto.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo), backgroundColor: widget.config.colorPrimario),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('votaciones').doc(widget.votacionId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List candidatos = List.from(data['candidatos'] ?? []);
          final int totalVotos = data['total_votos'] ?? 0;

          // Si ya votó, ordenamos por ranking (más votos arriba)
          if (_yaVoto) {
            candidatos.sort((a, b) => (b['votos'] ?? 0).compareTo(a['votos'] ?? 0));
          }

          return Column(
            children: [
              // Cabecera informativa
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                color: Colors.grey[100],
                child: Center(
                  child: Text(
                    _yaVoto
                        ? "Resultados en Vivo ($totalVotos votos)"
                        : "Tocá al jugador para elegirlo como FIGURA",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _yaVoto ? widget.config.colorPrimario : Colors.grey[700]
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: candidatos.length,
                  itemBuilder: (context, index) {
                    final c = candidatos[index];
                    final int votos = c['votos'] ?? 0;
                    final double porcentaje = totalVotos > 0 ? (votos / totalVotos) : 0.0;
                    final String foto = c['foto'] ?? '';

                    return Card(
                      elevation: _yaVoto ? 1 : 4, // Menos sombra si ya votó
                      color: (_yaVoto && index == 0) ? Colors.yellow[50] : Colors.white, // Resaltar líder
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        onTap: _yaVoto ? null : () => _votar(c, candidatos),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // FOTO
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                                    child: foto.isEmpty
                                        ? Text(c['nombre'][0], style: const TextStyle(fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(width: 15),

                                  // DATOS
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (c['dorsal'] != null && c['dorsal'].toString().isNotEmpty)
                                          Text("Camiseta #${c['dorsal']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),

                                  // PORCENTAJE (Solo visible al votar)
                                  if (_yaVoto)
                                    Text(
                                        "${(porcentaje * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.config.colorPrimario)
                                    ),
                                ],
                              ),

                              // BARRA DE PROGRESO
                              if (_yaVoto) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: porcentaje,
                                    color: widget.config.colorPrimario,
                                    backgroundColor: Colors.grey[200],
                                    minHeight: 6,
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}