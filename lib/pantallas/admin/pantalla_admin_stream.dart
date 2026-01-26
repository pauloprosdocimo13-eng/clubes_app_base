import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminStream extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminStream({super.key, required this.config});

  @override
  State<PantallaAdminStream> createState() => _PantallaAdminStreamState();
}

class _PantallaAdminStreamState extends State<PantallaAdminStream> {
  final _urlController = TextEditingController();
  bool _enVivo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('stream').get();
      if (doc.exists) {
        final data = doc.data()!;
        _urlController.text = data['url'] ?? '';
        _enVivo = data['en_vivo'] ?? false;
      }
    } catch (e) {
      print("Error cargando stream: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance.collection('configuracion').doc('stream').set({
        'url': _urlController.text.trim(),
        'en_vivo': _enVivo,
        'fecha_modificacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_enVivo ? "🔴 Transmisión ACTIVADA" : "⚪ Transmisión finalizada"),
            backgroundColor: _enVivo ? Colors.red : Colors.grey,
          ),
        );
        Navigator.pop(context);
      }
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
        title: const Text("Configurar Transmisión"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TARJETA DE ESTADO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _enVivo ? Colors.red[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _enVivo ? Colors.red : Colors.grey, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.live_tv, size: 50, color: _enVivo ? Colors.red : Colors.grey),
                const SizedBox(height: 10),
                Text(
                  _enVivo ? "¡ESTAMOS EN VIVO!" : "TRANSMISIÓN APAGADA",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _enVivo ? Colors.red[800] : Colors.grey[700]
                  ),
                ),
                Switch(
                  value: _enVivo,
                  activeColor: Colors.red,
                  onChanged: (v) => setState(() => _enVivo = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          const Text("Enlace de la Transmisión", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          const Text(
            "Pega aquí el link de YouTube, Facebook o Twitch donde se ve el partido.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: "URL del Video / Canal",
              hintText: "Ej: https://youtube.com/live/...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),

          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.config.colorPrimario,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _guardar,
            icon: const Icon(Icons.save),
            label: const Text("GUARDAR CONFIGURACIÓN"),
          ),
        ],
      ),
    );
  }
}