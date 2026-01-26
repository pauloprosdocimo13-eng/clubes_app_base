import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';
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
      final query = await FirebaseFirestore.instance
          .collection('socios')
          .where('dni', isEqualTo: dni)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final datos = doc.data();
        final id = doc.id; // Este es el ID del doc (DNI generalmente)

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaDashboardSocio(
                config: widget.config,
                socioId: id,
                datosSocio: datos,
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
    } catch (e) {
      setState(() {
        _error = "Error de conexión: $e";
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Portal de Socios"), backgroundColor: widget.config.colorPrimario),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge, size: 80, color: widget.config.colorPrimario.withOpacity(0.5)),
              const SizedBox(height: 20),
              Text(
                "¡Bienvenido Socio!",
                style: TextStyle(fontSize: 24, color: widget.config.colorPrimario, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ingresá tu DNI para ver tu carnet y estado de cuenta familiar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
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
                    backgroundColor: widget.config.colorPrimario,
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