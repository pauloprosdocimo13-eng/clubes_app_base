import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminPagosConfig extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminPagosConfig({super.key, required this.config});

  @override
  State<PantallaAdminPagosConfig> createState() =>
      _PantallaAdminPagosConfigState();
}

class _PantallaAdminPagosConfigState extends State<PantallaAdminPagosConfig> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _cbuController = TextEditingController();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('pagos')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _linkController.text = data['link_mp'] ?? '';
        _cbuController.text = data['alias_cbu'] ?? '';
      }
    } catch (e) {
      print("Error cargando pagos: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('pagos')
          .set({
            'link_mp': _linkController.text.trim(),
            'alias_cbu': _cbuController.text.trim(),
            'actualizado_el': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Configuración de Pagos Guardada!"),
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
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Pagos"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.payment, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  "Datos de Cobro",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Estos datos aparecerán en el Carnet Digital de los socios al momento de querer realizar un pago.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // LINK MERCADO PAGO
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: "Link de Mercado Pago (URL)",
                    hintText: "https://mpago.la/...",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Generá un link de cobro general en tu cuenta de MP y pegalo acá.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 20),

                // ALIAS CBU (Opcional)
                TextField(
                  controller: _cbuController,
                  decoration: const InputDecoration(
                    labelText: "Alias / CBU (Opcional)",
                    hintText: "CLUB.FUTBOL.MP",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Para aquellos socios que prefieran hacer transferencia bancaria.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _guardarConfiguracion,
                    child: const Text(
                      "GUARDAR CAMBIOS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
