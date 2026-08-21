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

  // Auditoría / seguridad de datos
  String? _titularDocIdOriginal;
  Map<String, dynamic>? _titularOriginal;
  final Map<String, Map<String, dynamic>> _integrantesOriginales = {};
  final Map<String, String> _bajasIntegrantesPendientes = {};

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

        _titularDocIdOriginal = docTitular.id;
        _titularOriginal = Map<String, dynamic>.from(data);

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
          _integrantesOriginales.clear();
          _bajasIntegrantesPendientes.clear();

          for (var doc in queryHijos.docs) {
            if (doc.id == docTitular.id) continue;
            var h = doc.data();

            _integrantesOriginales[doc.id] = Map<String, dynamic>.from(h);

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
                      enabled: !(esEdicion && datos.containsKey('id_existente')),
                      decoration: InputDecoration(
                        labelText: esEdicion && datos.containsKey('id_existente')
                            ? "DNI (ID único - no editable)"
                            : "DNI (Será ID)",
                        prefixIcon: const Icon(Icons.badge),
                        helperText: esEdicion && datos.containsKey('id_existente')
                            ? "Para proteger el historial, el DNI de un socio existente no se modifica desde este formulario."
                            : null,
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
    final Map<String, dynamic> hijo = _hijos[index];

    // Si todavía no fue guardado en Firestore, alcanza con quitarlo de la lista.
    if (!hijo.containsKey('id_existente')) {
      setState(() => _hijos.removeAt(index));
      return;
    }

    final motivoCtrl = TextEditingController();
    String? errorMotivo;

    final String? motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Quitar integrante de la familia"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${hijo['apellido'] ?? ''}, ${hijo['nombre'] ?? ''}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "DNI: ${hijo['dni'] ?? hijo['id_existente']}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "El integrante no se borrará definitivamente. Quedará en la papelera y podrá restaurarse.",
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Motivo de la baja *",
                        hintText: "Ej: dejó la actividad, registro duplicado...",
                        border: const OutlineInputBorder(),
                        errorText: errorMotivo,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final valor = motivoCtrl.text.trim();
                    if (valor.isEmpty) {
                      setStateDialog(() {
                        errorMotivo = "Ingresá un motivo para continuar";
                      });
                      return;
                    }
                    Navigator.pop(ctx, valor);
                  },
                  child: const Text("DAR DE BAJA"),
                ),
              ],
            );
          },
        );
      },
    );

    motivoCtrl.dispose();

    if (motivo == null || motivo.trim().isEmpty) return;

    final idExistente = hijo['id_existente'].toString();
    setState(() {
      _bajasIntegrantesPendientes[idExistente] = motivo.trim();
      _hijos.removeAt(index);
    });
  }

  dynamic _normalizarValorAuditoria(dynamic valor) {
    if (valor is Timestamp) {
      return valor.toDate().toIso8601String();
    }

    if (valor is List) {
      final lista = valor.map((e) => e.toString().trim()).toList();
      lista.sort();
      return lista;
    }

    if (valor is Map) {
      final resultado = <String, dynamic>{};
      valor.forEach((key, value) {
        resultado[key.toString()] = _normalizarValorAuditoria(value);
      });
      return resultado;
    }

    return valor;
  }

  Map<String, dynamic> _extraerDatosAuditables(Map<String, dynamic> data) {
    const campos = <String>[
      'nombre',
      'apellido',
      'dni',
      'telefono',
      'direccion',
      'email',
      'nro_socio',
      'actividades',
      'actividad',
      'categoria_deporte',
      'foto_url',
      'familia_id',
      'es_titular',
    ];

    final resultado = <String, dynamic>{};

    for (final campo in campos) {
      if (data.containsKey(campo)) {
        resultado[campo] = _normalizarValorAuditoria(data[campo]);
      }
    }

    return resultado;
  }

  Map<String, dynamic> _calcularCambios(
    Map<String, dynamic> anterior,
    Map<String, dynamic> nuevo,
  ) {
    final cambios = <String, dynamic>{};
    final campos = <String>{...anterior.keys, ...nuevo.keys};

    for (final campo in campos) {
      final antes = _normalizarValorAuditoria(anterior[campo]);
      final despues = _normalizarValorAuditoria(nuevo[campo]);

      if (antes.toString() != despues.toString()) {
        cambios[campo] = {
          'anterior': antes,
          'nuevo': despues,
        };
      }
    }

    return cambios;
  }

  void _agregarAuditoriaAlBatch({
    required WriteBatch batch,
    required FirebaseFirestore db,
    required String accion,
    required String socioId,
    required Map<String, dynamic> datosSocio,
    Map<String, dynamic>? cambios,
    String? detalle,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    batch.set(db.collection('auditoria_socios').doc(), {
      'accion': accion,
      'socio_id': socioId,
      'dni': (datosSocio['dni'] ?? socioId).toString(),
      'nombre': (datosSocio['nombre'] ?? '').toString(),
      'apellido': (datosSocio['apellido'] ?? '').toString(),
      'familia_id': (datosSocio['familia_id'] ?? '').toString(),
      'es_titular': datosSocio['es_titular'] == true,
      'usuario_email': user?.email ?? 'Desconocido',
      'usuario_uid': user?.uid ?? '',
      'fecha': FieldValue.serverTimestamp(),
      if (cambios != null && cambios.isNotEmpty) 'cambios': cambios,
      if (detalle != null && detalle.trim().isNotEmpty)
        'detalle': detalle.trim(),
    });
  }

  String _mensajeDniExistente(
    String dni,
    Map<String, dynamic> data,
  ) {
    final nombre =
        "${data['apellido'] ?? ''}, ${data['nombre'] ?? ''}".trim();
    final eliminado = data['eliminado'] == true;

    if (eliminado) {
      return "El DNI $dni pertenece a $nombre, que está en la papelera. "
          "Restaurá ese socio en lugar de crear uno nuevo.";
    }

    return "Ya existe un socio con el DNI $dni"
        "${nombre.isNotEmpty ? ': $nombre' : ''}. "
        "No se guardó ningún cambio.";
  }

  Future<String?> _validarDnisAntesDeGuardar() async {
    final db = FirebaseFirestore.instance;
    final dniTitular = _dniTitularCtrl.text.trim();

    final propuestas = <Map<String, String>>[
      {'dni': dniTitular, 'tipo': 'Titular'},
      ..._hijos.map(
        (hijo) => {
          'dni': (hijo['dni'] ?? '').toString().trim(),
          'tipo': 'Integrante',
        },
      ),
    ];

    final idsPropios = <String>{
      if (_titularDocIdOriginal != null) _titularDocIdOriginal!,
      ..._integrantesOriginales.keys,
    };

    final vistos = <String>{};

    for (final item in propuestas) {
      final dni = item['dni'] ?? '';
      final tipo = item['tipo'] ?? 'Socio';
      final esDniPropioExistente = idsPropios.contains(dni);

      if (dni.isEmpty) {
        return "$tipo sin DNI. Todos los integrantes deben tener documento.";
      }

      // Los registros históricos pueden tener documentos viejos cargados con
      // formatos imperfectos. No bloqueamos una edición existente por eso,
      // pero sí impedimos crear NUEVOS socios con un DNI inválido.
      if (!esDniPropioExistente && !RegExp(r'^\d+$').hasMatch(dni)) {
        return "El DNI $dni no es válido. Ingresá únicamente números.";
      }

      if (!esDniPropioExistente && RegExp(r'^0+$').hasMatch(dni)) {
        return "El DNI $dni no es válido. No se permite utilizar un documento compuesto solo por ceros.";
      }

      if (!vistos.add(dni)) {
        return "El DNI $dni está repetido dentro de esta misma familia. "
            "Cada socio debe tener un DNI único.";
      }

      if (_bajasIntegrantesPendientes.containsKey(dni)) {
        return "El DNI $dni pertenece a un integrante que acabás de marcar para baja. "
            "Guardá la familia primero antes de volver a utilizar ese documento.";
      }
    }

    for (final item in propuestas) {
      final dni = item['dni']!;

      final docPorId = await db.collection('socios').doc(dni).get();
      if (docPorId.exists && !idsPropios.contains(docPorId.id)) {
        final data = docPorId.data() ?? <String, dynamic>{};
        return _mensajeDniExistente(dni, data);
      }

      final queryPorCampo = await db
          .collection('socios')
          .where('dni', isEqualTo: dni)
          .limit(5)
          .get();

      for (final doc in queryPorCampo.docs) {
        if (!idsPropios.contains(doc.id)) {
          return _mensajeDniExistente(dni, doc.data());
        }
      }
    }

    return null;
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
      final errorDni = await _validarDnisAntesDeGuardar();

      if (errorDni != null) {
        if (mounted) {
          setState(() => _cargando = false);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text("DNI no disponible"),
                ],
              ),
              content: Text(errorDni),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("ENTENDIDO"),
                ),
              ],
            ),
          );
        }
        return;
      }

      final db = FirebaseFirestore.instance;
      final userAdmin = FirebaseAuth.instance.currentUser;
      final String adminEmail = userAdmin?.email ?? 'Desconocido';
      final String adminUid = userAdmin?.uid ?? '';

      final bool esEdicion = widget.familiaIdEditar != null;
      final String dniTitular = _dniTitularCtrl.text.trim();
      final String titularDocId = esEdicion
          ? (_titularDocIdOriginal ?? dniTitular)
          : dniTitular;
      final String familiaId = titularDocId;

      final WriteBatch batch = db.batch();

      final String actividadResumenTitular = _actividadesTitular.isEmpty
          ? 'Ninguna'
          : _actividadesTitular.join(", ");

      final Map<String, dynamic> dataTitular = {
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
        'eliminado': false,
      };

      if (_fotoTitularCtrl.text.trim().isNotEmpty) {
        dataTitular['foto_url'] = _fotoTitularCtrl.text.trim();
      } else if (esEdicion &&
          (_titularOriginal?['foto_url'] ?? '').toString().trim().isNotEmpty) {
        // Mantiene la foto existente si el widget no devolvió una nueva URL.
        dataTitular['foto_url'] = _titularOriginal!['foto_url'];
      }

      String ultimoMesPagoStr = "";

      if (!esEdicion) {
        final DateTime ayer = DateTime.now().subtract(const Duration(days: 30));
        ultimoMesPagoStr =
            "${ayer.year}-${ayer.month.toString().padLeft(2, '0')}";

        dataTitular['al_dia'] = false;
        dataTitular['ultimo_mes_pago'] = ultimoMesPagoStr;
        dataTitular['creado_el'] = FieldValue.serverTimestamp();
        dataTitular['creado_por_email'] = adminEmail;
        dataTitular['creado_por_uid'] = adminUid;

        _agregarAuditoriaAlBatch(
          batch: batch,
          db: db,
          accion: 'alta',
          socioId: titularDocId,
          datosSocio: dataTitular,
          detalle: 'Alta de titular / familia',
        );
      } else {
        dataTitular['modificado_en'] = FieldValue.serverTimestamp();
        dataTitular['modificado_por_email'] = adminEmail;
        dataTitular['modificado_por_uid'] = adminUid;

        final antes = _extraerDatosAuditables(
          _titularOriginal ?? <String, dynamic>{},
        );
        final despues = _extraerDatosAuditables(dataTitular);
        final cambios = _calcularCambios(antes, despues);

        if (cambios.isNotEmpty) {
          _agregarAuditoriaAlBatch(
            batch: batch,
            db: db,
            accion: 'modificacion',
            socioId: titularDocId,
            datosSocio: dataTitular,
            cambios: cambios,
            detalle: 'Edición de datos del titular',
          );
        }
      }

      batch.set(
        db.collection('socios').doc(titularDocId),
        dataTitular,
        SetOptions(merge: true),
      );

      for (final hijo in _hijos) {
        final String dniHijo = hijo['dni'].toString().trim();
        if (dniHijo.isEmpty) continue;

        final String idExistente =
            (hijo['id_existente'] ?? '').toString().trim();
        final bool esExistente = idExistente.isNotEmpty;
        final String docIdHijo = esExistente ? idExistente : dniHijo;

        final List<String> actsHijo = List<String>.from(
          hijo['actividades'] ?? const <String>[],
        );

        final String actividadResumenHijo = actsHijo.isEmpty
            ? 'Ninguna'
            : actsHijo.join(", ");

        final String catHijo =
            (hijo['categoria_deporte'] ?? '').toString().trim();

        final Map<String, dynamic> dataHijo = {
          'nombre': (hijo['nombre'] ?? '').toString().trim(),
          'apellido': (hijo['apellido'] ?? '').toString().trim(),
          'dni': dniHijo,
          'nro_socio': dniHijo,
          'actividades': actsHijo,
          'actividad': actividadResumenHijo,
          'categoria_deporte': catHijo,
          'familia_id': familiaId,
          'es_titular': false,
          'busqueda':
              "${hijo['apellido']} ${hijo['nombre']} $dniHijo $catHijo"
                  .toLowerCase(),
          'eliminado': false,
        };

        final String fotoUrlHijo =
            (hijo['foto_url'] ?? '').toString().trim();
        if (fotoUrlHijo.isNotEmpty) {
          dataHijo['foto_url'] = fotoUrlHijo;
        }

        if (!esExistente) {
          if (!esEdicion) {
            dataHijo['ultimo_mes_pago'] = ultimoMesPagoStr;
            dataHijo['al_dia'] = false;
          }

          dataHijo['creado_el'] = FieldValue.serverTimestamp();
          dataHijo['creado_por_email'] = adminEmail;
          dataHijo['creado_por_uid'] = adminUid;

          _agregarAuditoriaAlBatch(
            batch: batch,
            db: db,
            accion: 'alta',
            socioId: docIdHijo,
            datosSocio: dataHijo,
            detalle: esEdicion
                ? 'Nuevo integrante agregado a una familia existente'
                : 'Alta de integrante junto con la familia',
          );
        } else {
          dataHijo['modificado_en'] = FieldValue.serverTimestamp();
          dataHijo['modificado_por_email'] = adminEmail;
          dataHijo['modificado_por_uid'] = adminUid;

          final original =
              _integrantesOriginales[idExistente] ?? <String, dynamic>{};

          final cambios = _calcularCambios(
            _extraerDatosAuditables(original),
            _extraerDatosAuditables(dataHijo),
          );

          if (cambios.isNotEmpty) {
            _agregarAuditoriaAlBatch(
              batch: batch,
              db: db,
              accion: 'modificacion',
              socioId: docIdHijo,
              datosSocio: dataHijo,
              cambios: cambios,
              detalle: 'Edición de datos del integrante',
            );
          }
        }

        batch.set(
          db.collection('socios').doc(docIdHijo),
          dataHijo,
          SetOptions(merge: true),
        );
      }

      for (final entry in _bajasIntegrantesPendientes.entries) {
        final String docId = entry.key;
        final String motivo = entry.value;
        final original =
            _integrantesOriginales[docId] ?? <String, dynamic>{};

        final String operacionId =
            '${DateTime.now().millisecondsSinceEpoch}_$docId';

        batch.update(db.collection('socios').doc(docId), {
          'eliminado': true,
          'estado_baja': 'eliminado',
          'eliminado_en': FieldValue.serverTimestamp(),
          'eliminado_por_email': adminEmail,
          'eliminado_por_uid': adminUid,
          'motivo_eliminacion': motivo,
          'baja_operacion_id': operacionId,
        });

        _agregarAuditoriaAlBatch(
          batch: batch,
          db: db,
          accion: 'baja',
          socioId: docId,
          datosSocio: original,
          cambios: {
            'eliminado': {
              'anterior': original['eliminado'] == true,
              'nuevo': true,
            },
          },
          detalle: motivo,
        );
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Familia guardada correctamente."),
            backgroundColor: Colors.green,
          ),
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
      if (mounted) {
        setState(() => _cargando = false);
      }
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
