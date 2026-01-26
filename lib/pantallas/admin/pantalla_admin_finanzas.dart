import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminFinanzas extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminFinanzas({super.key, required this.config});

  @override
  State<PantallaAdminFinanzas> createState() => _PantallaAdminFinanzasState();
}

class _PantallaAdminFinanzasState extends State<PantallaAdminFinanzas>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filtros de fecha (por defecto mes actual)
  DateTime _fechaInicio = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Selector de rango de fechas
  Future<void> _seleccionarRangoFecha() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: widget.config.colorPrimario,
            colorScheme: ColorScheme.light(
              primary: widget.config.colorPrimario,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end.add(
          const Duration(hours: 23, minutes: 59),
        ); // Final del día
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Caja y Finanzas"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _seleccionarRangoFecha,
            tooltip: "Filtrar Fechas",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: widget.config.colorPrimario,
          unselectedLabelColor: Colors.grey,
          indicatorColor: widget.config.colorPrimario,
          tabs: const [
            Tab(text: "Movimientos"),
            Tab(text: "Nuevo Gasto/Ingreso"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabMovimientos(
            config: widget.config,
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
          ),
          _TabNuevoMovimiento(
            config: widget.config,
            alGuardar: () {
              _tabController.animateTo(0);
              setState(() {}); // Forzar recarga visual
            },
          ),
        ],
      ),
    );
  }
}

// --- TAB 1: LISTADO Y BALANCE ---
class _TabMovimientos extends StatelessWidget {
  final ConfiguracionApp config;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const _TabMovimientos({
    required this.config,
    required this.fechaInicio,
    required this.fechaFin,
  });

  // Función para borrar movimiento
  Future<void> _borrarMovimiento(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    bool esCuota = data['concepto'].toString().toLowerCase().contains('cuota');

    bool confirmar =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Anular Movimiento?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Se eliminará el registro de \$${data['monto']} de la caja.",
                ),
                if (esCuota) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "⚠ ATENCIÓN: Estás borrando un cobro de cuota. Esto ajustará la caja pero NO cambiará la fecha de vencimiento en el carnet del socio. Deberás ajustarla manualmente si corresponde.",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
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

    if (confirmar) {
      await FirebaseFirestore.instance
          .collection('movimientos')
          .doc(id)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Movimiento eliminado correctamente")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('movimientos')
          .orderBy('fecha', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        // Filtrado en memoria
        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['fecha'] == null) return false;
          DateTime fechaDoc = (data['fecha'] as Timestamp).toDate();
          return fechaDoc.isAfter(
                fechaInicio.subtract(const Duration(seconds: 1)),
              ) &&
              fechaDoc.isBefore(fechaFin.add(const Duration(seconds: 1)));
        }).toList();

        // Calculamos totales
        double ingresos = 0;
        double egresos = 0;
        double efectivo = 0;
        double digital = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final monto = (data['monto'] ?? 0).toDouble();
          final tipo = (data['tipo'] ?? '').toString().toLowerCase();
          final metodo = (data['metodo'] ?? 'Efectivo').toString();

          if (tipo == 'ingreso') {
            ingresos += monto;
            if (metodo == 'Efectivo')
              efectivo += monto;
            else
              digital += monto;
          } else {
            egresos += monto;
            if (metodo == 'Efectivo')
              efectivo -= monto;
            else
              digital -= monto;
          }
        }

        return Column(
          children: [
            // TARJETA DE BALANCE GENERAL
            Container(
              margin: const EdgeInsets.fromLTRB(15, 15, 15, 5),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoBalance("Ingresos", ingresos, Colors.green),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _InfoBalance("Gastos", egresos, Colors.red),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _InfoBalance(
                    "Saldo",
                    ingresos - egresos,
                    (ingresos - egresos) >= 0 ? Colors.blue : Colors.orange,
                  ),
                ],
              ),
            ),

            // TARJETA DE ARQUEO
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "En Caja Física: \$${efectivo.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    "Digital/Bancos: \$${digital.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // LISTA DE MOVIMIENTOS
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text("No hay movimientos en este rango."),
                    )
                  : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final id = docs[index].id;
                        final tipo = (data['tipo'] ?? '')
                            .toString()
                            .toLowerCase();
                        final bool esIngreso = tipo == 'ingreso';
                        final fecha =
                            (data['fecha'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final metodo = data['metodo'] ?? 'Automático';

                        IconData icon = esIngreso
                            ? Icons.arrow_downward
                            : Icons.arrow_upward;
                        if (data['concepto'].toString().contains('Cuota'))
                          icon = Icons.receipt_long;
                        if (data['categoria'] == 'Mantenimiento')
                          icon = Icons.build;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esIngreso
                                ? Colors.green[50]
                                : Colors.red[50],
                            child: Icon(
                              icon,
                              color: esIngreso ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            data['concepto'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                DateFormat('dd/MM HH:mm').format(fecha),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  metodo,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            "${esIngreso ? '+' : '-'} \$${data['monto']}",
                            style: TextStyle(
                              color: esIngreso
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () => _borrarMovimiento(
                            context,
                            id,
                            data,
                          ), // AHORA SÍ HACE ALGO
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoBalance extends StatelessWidget {
  final String label;
  final double valor;
  final Color color;
  const _InfoBalance(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          "\$${valor.toStringAsFixed(0)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// --- TAB 2: NUEVO REGISTRO (MANUAL) ---
class _TabNuevoMovimiento extends StatefulWidget {
  final ConfiguracionApp config;
  final VoidCallback alGuardar;
  const _TabNuevoMovimiento({required this.config, required this.alGuardar});
  @override
  State<_TabNuevoMovimiento> createState() => _TabNuevoMovimientoState();
}

class _TabNuevoMovimientoState extends State<_TabNuevoMovimiento> {
  String _tipo = 'ingreso';
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  String _metodo = 'Efectivo';
  String _categoria = 'Varios';
  bool _guardando = false;

  String? _socioVinculadoId;
  String? _socioVinculadoNombre;

  Future<void> _seleccionarSocio() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Vincular Socio"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Selecciona si este movimiento está asociado a alguien.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('socios')
                      .orderBy('apellido')
                      .limit(50)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final socios = snap.data!.docs;
                    if (socios.isEmpty)
                      return const Center(child: Text("No hay socios."));

                    return ListView.separated(
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemCount: socios.length,
                      itemBuilder: (ctx, i) {
                        final d = socios[i].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text("${d['apellido']}, ${d['nombre']}"),
                          subtitle: Text(d['actividad'] ?? ''),
                          onTap: () {
                            setState(() {
                              _socioVinculadoId = socios[i].id;
                              _socioVinculadoNombre =
                                  "${d['apellido']} ${d['nombre']}";
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    if (_montoCtrl.text.isEmpty || _conceptoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa Monto y Concepto")),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('movimientos').add({
        'tipo': _tipo,
        'monto': double.parse(_montoCtrl.text),
        'concepto': _conceptoCtrl.text,
        'metodo': _metodo,
        'categoria': _categoria,
        'fecha': FieldValue.serverTimestamp(),
        'socio_id': _socioVinculadoId,
        'socio_nombre': _socioVinculadoNombre,
        'origen': 'manual',
      });

      _montoCtrl.clear();
      _conceptoCtrl.clear();
      _socioVinculadoId = null;
      _socioVinculadoNombre = null;
      _categoria = 'Varios';

      widget.alGuardar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Movimiento registrado correctamente")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BotonTipo(
                  "INGRESO",
                  Colors.green,
                  _tipo == 'ingreso',
                  () => setState(() => _tipo = 'ingreso'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _BotonTipo(
                  "GASTO (Egreso)",
                  Colors.red,
                  _tipo == 'egreso',
                  () => setState(() => _tipo = 'egreso'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Monto",
              prefixText: "\$ ",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
          ),
          const SizedBox(height: 15),

          TextField(
            controller: _conceptoCtrl,
            decoration: const InputDecoration(
              labelText: "Concepto / Descripción",
              hintText: "Ej: Pago Luz, Compra Pelotas, Venta de Camiseta...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _metodo,
                  decoration: const InputDecoration(
                    labelText: "Método",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items:
                      ['Efectivo', 'Mercado Pago', 'Transferencia', 'Tarjeta']
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _metodo = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _categoria,
                  decoration: const InputDecoration(
                    labelText: "Categoría",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items:
                      [
                            'Varios',
                            'Cuotas',
                            'Mantenimiento',
                            'Servicios',
                            'Materiales',
                            'Torneos',
                            'Sueldos',
                          ]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _categoria = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 0,
            ),
            title: Text(
              _socioVinculadoNombre == null
                  ? "Vincular a un Socio (Opcional)"
                  : "Vinculado a: $_socioVinculadoNombre",
              style: TextStyle(
                fontWeight: _socioVinculadoNombre != null
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            subtitle: _socioVinculadoNombre == null
                ? const Text("Para imputar gastos o cobros extra")
                : null,
            leading: Icon(Icons.person_pin, color: widget.config.colorPrimario),
            trailing: _socioVinculadoNombre == null
                ? const Icon(Icons.arrow_forward_ios, size: 14)
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _socioVinculadoId = null;
                      _socioVinculadoNombre = null;
                    }),
                  ),
            onTap: _seleccionarSocio,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tipo == 'ingreso' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "GUARDAR ${_tipo.toUpperCase()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  final String texto;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;
  const _BotonTipo(this.texto, this.color, this.seleccionado, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: seleccionado ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            color: seleccionado ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
