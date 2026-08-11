import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configuracion/configuracion_app.dart';
import '../servicios/servicio_actividades.dart';
import '../servicios/servicio_aviso_entrada.dart';
import '../servicios/servicio_version.dart';

import 'pantalla_seleccion.dart';
import 'pantalla_noticias.dart';
import 'pantalla_reservas.dart';
import 'socios/pantalla_acceso_socio.dart';
import 'pantalla_login_admin.dart';
import '../widgets/banner_publicidad.dart'; // IMPORTAMOS EL BANNER DE PUBLICIDAD

class PantallaSeleccionActividad extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaSeleccionActividad({super.key, required this.config});

  @override
  State<PantallaSeleccionActividad> createState() => _PantallaSeleccionActividadState();
}

class _PantallaSeleccionActividadState extends State<PantallaSeleccionActividad> {
  List<ActividadClub> _actividades = [];
  List<ContactoClub> _contactos = [];
  bool _cargandoPortal = true;
  bool _mostrarPublicidad = true; // Variable para gestionar la publicidad

  @override
  void initState() {
    super.initState();
    _inicializarPortal();
  }

  Future<void> _inicializarPortal() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ServicioVersion.mostrarBloqueoSiCorresponde(context);
      if (mounted) {
        await ServicioAvisoEntrada.mostrarSiCorresponde(context, widget.config);
      }
    });

    try {
      // 1. Cargamos actividades y contactos
      final actividades = await ServicioActividades.cargarActividades();
      final contactos = await ServicioActividades.cargarContactos();
      
      // 2. Verificamos si la publicidad está activa en Firebase
      bool publicidadActiva = true;
      try {
        final docConfig = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
        if (docConfig.exists && docConfig.data() != null) {
          final data = docConfig.data() as Map<String, dynamic>;
          final modulos = data['modulos_activos'] as Map<String, dynamic>? ?? {};
          publicidadActiva = modulos['publicidad'] ?? true;
        }
      } catch (e) {
        print("Error leyendo config de publicidad: $e");
      }

      if (mounted) {
        setState(() {
          _actividades = actividades;
          _contactos = contactos;
          _mostrarPublicidad = publicidadActiva;
          _cargandoPortal = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoPortal = false);
    }
  }

  // --- NAVEGACIÓN Y FUNCIONES ---

  void _irAFutbol(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaSeleccion(config: widget.config)));
  }

  void _irANoticias(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text("Noticias del Club"),
            backgroundColor: widget.config.colorPrimario,
            foregroundColor: Colors.white,
          ),
          body: PantallaNoticias(config: widget.config),
        ),
      ),
    );
  }

  void _irAReservas(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaReservas(config: widget.config)));
  }

  void _irAAccesoSocios(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaAccesoSocio(config: widget.config)));
  }

  Future<void> _abrirLink(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir el enlace.")),
        );
      }
    }
  }

  // --- PANELES EMERGENTES (BOTTOM SHEETS) ---

  void _mostrarInfoActividad(BuildContext context, ActividadClub actividad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: actividad.color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(actividad.iconData, color: actividad.color, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      actividad.nombre.toUpperCase(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              _FilaInfoInfo(icono: Icons.calendar_month, titulo: 'Días y Horarios', valor: actividad.horarios, colorIcono: Colors.blue),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
              _FilaInfoInfo(icono: Icons.payments, titulo: 'Arancel', valor: actividad.arancel, colorIcono: Colors.green),
              const SizedBox(height: 30),
              if (actividad.esFutbol)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.colorPrimario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _irAFutbol(context);
                    },
                    child: const Text('INGRESAR A LA SECCIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _mostrarPanelContacto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              const Text('Contacto y Redes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              ..._contactos.map((c) => Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(backgroundColor: c.color, child: Icon(c.iconData, color: Colors.white)),
                        title: Text(c.titulo),
                        subtitle: Text(c.subtitulo),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _abrirLink(context, c.url),
                      ),
                      const Divider(),
                    ],
                  )),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoPortal) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(child: CircularProgressIndicator(color: widget.config.colorPrimario)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. CABECERA INSTITUCIONAL CON BOTÓN ADMIN
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.config.colorPrimario,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(color: widget.config.colorPrimario.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage(widget.config.rutaLogo),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      widget.config.nombreApp.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)),
                      child: const Text("Portal Institucional", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              // BOTÓN DE ACCESO ADMIN (Salvavidas sutil)
              Positioned(
                top: 50,
                right: 15,
                child: IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.white24, // Sutil para que pase desapercibido
                  ),
                  onPressed: () {
                    // Navegamos directo al Login de Admin
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaLoginAdmin(config: widget.config),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 2. CONTENEDOR PRINCIPAL CON SCROLL
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                
                // --- SECCIÓN: BANNER PUBLICIDAD AL TOPE ---
                if (!_cargandoPortal && _mostrarPublicidad)
                  Container(
                    width: double.infinity,
                    height: 180,
                    padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
                    child: const BannerPublicidad(),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECCIÓN: NOVEDADES ---
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 10),
                        child: Text("Novedades", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                      ),
                      _TarjetaNoticias(config: widget.config, alPresionar: () => _irANoticias(context)),
                      const SizedBox(height: 25),

                      // --- SECCIÓN: ACTIVIDADES DEL CLUB ---
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 15),
                        child: Text("Actividades del Club", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
                        ),
                        itemCount: _actividades.length,
                        itemBuilder: (context, index) {
                          final act = _actividades[index];
                          return _TarjetaIgualitaria(
                            nombre: act.nombre,
                            icono: act.iconData,
                            colorPrincipal: act.color,
                            alPresionar: () => _mostrarInfoActividad(context, act),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // --- BLOQUE OSCURO INFERIOR (SERVICIOS Y CONTACTO) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "SERVICIOS AL SOCIO",
                        style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal[800],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          minimumSize: const Size(double.infinity, 55),
                        ),
                        onPressed: () => _irAReservas(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month),
                            SizedBox(width: 10),
                            Text("ALQUILER DE CANCHAS / SALÓN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          minimumSize: const Size(double.infinity, 55),
                        ),
                        onPressed: () => _irAAccesoSocios(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge),
                            SizedBox(width: 10),
                            Text("CARNET DIGITAL DE SOCIO", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          minimumSize: const Size(double.infinity, 55),
                        ),
                        icon: const Icon(Icons.contact_support_outlined),
                        label: const Text("CONTACTO Y REDES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        onPressed: () => _mostrarPanelContacto(context),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES PARA LA INTERFAZ ---

class _FilaInfoInfo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color colorIcono;

  const _FilaInfoInfo({required this.icono, required this.titulo, required this.valor, required this.colorIcono});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: colorIcono, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaNoticias extends StatelessWidget {
  final ConfiguracionApp config;
  final VoidCallback alPresionar;

  const _TarjetaNoticias({required this.config, required this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: alPresionar,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [config.colorPrimario, Colors.black87],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.newspaper, color: Colors.white, size: 35),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Noticias del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 5),
                    Text("Enterate de las últimas novedades y eventos de la institución.", style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaIgualitaria extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final Color colorPrincipal;
  final VoidCallback alPresionar;

  const _TarjetaIgualitaria({required this.nombre, required this.icono, required this.colorPrincipal, required this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: alPresionar,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [Colors.white, colorPrincipal.withOpacity(0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colorPrincipal.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icono, color: colorPrincipal, size: 32),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800], height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}