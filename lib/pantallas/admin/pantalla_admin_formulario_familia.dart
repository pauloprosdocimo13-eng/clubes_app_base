import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../configuracion/configuracion_app.dart';
import '../../widgets/input_imagen.dart';

class PantallaAdminFormularioFamilia extends StatefulWidget {
  final ConfiguracionApp config;
  final String? familiaIdEditar;

  const PantallaAdminFormularioFamilia({
    super.key,
    required this.config,
    this.familiaIdEditar,
  });

  @override
  State<PantallaAdminFormularioFamilia> createState() =>
      _PantallaAdminFormularioFamiliaState();
}

class _PantallaAdminFormularioFamiliaState
    extends State<PantallaAdminFormularioFamilia> {
  bool _cargando = true;

  // --- CONTROLADORES TITULAR ---
  final _dniTitularCtrl = TextEditingController();
  final _nombreTitularCtrl = TextEditingController();
  final _apellidoTitularCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nroSocioCtrl = TextEditingController();
  final _fotoTitularCtrl = TextEditingController();

  // AHORA: Lista de actividades seleccionadas (Strings)
  List<String> _actividadesTitular = [];

  bool _pagaAhora = false;

  // --- LISTA DE INTEGRANTES (HIJOS) ---
  // Cada mapa tendrá 'actividades': List<String>
  List<Map<String, dynamic>> _hijos = [];

  // --- PRECIOS Y CONCEPTOS ---
  List<String> _conceptosDisponibles = []; // Ej: [Cuota Social, Fútbol, Patín]
  Map<String, double> _preciosCache = {};

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await _cargarPreciosYConceptos();

    if (widget.familiaIdEditar != null) {
      await _cargarDatosFamilia();
    } else {
      // Valor por defecto para nuevos: Si existe "Cuota Social", la pre-seleccionamos
      if (_conceptosDisponibles.contains('Cuota Social')) {
        _actividadesTitular = ['Cuota Social'];
      }
      setState(() => _cargando = false);
    }
  }

  // 1. CARGA DE PRECIOS PARA LOS CHECKBOXES
  Future<void> _cargarPreciosYConceptos() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        Map<String, dynamic> mapaPrecios = data['precios_cuotas'] ?? data;

        _preciosCache.clear();
        _conceptosDisponibles.clear();

        mapaPrecios.forEach((key, value) {
          // Filtramos claves internas
          if (!key.contains('_') && key != 'fecha_actualizacion') {
            _conceptosDisponibles.add(key);
            if (value is num) _preciosCache[key] = value.toDouble();
            if (value is String)
              _preciosCache[key] = double.tryParse(value) ?? 0;
          }
        });

        // Ordenamos alfabéticamente para que se vea prolijo
        _conceptosDisponibles.sort();
      }
    } catch (e) {
      print("Error cargando precios: $e");
    }
  }

  // 2. CARGA DE DATOS (EDICIÓN)
  Future<void> _cargarDatosFamilia() async {
    try {
      String idBuscado = widget.familiaIdEditar!;
      DocumentSnapshot docTitular = await FirebaseFirestore.instance
          .collection('socios')
          .doc(idBuscado)
          .get();

      // Fallback por familia_id
      if (!docTitular.exists) {
        var query = await FirebaseFirestore.instance
            .collection('socios')
            .where('familia_id', isEqualTo: idBuscado)
            .where('es_titular', isEqualTo: true)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) docTitular = query.docs.first;
      }

      if (docTitular.exists) {
        final data = docTitular.data() as Map<String, dynamic>;

        setState(() {
          _dniTitularCtrl.text = data['dni'] ?? docTitular.id;
          _nombreTitularCtrl.text = data['nombre'] ?? '';
          _apellidoTitularCtrl.text = data['apellido'] ?? '';
          _telefonoCtrl.text = data['telefono'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _nroSocioCtrl.text = data['nro_socio'] ?? _dniTitularCtrl.text;
          _fotoTitularCtrl.text = data['foto_url'] ?? '';

          // RECUPERAR ACTIVIDADES (Manejo de retrocompatibilidad)
          if (data['actividades'] != null) {
            _actividadesTitular = List<String>.from(data['actividades']);
          } else if (data['actividad'] != null) {
            // Si venía del sistema viejo (un solo string), lo convertimos a lista
            String actVieja = data['actividad'];
            if (actVieja != 'Ninguna')
              _actividadesTitular = [actVieja];
            else
              _actividadesTitular = [];
          }
        });

        // Cargar Hijos
        var queryHijos = await FirebaseFirestore.instance
            .collection('socios')
            .where('familia_id', isEqualTo: docTitular.id)
            .get();

        setState(() {
          _hijos = [];
          for (var doc in queryHijos.docs) {
            if (doc.id == docTitular.id) continue;

            var h = doc.data();

            // Lógica de Actividades Hijo
            List<String> actsHijo = [];
            if (h['actividades'] != null) {
              actsHijo = List<String>.from(h['actividades']);
            } else if (h['actividad'] != null) {
              String actVieja = h['actividad'];
              if (actVieja != 'Ninguna') actsHijo = [actVieja];
            }

            _hijos.add({
              'id_existente': doc.id,
              'nombre': h['nombre'] ?? '',
              'apellido': h['apellido'] ?? '',
              'dni': h['dni'] ?? '',
              'actividades': actsHijo, // Lista
              'foto_url': h['foto_url'] ?? '',
            });
          }
        });
      }
    } catch (e) {
      print("Error cargando familia: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- HELPER: DIÁLOGO DE SELECCIÓN MÚLTIPLE ---
  Future<List<String>?> _mostrarSelectorMultiple(
    List<String> seleccionadasPrevias,
  ) async {
    // Copia temporal para trabajar en el diálogo
    List<String> seleccionTemporal = List.from(seleccionadasPrevias);

    return await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Seleccionar Conceptos"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _conceptosDisponibles.length,
                  itemBuilder: (ctx, i) {
                    final concepto = _conceptosDisponibles[i];
                    final precio = _preciosCache[concepto] ?? 0;
                    final estaSeleccionado = seleccionTemporal.contains(
                      concepto,
                    );

                    return CheckboxListTile(
                      title: Text(concepto),
                      subtitle: Text(
                        "\$${precio.toStringAsFixed(0)}",
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      value: estaSeleccionado,
                      activeColor: widget.config.colorPrimario,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            seleccionTemporal.add(concepto);
                          } else {
                            seleccionTemporal.remove(concepto);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null), // Cancelar
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, seleccionTemporal), // Aceptar
                  child: const Text("LISTO"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIÁLOGO HIJO ---
  void _abrirDialogoHijo({int? indexEditar}) {
    bool esEdicion = indexEditar != null;
    Map<String, dynamic> datos = esEdicion ? _hijos[indexEditar] : {};

    final nombreCtrl = TextEditingController(
      text: esEdicion ? datos['nombre'] : '',
    );
    final apellidoCtrl = TextEditingController(
      text: esEdicion ? datos['apellido'] : _apellidoTitularCtrl.text,
    );
    final dniCtrl = TextEditingController(text: esEdicion ? datos['dni'] : '');

    // Lista local para el hijo
    List<String> actividadesHijo = esEdicion
        ? List<String>.from(datos['actividades'] ?? [])
        : [];
    // Pre-seleccionar Cuota Social si es nuevo
    if (!esEdicion && _conceptosDisponibles.contains('Cuota Social')) {
      actividadesHijo.add('Cuota Social');
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                esEdicion ? "Editar Integrante" : "Agregar Integrante",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: apellidoCtrl,
                      decoration: const InputDecoration(
                        labelText: "Apellido",
                        prefixIcon: Icon(Icons.family_restroom),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dniCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "DNI (Será ID)",
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SELECTOR ACTIVIDADES HIJO
                    const Text(
                      "Actividades / Conceptos:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final res = await _mostrarSelectorMultiple(
                          actividadesHijo,
                        );
                        if (res != null)
                          setStateDialog(() => actividadesHijo = res);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.list, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                actividadesHijo.isEmpty
                                    ? "Toca para seleccionar..."
                                    : actividadesHijo.join(", "),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nombreCtrl.text.isEmpty || dniCtrl.text.isEmpty) return;

                    Map<String, dynamic> nuevoHijo = {
                      'nombre': nombreCtrl.text,
                      'apellido': apellidoCtrl.text,
                      'dni': dniCtrl.text.trim(),
                      'actividades': actividadesHijo, // GUARDAMOS LA LISTA
                      'foto_url': esEdicion ? datos['foto_url'] : '',
                    };

                    if (esEdicion && datos.containsKey('id_existente'))
                      nuevoHijo['id_existente'] = datos['id_existente'];

                    setState(() {
                      if (esEdicion)
                        _hijos[indexEditar] = nuevoHijo;
                      else
                        _hijos.add(nuevoHijo);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("GUARDAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _borrarHijo(int index) async {
    Map<String, dynamic> hijo = _hijos[index];
    if (hijo.containsKey('id_existente')) {
      await FirebaseFirestore.instance
          .collection('socios')
          .doc(hijo['id_existente'])
          .delete();
    }
    setState(() => _hijos.removeAt(index));
  }

  // --- GUARDADO GENERAL ---
  Future<void> _guardarFamilia() async {
    if (_dniTitularCtrl.text.isEmpty || _apellidoTitularCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("DNI y Apellido son obligatorios")),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final db = FirebaseFirestore.instance;
      String dniTitular = _dniTitularCtrl.text.trim();
      String familiaId = dniTitular;
      bool esEdicion = widget.familiaIdEditar != null;
      WriteBatch batch = db.batch();

      // String resumen de actividades del titular (para mostrar rápido en listas)
      String actividadResumenTitular = _actividadesTitular.isEmpty
          ? 'Ninguna'
          : _actividadesTitular.join(", ");

      Map<String, dynamic> dataTitular = {
        'nombre': _nombreTitularCtrl.text.trim(),
        'apellido': _apellidoTitularCtrl.text.trim(),
        'dni': dniTitular,
        'telefono': _telefonoCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'nro_socio': _nroSocioCtrl.text.isEmpty
            ? dniTitular
            : _nroSocioCtrl.text.trim(),
        'foto_url': _fotoTitularCtrl.text.trim(),
        'actividades': _actividadesTitular, // LISTA REAL
        'actividad': actividadResumenTitular, // STRING VISUAL
        'familia_id': familiaId,
        'es_titular': true,
        'busqueda':
            "${_apellidoTitularCtrl.text} ${_nombreTitularCtrl.text} $dniTitular"
                .toLowerCase(),
      };

      String ultimoMesPagoStr = "";
      if (!esEdicion) {
        if (!_pagaAhora) {
          DateTime ayer = DateTime.now().subtract(const Duration(days: 30));
          ultimoMesPagoStr =
              "${ayer.year}-${ayer.month.toString().padLeft(2, '0')}";
          dataTitular['al_dia'] = false;
        } else {
          DateTime hoy = DateTime.now();
          ultimoMesPagoStr =
              "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}";
          dataTitular['al_dia'] = true;
        }
        dataTitular['ultimo_mes_pago'] = ultimoMesPagoStr;
        dataTitular['creado_el'] = FieldValue.serverTimestamp();
      }

      batch.set(
        db.collection('socios').doc(dniTitular),
        dataTitular,
        SetOptions(merge: true),
      );

      // HIJOS
      for (var hijo in _hijos) {
        String dniHijo = hijo['dni'].toString().trim();
        if (dniHijo.isEmpty) continue;

        List<String> actsHijo = hijo['actividades'] ?? [];
        String actividadResumenHijo = actsHijo.isEmpty
            ? 'Ninguna'
            : actsHijo.join(", ");

        Map<String, dynamic> dataHijo = {
          'nombre': hijo['nombre'],
          'apellido': hijo['apellido'],
          'dni': dniHijo,
          'nro_socio': dniHijo,
          'actividades': actsHijo,
          'actividad': actividadResumenHijo,
          'foto_url': hijo['foto_url'] ?? '',
          'familia_id': familiaId,
          'es_titular': false,
          'busqueda': "${hijo['apellido']} ${hijo['nombre']} $dniHijo"
              .toLowerCase(),
        };

        if (!esEdicion) {
          dataHijo['ultimo_mes_pago'] = ultimoMesPagoStr;
          dataHijo['al_dia'] = dataTitular['al_dia'];
          dataHijo['creado_el'] = FieldValue.serverTimestamp();
        }

        batch.set(
          db.collection('socios').doc(dniHijo),
          dataHijo,
          SetOptions(merge: true),
        );
      }

      // --- MOVIMIENTO DE CAJA (SUMA DE CHECKBOXES) ---
      if (!esEdicion && _pagaAhora) {
        double totalACobrar = 0;
        List<String> detallesPago = [];

        // Sumar Titular
        for (var concepto in _actividadesTitular) {
          double p = _preciosCache[concepto] ?? 0;
          totalACobrar += p;
          if (p > 0) detallesPago.add("T: $concepto");
        }

        // Sumar Hijos
        for (var h in _hijos) {
          List<String> acts = h['actividades'] ?? [];
          for (var concepto in acts) {
            double p = _preciosCache[concepto] ?? 0;
            totalACobrar += p;
            if (p > 0) detallesPago.add("H(${h['nombre']}): $concepto");
          }
        }

        if (totalACobrar > 0) {
          DocumentReference movRef = db.collection('movimientos').doc();
          batch.set(movRef, {
            'tipo': 'ingreso',
            'monto': totalACobrar,
            'fecha': FieldValue.serverTimestamp(),
            'concepto': "Alta Familia - ${detallesPago.join(', ')}",
            'socio_id': dniTitular,
            'socio_nombre':
                "${_apellidoTitularCtrl.text} ${_nombreTitularCtrl.text}",
            'admin_email': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
            'mes_correspondiente': ultimoMesPagoStr,
          });
        }
      }

      await batch.commit();

      if (mounted) {
        if (!esEdicion && _pagaAhora) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Familia creada y PAGO REGISTRADO en caja."),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Datos guardados correctamente.")),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esEdicion = widget.familiaIdEditar != null;

    // Cálculo en vivo de cuánto pagaría si marca "Pagar Ahora"
    double estimadoTotal = 0;
    if (!esEdicion) {
      for (var a in _actividadesTitular)
        estimadoTotal += (_preciosCache[a] ?? 0);
      for (var h in _hijos) {
        for (var a in (h['actividades'] as List<String>))
          estimadoTotal += (_preciosCache[a] ?? 0);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(esEdicion ? "Editar Familia" : "Alta Familia"),
        backgroundColor: widget.config.colorPrimario,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // TARJETA TITULAR
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TITULAR (Jefe de Familia)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          InputImagen(
                            urlInicial: _fotoTitularCtrl.text,
                            carpeta: 'socios',
                            alSubirImagen: (u) => _fotoTitularCtrl.text = u,
                          ),
                          TextField(
                            controller: _nombreTitularCtrl,
                            decoration: const InputDecoration(
                              labelText: "Nombre",
                            ),
                          ),
                          TextField(
                            controller: _apellidoTitularCtrl,
                            decoration: const InputDecoration(
                              labelText: "Apellido",
                            ),
                          ),
                          TextField(
                            controller: _dniTitularCtrl,
                            enabled: !esEdicion,
                            decoration: const InputDecoration(
                              labelText: "DNI (ID Único)",
                            ),
                          ),
                          TextField(
                            controller: _telefonoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Teléfono",
                            ),
                          ),

                          const SizedBox(height: 15),
                          const Text(
                            "Conceptos a Pagar (Titular):",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // SELECTOR PERSONALIZADO TITULAR
                          InkWell(
                            onTap: () async {
                              final res = await _mostrarSelectorMultiple(
                                _actividadesTitular,
                              );
                              if (res != null)
                                setState(() => _actividadesTitular = res);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.list, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _actividadesTitular.isEmpty
                                          ? "Toca para seleccionar..."
                                          : _actividadesTitular.join(", "),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // TARJETA HIJOS
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text("INTEGRANTES"),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _abrirDialogoHijo,
                          ),
                        ),
                        ..._hijos.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var h = entry.value;
                          List<String> acts = h['actividades'] ?? [];
                          return ListTile(
                            title: Text("${h['nombre']} ${h['apellido']}"),
                            subtitle: Text(
                              "${h['dni']} - [${acts.join(', ')}]",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _abrirDialogoHijo(indexEditar: idx),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _borrarHijo(idx),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // CHECKBOX DE PAGO INICIAL
                  if (!esEdicion)
                    Card(
                      color: _pagaAhora ? Colors.green[50] : Colors.white,
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: _pagaAhora,
                            activeColor: Colors.green,
                            onChanged: (v) => setState(() => _pagaAhora = v!),
                            title: const Text(
                              "¿Paga ingreso ahora?",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              "Se sumarán todos los conceptos seleccionados.",
                            ),
                          ),
                          if (_pagaAhora)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                "Total Estimado: \$${estimadoTotal.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _guardarFamilia,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("GUARDAR DATOS"),
                  ),
                ],
              ),
            ),
    );
  }
}
