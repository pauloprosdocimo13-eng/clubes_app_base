import 'package:flutter/material.dart';

class BotonMenu extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color colorPrimario;
  final VoidCallback alPresionar;

  const BotonMenu({
    super.key,
    required this.titulo,
    required this.icono,
    required this.colorPrimario,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. El Círculo con el Icono
        GestureDetector(
          onTap: alPresionar,
          child: Container(
            // CAMBIO: Achicamos de 70 a 60 para que no desborde en celulares chicos
            width: 60, 
            height: 60,
            decoration: BoxDecoration(
              color: colorPrimario, // Color del club
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2), // .withOpacity es más compatible que withValues
                  blurRadius: 5,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Icon(
              icono,
              color: Colors.white,
              size: 28, // Achicamos un pelín el icono también
            ),
          ),
        ),
        
        // CAMBIO: Menos espacio entre círculo y texto (de 10 a 6)
        const SizedBox(height: 6), 

        // 2. El Título abajo
        // CAMBIO: Agregamos Padding y FittedBox para que el texto nunca desborde
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown, // Si el texto es largo, se achica la letra
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 13, // Un punto menos de fuente por las dudas
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}