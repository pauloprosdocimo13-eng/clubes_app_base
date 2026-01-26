import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../configuracion/configuracion_app.dart';

class PantallaDetalleSorteo extends StatelessWidget {
  final ConfiguracionApp config;
  final String sorteoId;
  final Map<String, dynamic> dataSorteo;

  const PantallaDetalleSorteo({
    super.key,
    required this.config,
    required this.sorteoId,
    required this.dataSorteo,
  });

  Future<void> _reservarPorWhatsApp(BuildContext context, int numero) async {
    // 1. Buscamos el teléfono del club
    String telefono = "5491126440284"; // Fallback
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('general').get();
      if (doc.exists) {
        final data = doc.data()!;
        // Priorizamos teléfono de ventas, sino contacto
        telefono = data['telefono_ventas'] ?? data['telefono_contacto'] ?? telefono;
      }
    } catch (e) {
      print("Error obteniendo teléfono: $e");
    }

    // 2. Armamos el mensaje
    final titulo = dataSorteo['titulo'] ?? 'la Rifa';
    final precio = dataSorteo['precio'] ?? 0;
    final mensaje = "Hola! 👋 Quiero reservar el número *$numero* para: $titulo (Valor: \$$precio). ¿Cómo hago el pago?";

    // 3. Abrimos WhatsApp
    final urlString = "https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}";
    try {
      await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cantidad = dataSorteo['cantidad_numeros'] ?? 100;
    final titulo = dataSorteo['titulo'] ?? 'Sorteo';
    final premio = dataSorteo['premio'] ?? '';
    final precio = dataSorteo['precio'] ?? 0;

    // Escuchamos en tiempo real los números vendidos
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // INFO DEL SORTEO
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            child: Column(
              children: [
                Text("Premio: $premio", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 5),
                Text("Valor del número: \$$precio", style: TextStyle(color: config.colorPrimario, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                const Text("Tocá un número libre (VERDE) para pedirlo por WhatsApp", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          const Divider(height: 1),

          // GRILLA EN TIEMPO REAL
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('sorteos').doc(sorteoId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final liveData = snapshot.data!.data() as Map<String, dynamic>;
                final vendidos = List<int>.from(liveData['numeros_vendidos'] ?? []);

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cantidad,
                  itemBuilder: (context, index) {
                    final numero = index;
                    final estaVendido = vendidos.contains(numero);
                    final numeroStr = numero.toString().padLeft(cantidad > 100 ? 3 : 2, '0');

                    return InkWell(
                      onTap: estaVendido
                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este número ya está vendido 😢")))
                          : () => _reservarPorWhatsApp(context, numero),
                      child: Container(
                        decoration: BoxDecoration(
                          color: estaVendido ? Colors.red[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: estaVendido ? Colors.red : Colors.green,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: estaVendido
                              ? const Icon(Icons.close, color: Colors.red)
                              : Text(numeroStr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900])),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}