import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../configuracion/configuracion_app.dart';

void mostrarDialogoSugerencias(BuildContext context, ConfiguracionApp config) {
  final TextEditingController _sugerenciaCtrl = TextEditingController();
  bool _enviando = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                const SizedBox(width: 10),
                const Text(
                  "Buzón de Ideas",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "¿Qué le agregarías o cambiarías a la app? Te leemos para seguir mejorando.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _sugerenciaCtrl,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: "Escribí tu idea acá...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: config.colorPrimario,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _enviando ? null : () => Navigator.pop(ctx),
                child: const Text(
                  "CANCELAR",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.colorPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _enviando
                    ? null
                    : () async {
                        if (_sugerenciaCtrl.text.trim().isEmpty) return;

                        setStateDialog(() => _enviando = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;

                          // Guardamos en una colección nueva llamada 'sugerencias'
                          await FirebaseFirestore.instance
                              .collection('sugerencias')
                              .add({
                                'texto': _sugerenciaCtrl.text.trim(),
                                'fecha': FieldValue.serverTimestamp(),
                                'usuario_id': user?.uid ?? 'anonimo',
                                'usuario_email': user?.email ?? 'Sin email',
                                'leido':
                                    false, // Para que después vos te armes un panel y las marques como leídas
                              });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "¡Gracias! Tu idea fue enviada al equipo del club.",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => _enviando = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error al enviar. Intentá de nuevo.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: _enviando
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ENVIAR IDEA",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
