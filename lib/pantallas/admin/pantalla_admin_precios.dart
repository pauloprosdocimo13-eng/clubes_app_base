import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/servicio_datos_club.dart';

class PantallaAdminPrecios extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminPrecios({
    super.key,
    required this.config,
  });

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

  // Carga inicial desde la base correspondiente al club actual.
  //
  // Horizonte / generico:
  //   clubes/generico/configuracion/precios
  //
  // Güemes y demás clubes Legacy:
  //   configuracion/precios
  Future<void> _cargarPrecios() async {
    try {
      final doc = await ServicioDatosClub.precios.get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _precios = doc.data()?['precios_cuotas'] ?? {};
          _cargando = false;
        });
      } else {
        // Conservamos los mismos valores sugeridos que tenía la pantalla.
        // No se escriben hasta que el administrador guarde algún cambio.
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
      if (!mounted) return;

      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error cargando precios: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Guardar cambio (Agregar o Editar)
  Future<void> _guardarCambio(String actividad, double precio) async {
    // 1. Actualizar estado local para feedback inmediato
    setState(() {
      _precios[actividad] = precio;
    });

    // 2. Guardar en la base correspondiente al club.
    try {
      final user = ServicioDatosClub.usuarioAuthActual;

      await ServicioDatosClub.precios.set({
        'precios_cuotas': _precios,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'actualizado_por_email': user?.email ?? 'Desconocido',
        'actualizado_por_uid': user?.uid ?? '',
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Precio guardado correctamente en "
            "${ServicioDatosClub.origenDescripcion}.",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error guardando: $e"),
          backgroundColor: Colors.red,
        ),
      );

      // Si la escritura falla, volvemos a leer la versión real de Firestore
      // para no dejar en pantalla un valor que no quedó guardado.
      await _cargarPrecios();
    }
  }

  Future<void> _borrarActividad(String actividad) async {
    bool confirmar =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("¿Borrar Actividad?"),
            content: Text(
              "Se eliminará '$actividad' de la lista de precios.",
            ),
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

    // 1. Lo borramos visualmente de la pantalla al instante.
    setState(() {
      _precios.remove(actividad);
    });

    // 2. Eliminamos únicamente esa actividad del mapa remoto.
    try {
      final user = ServicioDatosClub.usuarioAuthActual;

      await ServicioDatosClub.precios.set({
        'precios_cuotas': {
          actividad: FieldValue.delete(),
        },
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'actualizado_por_email': user?.email ?? 'Desconocido',
        'actualizado_por_uid': user?.uid ?? '',
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "'$actividad' fue eliminada de "
            "${ServicioDatosClub.origenDescripcion}.",
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al borrar en la nube: $e"),
          backgroundColor: Colors.red,
        ),
      );

      // Si la baja falla, recargamos para mostrar nuevamente el dato real.
      await _cargarPrecios();
    }
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  color: Colors.blueGrey[50],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueGrey[800],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Datos: ${ServicioDatosClub.origenDescripcion}\n"
                          "Estas actividades aparecerán automáticamente "
                          "en el alta de socios y se usarán para calcular "
                          "el total a pagar.",
                          style: TextStyle(
                            color: Colors.blueGrey[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(15),
                    itemCount: listaOrdenada.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = listaOrdenada[index];
                      final valor = entry.value is num
                          ? (entry.value as num).toDouble()
                          : double.tryParse(entry.value.toString()) ?? 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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
                                "\$${valor.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                              tooltip: "Editar precio",
                              onPressed: () => _mostrarDialogoEditar(
                                entry.key,
                                valor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              tooltip: "Borrar actividad",
                              onPressed: () =>
                                  _borrarActividad(entry.key),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
