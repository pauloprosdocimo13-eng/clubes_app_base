import 'package:flutter/material.dart';
import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';
import '../../tusede/servicios/servicio_portal_socio.dart';
import 'pantalla_dashboard_socio.dart';

class PantallaAccesoSocio extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAccesoSocio({super.key, required this.config});

  @override
  State<PantallaAccesoSocio> createState() => _PantallaAccesoSocioState();
}

class _PantallaAccesoSocioState extends State<PantallaAccesoSocio> {
  final TextEditingController _dniController = TextEditingController();
  bool _cargando = false;
  String _error = '';

  Future<void> _buscarSocio() async {
    final dni = _dniController.text.trim();
    if (dni.isEmpty) {
      setState(() => _error = "Ingresá tu DNI");
      return;
    }

    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      final socio =
          await ServicioPortalSocio().buscarSocioPorDni(dni);

      if (socio != null) {
        final datos = socio.datos;
        final id = socio.id;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaDashboardSocio(
                config: widget.config,
                socioId: id,
                datosSocio: datos,
                datosPortal: socio.datosPortal,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _error = "No encontramos un socio con ese DNI.";
          _cargando = false;
        });
      }
    } on PortalSocioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "No pudimos abrir el carnet. Intentá nuevamente.";
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Portal de Socios · ${ContextoClub.nombreCorto}"),
        backgroundColor: ContextoClub.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge, size: 80, color: ContextoClub.colorPrimario.withOpacity(0.5)),
              const SizedBox(height: 20),
              Text(
                "¡Bienvenido Socio!",
                style: TextStyle(fontSize: 24, color: ContextoClub.colorPrimario, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ingresá tu DNI para ver tu carnet y estado de cuenta familiar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                "Club: ${ContextoClub.nombreClub}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "DNI (Sin puntos)",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_search),
                  errorText: _error.isNotEmpty ? _error : null,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ContextoClub.colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _cargando ? null : _buscarSocio,
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("INGRESAR"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}