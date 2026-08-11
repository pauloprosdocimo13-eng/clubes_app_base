import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
import '../../servicios/servicio_actividades.dart';

class PantallaAdminConfigClub extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminConfigClub({super.key, required this.config});

  @override
  State<PantallaAdminConfigClub> createState() => _PantallaAdminConfigClubState();
}

class _PantallaAdminConfigClubState extends State<PantallaAdminConfigClub>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _cargando = true;
  bool _guardando = false;

  bool _multiActividad = false;
  List<ActividadClub> _actividades = [];
  List<ContactoClub> _contactos = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final docGeneral = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('general')
          .get();

      if (docGeneral.exists && docGeneral.data() != null) {
        _multiActividad = docGeneral.data()!['activar_multi_actividad'] ?? false;
      }

      _actividades = await ServicioActividades.cargarActividades();
      _contactos = await ServicioActividades.cargarContactos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando configuración: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarTodo() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('configuracion').doc('general').set(
        {
          'activar_multi_actividad': _multiActividad,
          'prefijo_notificaciones': widget.config.prefijoColeccion,
        },
        SetOptions(merge: true),
      );
      await ServicioActividades.guardarActividades(_actividades);
      await ServicioActividades.guardarContactos(_contactos);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _editarActividad({ActividadClub? actividad, int? index}) {
    final nombreCtrl = TextEditingController(text: actividad?.nombre ?? '');
    final horariosCtrl = TextEditingController(text: actividad?.horarios ?? '');
    final arancelCtrl = TextEditingController(text: actividad?.arancel ?? '');
    var iconoSel = actividad?.icono ?? 'fitness_center';
    var colorSel = actividad?.colorHex ?? '#607D8B';
    var esFutbol = actividad?.esFutbol ?? false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(actividad == null ? 'Nueva actividad' : 'Editar actividad'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: horariosCtrl,
                  decoration: const InputDecoration(labelText: 'Horarios'),
                  maxLines: 3,
                ),
                TextField(
                  controller: arancelCtrl,
                  decoration: const InputDecoration(labelText: 'Arancel'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: iconoSel,
                  decoration: const InputDecoration(labelText: 'Icono'),
                  items: ServicioActividades.nombresIconosDisponibles()
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setDialog(() => iconoSel = v ?? iconoSel),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Color (#RRGGBB)'),
                  controller: TextEditingController(text: colorSel),
                  onChanged: (v) => colorSel = v,
                ),
                SwitchListTile(
                  title: const Text('Es sección de Fútbol'),
                  value: esFutbol,
                  onChanged: (v) => setDialog(() => esFutbol = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final nueva = ActividadClub(
                  nombre: nombreCtrl.text.trim(),
                  horarios: horariosCtrl.text.trim(),
                  arancel: arancelCtrl.text.trim(),
                  icono: iconoSel,
                  colorHex: colorSel,
                  esFutbol: esFutbol,
                );
                setState(() {
                  if (index != null) {
                    _actividades[index] = nueva;
                  } else {
                    _actividades.add(nueva);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _editarContacto({ContactoClub? contacto, int? index}) {
    final tituloCtrl = TextEditingController(text: contacto?.titulo ?? '');
    final subtituloCtrl = TextEditingController(text: contacto?.subtitulo ?? '');
    final urlCtrl = TextEditingController(text: contacto?.url ?? '');
    var iconoSel = contacto?.icono ?? 'link';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(contacto == null ? 'Nuevo contacto' : 'Editar contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: subtituloCtrl, decoration: const InputDecoration(labelText: 'Subtítulo')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL / Link')),
              DropdownButtonFormField<String>(
                value: iconoSel,
                decoration: const InputDecoration(labelText: 'Icono'),
                items: ServicioActividades.nombresIconosDisponibles()
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (v) => setDialog(() => iconoSel = v ?? iconoSel),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final nuevo = ContactoClub(
                  titulo: tituloCtrl.text.trim(),
                  subtitulo: subtituloCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                  icono: iconoSel,
                );
                setState(() {
                  if (index != null) {
                    _contactos[index] = nuevo;
                  } else {
                    _contactos.add(nuevo);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Club'),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Actividades'),
            Tab(text: 'Contacto'),
          ],
        ),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _guardarTodo),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SwitchListTile(
                  title: const Text('Portal multi-actividad'),
                  subtitle: const Text('Muestra el portal institucional al iniciar'),
                  value: _multiActividad,
                  onChanged: (v) => setState(() => _multiActividad = v),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _listaActividades(),
                      _listaContactos(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.config.colorPrimario,
        onPressed: () {
          if (_tabs.index == 0) {
            _editarActividad();
          } else {
            _editarContacto();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _listaActividades() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _actividades.length,
      itemBuilder: (context, index) {
        final act = _actividades[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: act.color.withOpacity(0.15),
              child: Icon(act.iconData, color: act.color),
            ),
            title: Text(act.nombre),
            subtitle: Text('${act.horarios}\n${act.arancel}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarActividad(actividad: act, index: index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _actividades.removeAt(index)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _listaContactos() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contactos.length,
      itemBuilder: (context, index) {
        final c = _contactos[index];
        return Card(
          child: ListTile(
            leading: Icon(c.iconData, color: c.color),
            title: Text(c.titulo),
            subtitle: Text('${c.subtitulo}\n${c.url}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarContacto(contacto: c, index: index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _contactos.removeAt(index)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
