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
  bool _subiendoFotoGeneral = false; // <--- BLOQUEADOR GENERAL

  // --- CONTROLADORES TITULAR ---
  final _dniTitularCtrl = TextEditingController();
  final _nombreTitularCtrl = TextEditingController();
  final _apellidoTitularCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nroSocioCtrl = TextEditingController();
  final _fotoTitularCtrl = TextEditingController();
  final _categoriaTitularCtrl = TextEditingController();

  List<String> _actividadesTitular = [];
  List<Map<String, dynamic>> _hijos = [];

  List<String> _conceptosDisponibles = [];
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
      if (_conceptosDisponibles.contains('Cuota Social')) {
        _actividadesTitular = ['Cuota Social'];
      }
      setState(() => _cargando = false);
    }
  }

  List<String> _limpiarActividades(dynamic arrayActs, dynamic stringAct) {
    Set<String> resultado = {};
    if (arrayActs != null && arrayActs is List) {
      for (var a in arrayActs) {
        resultado.addAll(
          a.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
        );
      }
    } else if (stringAct != null) {
      resultado.addAll(
        stringAct.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
      );
    }
    resultado.removeWhere((e) => e.isEmpty || e == 'Ninguna');
    return resultado.toList();
  }

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
          if (!key.contains('_') && key != 'fecha_actualizacion') {
            _conceptosDisponibles.add(key);
            if (value is num) _preciosCache[key] = value.toDouble();
            if (value is String)
              _preciosCache[key] = double.tryParse(value) ?? 0;
          }
        });
        _conceptosDisponibles.sort();
      }
    } catch (e) {
      print("Error cargando precios: $e");
    }
  }

  Future<void> _cargarDatosFamilia() async {
    try {
      String idBuscado = widget.familiaIdEditar!;
      DocumentSnapshot docTitular = await FirebaseFirestore.instance
          .collection('socios')
          .doc(idBuscado)
          .get();

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
          _direccionCtrl.text = data['direccion'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _nroSocioCtrl.text = data['nro_socio'] ?? _dniTitularCtrl.text;
          _fotoTitularCtrl.text = data['foto_url'] ?? '';
          _categoriaTitularCtrl.text = data['categoria_deporte'] ?? '';

          _actividadesTitular = _limpiarActividades(
            data['actividades'],
            data['actividad'],
          );

          for (String act in _actividadesTitular) {
            if (!_conceptosDisponibles.contains(act)) {
              _conceptosDisponibles.add(act);
              _preciosCache[act] = 0.0;
            }
          }
        });

        var queryHijos = await FirebaseFirestore.instance
            .collection('socios')
            .where('familia_id', isEqualTo: docTitular.id)
            .get();

        setState(() {
          _hijos = [];
          for (var doc in queryHijos.docs) {
            if (doc.id == docTitular.id) continue;
            var h = doc.data();

            List<String> actsHijo = _limpiarActividades(
              h['actividades'],
              h['actividad'],
            );

            for (String act in actsHijo) {
              if (!_conceptosDisponibles.contains(act)) {
                _conceptosDisponibles.add(act);
                _preciosCache[act] = 0.0;
              }
            }

            _hijos.add({
              'id_existente': doc.id,
              'nombre': h['nombre'] ?? '',
              'apellido': h['apellido'] ?? '',
              'dni': h['dni'] ?? '',
              'actividades': actsHijo,
              'foto_url': h['foto_url'] ?? '',
              'categoria_deporte': h['categoria_deporte'] ?? '',
            });
          }

          _conceptosDisponibles.sort();
        });
      }
    } catch (e) {
      print("Error cargando familia: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<List<String>?> _mostrarSelectorMultiple(
    List<String> seleccionadasPrevias,
  ) async {
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
                        precio == 0
                            ? "(Obsoleta / Sin Precio)"
                            : "\$${precio.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: precio == 0
                              ? Colors.red[300]
                              : Colors.green[700],
                          fontSize: 12,
                        ),
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
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, seleccionTemporal),
                  child: const Text("LISTO"),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
    final fotoHijoCtrl = TextEditingController(
      text: esEdicion ? (datos['foto_url'] ?? '') : '',
    );
    final categoriaCtrl = TextEditingController(
      text: esEdicion ? (datos['categoria_deporte'] ?? '') : '',
    );

    List<String> actividadesHijo = esEdicion
        ? List<String>.from(datos['actividades'] ?? [])
        : [];
    if (!esEdicion && _conceptosDisponibles.contains('Cuota Social')) {
      actividadesHijo.add('Cuota Social');
    }

    bool subiendoFotoLocal = false; // <--- BLOQUEADOR DEL HIJO

    showDialog(
      context: context,
      barrierDismissible: false, // <-- NUNCA cerrar tocando afuera
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
                    InputImagen(
                      urlInicial: fotoHijoCtrl.text,
                      carpeta: 'socios_hijos',
                      nombreArchivo: dniCtrl.text
                          .trim(), // <-- LE PASAMOS EL DNI
                      onCargando: (estaSubiendo) {
                        setStateDialog(() => subiendoFotoLocal = estaSubiendo);
                      },
                      alSubirImagen: (url) {
                        setStateDialog(() => fotoHijoCtrl.text = url);
                      },
                    ),
                    if (subiendoFotoLocal)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Aguarde a que suba la foto...",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 15),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoriaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Categoría / División (Opcional)",
                        hintText: "Ej: 2012, Infantil...",
                        prefixIcon: Icon(Icons.sports_soccer),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                        if (res != null) {
                          setStateDialog(() => actividadesHijo = res);
                        }
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
                  onPressed: subiendoFotoLocal
                      ? null
                      : () => Navigator.pop(ctx),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  onPressed: subiendoFotoLocal
                      ? null
                      : () {
                          if (nombreCtrl.text.isEmpty || dniCtrl.text.isEmpty)
                            return;

                          // --- ESCUDO FOTO HIJO ---
                          String nuevaFotoHijo = fotoHijoCtrl.text.trim();
                          if (nuevaFotoHijo.isEmpty && esEdicion) {
                            nuevaFotoHijo = datos['foto_url'] ?? '';
                          }

                          Map<String, dynamic> nuevoHijo = {
                            'nombre': nombreCtrl.text,
                            'apellido': apellidoCtrl.text,
                            'dni': dniCtrl.text.trim(),
                            'actividades': actividadesHijo,
                            'foto_url': nuevaFotoHijo,
                            'categoria_deporte': categoriaCtrl.text.trim(),
                          };

                          if (esEdicion && datos.containsKey('id_existente')) {
                            nuevoHijo['id_existente'] = datos['id_existente'];
                          }

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

      String actividadResumenTitular = _actividadesTitular.isEmpty
          ? 'Ninguna'
          : _actividadesTitular.join(", ");

      // --- 1. DATOS TITULAR (SIN PISAR LA FOTO) ---
      Map<String, dynamic> dataTitular = {
        'nombre': _nombreTitularCtrl.text.trim(),
        'apellido': _apellidoTitularCtrl.text.trim(),
        'dni': dniTitular,
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'nro_socio': _nroSocioCtrl.text.isEmpty
            ? dniTitular
            : _nroSocioCtrl.text.trim(),
        'actividades': _actividadesTitular,
        'actividad': actividadResumenTitular,
        'categoria_deporte': _categoriaTitularCtrl.text.trim(),
        'familia_id': familiaId,
        'es_titular': true,
        'busqueda':
            "${_apellidoTitularCtrl.text} ${_nombreTitularCtrl.text} $dniTitular ${_categoriaTitularCtrl.text.trim()}"
                .toLowerCase(),
      };

      // --- ESCUDO FOTO TITULAR ---
      if (_fotoTitularCtrl.text.trim().isNotEmpty) {
        dataTitular['foto_url'] = _fotoTitularCtrl.text.trim();
      }

      String ultimoMesPagoStr = "";
      if (!esEdicion) {
        DateTime ayer = DateTime.now().subtract(const Duration(days: 30));
        ultimoMesPagoStr =
            "${ayer.year}-${ayer.month.toString().padLeft(2, '0')}";
        dataTitular['al_dia'] = false;
        dataTitular['ultimo_mes_pago'] = ultimoMesPagoStr;
        dataTitular['creado_el'] = FieldValue.serverTimestamp();
      }

      batch.set(
        db.collection('socios').doc(dniTitular),
        dataTitular,
        SetOptions(merge: true), // Solo pisa los campos nuevos
      );

      for (var hijo in _hijos) {
        String dniHijo = hijo['dni'].toString().trim();
        if (dniHijo.isEmpty) continue;

        List<String> actsHijo = hijo['actividades'] ?? [];
        String actividadResumenHijo = actsHijo.isEmpty
            ? 'Ninguna'
            : actsHijo.join(", ");
        String catHijo = hijo['categoria_deporte'] ?? '';

        Map<String, dynamic> dataHijo = {
          'nombre': hijo['nombre'],
          'apellido': hijo['apellido'],
          'dni': dniHijo,
          'nro_socio': dniHijo,
          'actividades': actsHijo,
          'actividad': actividadResumenHijo,
          'categoria_deporte': catHijo,
          'familia_id': familiaId,
          'es_titular': false,
          'busqueda': "${hijo['apellido']} ${hijo['nombre']} $dniHijo $catHijo"
              .toLowerCase(),
        };

        // --- ESCUDO FOTO HIJO ---
        String fotoUrlHijo = (hijo['foto_url'] ?? '').toString().trim();
        if (fotoUrlHijo.isNotEmpty) {
          dataHijo['foto_url'] = fotoUrlHijo;
        }

        if (!esEdicion) {
          dataHijo['ultimo_mes_pago'] = ultimoMesPagoStr;
          dataHijo['al_dia'] = false;
          dataHijo['creado_el'] = FieldValue.serverTimestamp();
        }

        batch.set(
          db.collection('socios').doc(dniHijo),
          dataHijo,
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Familia guardada correctamente.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esEdicion = widget.familiaIdEditar != null;

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
                            nombreArchivo: _dniTitularCtrl.text
                                .trim(), // <-- LE PASAMOS EL DNI
                            onCargando: (estaSubiendo) {
                              setState(
                                () => _subiendoFotoGeneral = estaSubiendo,
                              );
                            },
                            alSubirImagen: (u) => _fotoTitularCtrl.text = u,
                          ),
                          if (_subiendoFotoGeneral)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Aguarde a que suba la foto...",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
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
                          TextField(
                            controller: _direccionCtrl,
                            decoration: const InputDecoration(
                              labelText: "Dirección",
                            ),
                          ),
                          TextField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _categoriaTitularCtrl,
                            decoration: const InputDecoration(
                              labelText: "Categoría / División (Opcional)",
                              hintText: "Ej: Primera, Femenino...",
                              prefixIcon: Icon(Icons.sports_soccer),
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
                          InkWell(
                            onTap: () async {
                              final res = await _mostrarSelectorMultiple(
                                _actividadesTitular,
                              );
                              if (res != null) {
                                setState(() => _actividadesTitular = res);
                              }
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
                          String cat = h['categoria_deporte'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  (h['foto_url'] != null && h['foto_url'] != '')
                                  ? NetworkImage(h['foto_url'])
                                  : null,
                              child:
                                  (h['foto_url'] == null || h['foto_url'] == '')
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text("${h['nombre']} ${h['apellido']}"),
                            subtitle: Text(
                              "${h['dni']} - [${acts.join(', ')}]\n${cat.isNotEmpty ? 'Cat: $cat' : ''}",
                            ),
                            isThreeLine: cat.isNotEmpty,
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
                  ElevatedButton(
                    onPressed: _subiendoFotoGeneral
                        ? null
                        : _guardarFamilia, // <--- BLOQUEO SEGURO
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: _subiendoFotoGeneral
                          ? Colors.grey
                          : widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                    ),
                    child: _subiendoFotoGeneral
                        ? const Text("ESPERANDO IMAGEN...")
                        : const Text("GUARDAR DATOS"),
                  ),
                ],
              ),
            ),
    );
  }
}
