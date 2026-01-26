import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminFormularioSorteo extends StatefulWidget {
  final ConfiguracionApp config;
  final String? sorteoId; // Si es null, es NUEVO

  const PantallaAdminFormularioSorteo({
    super.key,
    required this.config,
    this.sorteoId,
  });

  @override
  State<PantallaAdminFormularioSorteo> createState() => _PantallaAdminFormularioSorteoState();
}

class _PantallaAdminFormularioSorteoState extends State<PantallaAdminFormularioSorteo> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _premioController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  DateTime _fechaSorteo = DateTime.now().add(const Duration(days: 30));
  int _cantidadNumeros = 100; // Por defecto 00-99
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    if (widget.sorteoId != null) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _tituloController.text = data['titulo'] ?? '';
        _premioController.text = data['premio'] ?? '';
        _precioController.text = data['precio']?.toString() ?? '';
        _cantidadNumeros = data['cantidad_numeros'] ?? 100;
        _activo = data['activo'] ?? true;
        if (data['fecha_sorteo'] != null) {
          _fechaSorteo = (data['fecha_sorteo'] as Timestamp).toDate();
        }
      }
    } catch (e) {
      print("Error cargando sorteo: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarSorteo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    double precio = double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0.0;

    final datos = {
      'titulo': _tituloController.text.trim(),
      'premio': _premioController.text.trim(),
      'precio': precio,
      'cantidad_numeros': _cantidadNumeros,
      'fecha_sorteo': Timestamp.fromDate(_fechaSorteo),
      'activo': _activo,
      // Si es nuevo, inicializamos el mapa de "vendidos" vacío
      // Si es edición, NO tocamos los vendidos (se mantienen)
    };

    try {
      if (widget.sorteoId == null) {
        // NUEVO
        await FirebaseFirestore.instance.collection('sorteos').add({
          ...datos,
          'numeros_vendidos': [], // Lista de ints (ej: [0, 14, 99])
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
      } else {
        // EDITAR
        await FirebaseFirestore.instance.collection('sorteos').doc(widget.sorteoId).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sorteoId == null ? "Nueva Rifa" : "Editar Rifa"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarSorteo)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text("Sorteo Activo"),
              subtitle: Text(_activo ? "Visible para todos" : "Oculto (Borrador/Finalizado)"),
              value: _activo,
              activeColor: widget.config.colorPrimario,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const Divider(),

            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: "Título de la Rifa",
                hintText: "Ej: Rifa Día del Padre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
              validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            ),
            const SizedBox(height: 15),

            TextFormField(
              controller: _premioController,
              decoration: const InputDecoration(
                labelText: "Premio(s)",
                hintText: "Ej: 1er Premio: TV 50' - 2do: Camiseta",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.card_giftcard),
              ),
              maxLines: 2,
              validator: (v) => v!.isEmpty ? "Indica qué se sortea" : null,
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Valor del Número (\$)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) => v!.isEmpty ? "Falta precio" : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _cantidadNumeros,
                    decoration: const InputDecoration(
                      labelText: "Cant. Números",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 100, child: Text("100 (00-99)")),
                      DropdownMenuItem(value: 200, child: Text("200 (000-199)")),
                      DropdownMenuItem(value: 333, child: Text("333 (Por lotería)")),
                      DropdownMenuItem(value: 500, child: Text("500 Números")),
                      DropdownMenuItem(value: 1000, child: Text("1000 (000-999)")),
                    ],
                    onChanged: widget.sorteoId == null
                        ? (v) => setState(() => _cantidadNumeros = v!)
                        : null, // No dejar cambiar cantidad si ya está creado para no romper ventas
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Fecha del Sorteo:"),
              subtitle: Text("${_fechaSorteo.day}/${_fechaSorteo.month}/${_fechaSorteo.year}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaSorteo,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _fechaSorteo = picked);
              },
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.colorPrimario,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _guardarSorteo,
              child: const Text("GUARDAR RIFA"),
            ),
          ],
        ),
      ),
    );
  }
}