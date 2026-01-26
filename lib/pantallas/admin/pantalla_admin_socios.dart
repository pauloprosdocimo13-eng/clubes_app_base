import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para saber qué admin cobró
import '../../configuracion/configuracion_app.dart';
import 'pantalla_admin_formulario_familia.dart';
import 'pantalla_admin_precios.dart';

class PantallaAdminSocios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminSocios({super.key, required this.config});

  @override
  State<PantallaAdminSocios> createState() => _PantallaAdminSociosState();
}

class _PantallaAdminSociosState extends State<PantallaAdminSocios> {
  String _busqueda = "";

  // Cache de precios para sugerir el monto al cobrar
  Map<String, double> _preciosCache = {};

  @override
  void initState() {
    super.initState();
    _cargarPreciosEnMemoria();
  }

  // Carga silenciosa de precios para tenerlos listos al cobrar
  Future<void> _cargarPreciosEnMemoria() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final map = data['precios_cuotas'] ?? {};
        map.forEach((k, v) {
          if (v is num) _preciosCache[k] = v.toDouble();
        });
      }
    } catch (e) {
      print("Error cargando precios: $e");
    }
  }

  // --- NAVEGACIÓN ---
  void _irAFormularioFamilia({String? familiaId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaAdminFormularioFamilia(
          config: widget.config,
          familiaIdEditar: familiaId,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _irAConfigurarPrecios() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaAdminPrecios(config: widget.config),
      ),
    ).then((_) => _cargarPreciosEnMemoria()); // Recargar al volver
  }

  // --- LÓGICA DE BORRADO ---
  Future<void> _borrarSocio(String docId, Map<String, dynamic> data) async {
    bool esTitular = data['es_titular'] == true;
    String familiaId = esTitular ? docId : (data['familia_id'] ?? docId);

    bool confirmar =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Eliminar Socio?"),
            content: Text(
              esTitular
                  ? "ATENCIÓN: Es TITULAR. Se borrará a TODA su familia."
                  : "¿Seguro deseas eliminar a este integrante?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "ELIMINAR",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    try {
      final db = FirebaseFirestore.instance;
      if (esTitular) {
        var batch = db.batch();
        var queryFamilia = await db
            .collection('socios')
            .where('familia_id', isEqualTo: familiaId)
            .get();
        for (var doc in queryFamilia.docs) {
          batch.delete(doc.reference);
        }
        // Asegurar borrado del doc titular si no vino en la query
        batch.delete(db.collection('socios').doc(docId));
        await batch.commit();
      } else {
        await db.collection('socios').doc(docId).delete();
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Eliminado correctamente.")),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- LÓGICA DE COBRO CON CAJA (MOVIMIENTOS) ---
  void _mostrarDialogoCobro(String docId, Map<String, dynamic> data) {
    // 1. Calcular Mes a Pagar
    String ultimoMesPagoStr = data['ultimo_mes_pago'] ?? '';
    DateTime fechaBase; // La fecha que vamos a pagar
    if (ultimoMesPagoStr.isEmpty) {
      fechaBase = DateTime.now(); // Si nunca pagó, paga el mes actual
    } else {
      DateTime ultimo = DateTime.parse("$ultimoMesPagoStr-01");
      fechaBase = DateTime(
        ultimo.year,
        ultimo.month + 1,
        1,
      ); // Paga el siguiente
    }

    // Lista de meses para mostrar nombre lindo
    const meses = [
      "Ene",
      "Feb",
      "Mar",
      "Abr",
      "May",
      "Jun",
      "Jul",
      "Ago",
      "Sep",
      "Oct",
      "Nov",
      "Dic",
    ];
    String nombreMes = "${meses[fechaBase.month - 1]} ${fechaBase.year}";

    // 2. Determinar Monto Sugerido
    String actividad = data['actividad'] ?? 'Socio Pleno';
    double montoSugerido =
        _preciosCache[actividad] ?? _preciosCache['Socio Pleno'] ?? 0;

    // Controlador para que el admin pueda cambiar el precio si quiere (ej: descuento)
    final montoCtrl = TextEditingController(
      text: montoSugerido.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Registrar Cobro"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Socio: ${data['nombre']} ${data['apellido']}"),
            Text(
              "Actividad: $actividad",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text(
              "Cobrando mes de: $nombreMes",
              style: TextStyle(
                color: widget.config.colorPrimario,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monto a Cobrar",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Al confirmar, se actualizará el carnet y se generará un ingreso en la caja.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.attach_money),
            label: const Text("CONFIRMAR PAGO"),
            onPressed: () {
              double montoFinal = double.tryParse(montoCtrl.text) ?? 0;
              if (montoFinal > 0) {
                _procesarPago(docId, data, fechaBase, montoFinal, actividad);
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _procesarPago(
    String docId,
    Map<String, dynamic> socioData,
    DateTime mesPagado,
    double monto,
    String actividad,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final userAdmin = FirebaseAuth.instance.currentUser;

      // Formato para guardar en socio: YYYY-MM
      String nuevoUltimoMesStr =
          "${mesPagado.year}-${mesPagado.month.toString().padLeft(2, '0')}";

      // Batch para atomicidad (o se guardan los dos, o ninguno)
      WriteBatch batch = db.batch();

      // 1. ACTUALIZAR SOCIO
      DocumentReference socioRef = db.collection('socios').doc(docId);
      batch.update(socioRef, {
        'ultimo_mes_pago': nuevoUltimoMesStr,
        'al_dia': true,
        'fecha_ultimo_cobro_real': FieldValue.serverTimestamp(),
      });

      // 2. CREAR MOVIMIENTO DE CAJA
      DocumentReference movRef = db.collection('movimientos').doc(); // ID auto
      batch.set(movRef, {
        'tipo': 'ingreso', // ingreso o egreso
        'monto': monto,
        'fecha': FieldValue.serverTimestamp(),
        'concepto': "Cuota ${mesPagado.month}/${mesPagado.year} - $actividad",
        'socio_id': docId,
        'socio_nombre': "${socioData['apellido']} ${socioData['nombre']}",
        'admin_email': userAdmin?.email ?? 'Desconocido',
        'mes_correspondiente': nuevoUltimoMesStr,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("¡Cobro de \$$monto registrado con éxito!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al cobrar: $e")));
    }
  }

  // --- CALCULO DE ESTADO ---
  Map<String, dynamic> _obtenerEstado(Map<String, dynamic> data) {
    String ultimoMes = data['ultimo_mes_pago'] ?? '';
    if (ultimoMes.isEmpty) return {'texto': 'SIN PAGO', 'color': Colors.grey};

    try {
      DateTime fechaPago = DateTime.parse("$ultimoMes-01");
      DateTime ahora = DateTime.now();

      // Diferencia en meses
      int diff =
          (ahora.year * 12 + ahora.month) -
          (fechaPago.year * 12 + fechaPago.month);

      if (diff <= 0) return {'texto': 'AL DÍA', 'color': Colors.green};
      if (diff == 1 && ahora.day <= 10)
        return {'texto': 'VENCE EL 10', 'color': Colors.lightGreen};

      return {'texto': 'DEUDA ($diff meses)', 'color': Colors.red};
    } catch (e) {
      return {'texto': 'ERROR', 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Socios"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.price_change),
            tooltip: "Configurar Precios",
            onPressed: _irAConfigurarPrecios,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.config.colorPrimario,
        icon: const Icon(Icons.group_add),
        label: const Text("NUEVA FAMILIA"),
        onPressed: () => _irAFormularioFamilia(familiaId: null),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Buscar por Apellido, Nombre o DNI...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _busqueda = val.toLowerCase()),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('socios')
                  .orderBy('apellido')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                if (_busqueda.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    String busquedaStr =
                        "${data['nombre']} ${data['apellido']} ${data['dni']} ${data['busqueda']}"
                            .toLowerCase();
                    return busquedaStr.contains(_busqueda);
                  }).toList();
                }

                if (docs.isEmpty)
                  return const Center(child: Text("No se encontraron socios."));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final id = doc.id;

                    final estado = _obtenerEstado(data);
                    final esTitular = data['es_titular'] == true;
                    // ID de familia: si es titular es su ID, si no, el campo familia_id
                    final familiaIdParaEditar = esTitular
                        ? id
                        : (data['familia_id'] ?? '');

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: esTitular
                            ? BorderSide(
                                color: widget.config.colorPrimario.withOpacity(
                                  0.5,
                                ),
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              (data['foto_url'] != null &&
                                  data['foto_url'] != '')
                              ? NetworkImage(data['foto_url'])
                              : null,
                          child:
                              (data['foto_url'] == null ||
                                  data['foto_url'] == '')
                              ? Icon(
                                  esTitular ? Icons.star : Icons.person,
                                  color: esTitular
                                      ? Colors.orange
                                      : Colors.grey,
                                )
                              : null,
                        ),
                        title: Text(
                          "${data['apellido']}, ${data['nombre']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esTitular ? Colors.black : Colors.grey[700],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${data['actividad'] ?? '-'} • DNI: ${data['dni']}",
                            ),
                            if (esTitular)
                              Text(
                                "TITULAR FAMILIA",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: widget.config.colorPrimario,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: estado['color'],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                estado['texto'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),

                            // BOTÓN COBRAR (NUEVO)
                            IconButton(
                              icon: const Icon(Icons.payments, size: 20),
                              color: Colors.green,
                              tooltip: "Cobrar Cuota",
                              onPressed: () => _mostrarDialogoCobro(id, data),
                            ),

                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () => _irAFormularioFamilia(
                                familiaId: familiaIdParaEditar,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () => _borrarSocio(id, data),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
