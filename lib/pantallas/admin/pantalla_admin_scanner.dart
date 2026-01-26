import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

class PantallaAdminScanner extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminScanner({super.key, required this.config});

  @override
  State<PantallaAdminScanner> createState() => _PantallaAdminScannerState();
}

class _PantallaAdminScannerState extends State<PantallaAdminScanner> {
  bool _procesando = false; // Bloqueo para no leer el mismo QR 20 veces seguidas
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Lógica para validar el socio en Firebase
  Future<void> _validarIngreso(String socioId) async {
    setState(() => _procesando = true);

    try {
      // 1. Buscamos el documento por su ID (que viene en el QR)
      final doc = await FirebaseFirestore.instance.collection('socios').doc(socioId).get();

      if (!doc.exists) {
        _mostrarAlerta(
          esValido: false,
          titulo: "QR NO VÁLIDO",
          mensaje: "El código escaneado no pertenece a un socio activo.",
        );
        return;
      }

      final data = doc.data()!;
      final String nombre = "${data['nombre']} ${data['apellido']}";
      final String estado = data['estado'] ?? 'Deudor';

      // 2. Validamos si está al día
      // Aceptamos "Al día", "al dia", "AL DIA", etc.
      final bool accesoPermitido = estado.toLowerCase().contains('al d') || estado.toLowerCase() == 'al día';

      // 3. Mostramos el resultado
      _mostrarAlerta(
        esValido: accesoPermitido,
        titulo: accesoPermitido ? "ACCESO PERMITIDO" : "ACCESO DENEGADO",
        mensaje: "Socio: $nombre\nEstado: $estado",
      );

    } catch (e) {
      _mostrarAlerta(
        esValido: false,
        titulo: "ERROR",
        mensaje: "Error de conexión al validar socio.",
      );
    }
  }

  void _mostrarAlerta({required bool esValido, required String titulo, required String mensaje}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga a tocar el botón
      builder: (context) => AlertDialog(
        backgroundColor: esValido ? Colors.green[50] : Colors.red[50],
        title: Row(
          children: [
            Icon(esValido ? Icons.check_circle : Icons.cancel, color: esValido ? Colors.green : Colors.red, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: TextStyle(color: esValido ? Colors.green[900] : Colors.red[900], fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text(mensaje, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esValido ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Esperamos un poquito antes de volver a escanear para no leer el mismo QR instantáneamente
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) setState(() => _procesando = false);
              });
            },
            child: const Text("ACEPTAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escanear Ingreso"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_procesando) return;

                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _validarIngreso(barcode.rawValue!);
                    break; // Solo leemos el primero que encontramos
                  }
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            width: double.infinity,
            child: const Text(
              "Apunta al QR del carnet digital",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          )
        ],
      ),
    );
  }
}