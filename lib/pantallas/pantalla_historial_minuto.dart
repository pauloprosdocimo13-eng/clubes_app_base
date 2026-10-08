import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../configuracion/configuracion_app.dart';
import '../tusede/servicios/contexto_club.dart';
import '../tusede/servicios/servicio_contenido_publico.dart';
import '../tusede/servicios/servicio_datos_club.dart';

class PantallaHistorialMinuto extends StatelessWidget {
  final ConfiguracionApp config;
  final String deporteId;

  const PantallaHistorialMinuto({
    super.key,
    required this.config,
    required this.deporteId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Partidos'),
        backgroundColor: config.colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: ServicioDatosClub.usaTuSedeCentral
          ? _construirCentral()
          : _construirLegacy(),
    );
  }

  // ============================================================
  // TUSEDE CENTRAL
  // ============================================================

  Widget _construirCentral() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ServicioContenidoPublico.cargarHistorial(deporteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No se pudo leer el historial: '
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final partidos = snapshot.data ?? <Map<String, dynamic>>[];

        return _construirLista(partidos);
      },
    );
  }

  // ============================================================
  // FIREBASE LEGACY
  // ============================================================

  Widget _construirLegacy() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ServicioDatosClub.historialPartidos
          .where('deporte_id', isEqualTo: deporteId)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudo leer el historial: '
              '${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final partidos = snapshot.data!.docs.map((doc) => doc.data()).toList();

        return _construirLista(partidos);
      },
    );
  }

  // ============================================================
  // LISTA COMPARTIDA
  // ============================================================

  Widget _construirLista(List<Map<String, dynamic>> partidos) {
    if (partidos.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay partidos finalizados '
          'en el historial.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: partidos.length,
      itemBuilder: (context, index) {
        final data = partidos[index];

        return _construirPartido(data);
      },
    );
  }

  // ============================================================
  // TARJETA DE PARTIDO
  // ============================================================

  Widget _construirPartido(Map<String, dynamic> data) {
    final rival = (data['rival'] ?? 'Rival').toString();

    final golesLocal = _entero(data['goles_local']);

    final golesVisita = _entero(data['goles_visita']);

    final categoria = (data['categoria'] ?? '').toString();

    final estado = (data['estado'] ?? 'FINALIZADO').toString();

    final motivo = (data['motivo_suspension'] ?? '').toString().trim();

    final fecha = _fecha(data['fecha']);

    final eventos = _eventos(data['eventos']);

    final fechaTexto = fecha != null
        ? '${fecha.day}/${fecha.month} - '
              '${fecha.hour}:'
              '${fecha.minute.toString().padLeft(2, '0')}hs'
        : '';

    String textoCategoria = categoria;

    if (RegExp(r'^[0-9]+$').hasMatch(categoria)) {
      textoCategoria = 'Cat: $categoria';
    }

    final nombreClub =
        ServicioDatosClub.usaTuSedeCentral &&
            ContextoClub.nombreClub.trim().isNotEmpty
        ? ContextoClub.nombreClub.trim()
        : config.nombreApp;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(15),
        title: Column(
          children: [
            Text(
              '$fechaTexto - '
              '$textoCategoria',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nombreClub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: estado.toUpperCase() == 'SUSPENDIDO'
                        ? Colors.orange
                        : Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$golesLocal - '
                    '$golesVisita',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rival,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (estado.toUpperCase() == 'SUSPENDIDO')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  motivo.isNotEmpty
                      ? 'SUSPENDIDO: '
                            '$motivo'
                      : 'SUSPENDIDO',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        children: [
          const Divider(),
          if (eventos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Sin incidencias '
                'registradas.',
              ),
            )
          else
            ...eventos.map((evento) {
              final esLocal = evento['equipo'] == 'local';

              final tipo = (evento['tipo'] ?? '').toString();

              final minuto = (evento['minuto'] ?? '').toString();

              final detalle = (evento['detalle'] ?? '').toString();

              return ListTile(
                dense: true,
                leading: Icon(
                  tipo == 'gol' ? Icons.sports_soccer : Icons.style,
                  color: tipo == 'gol' ? Colors.black : _colorTarjeta(tipo),
                  size: 20,
                ),
                title: Text(
                  '$minuto - '
                  '${tipo.toUpperCase()}',
                ),
                subtitle: Text(detalle),
                trailing: Text(
                  esLocal ? 'LOCAL' : 'VISITA',
                  style: TextStyle(
                    color: esLocal ? config.colorPrimario : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERSIÓN DE DATOS
  // ============================================================

  int _entero(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  DateTime? _fecha(dynamic valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return null;
  }

  List<Map<String, dynamic>> _eventos(dynamic valor) {
    if (valor is! List) {
      return <Map<String, dynamic>>[];
    }

    final resultado = <Map<String, dynamic>>[];

    for (final item in valor) {
      if (item is Map) {
        resultado.add(Map<String, dynamic>.from(item));
      }
    }

    return resultado;
  }

  // ============================================================
  // COLORES DE TARJETAS
  // ============================================================

  Color _colorTarjeta(String tipo) {
    if (tipo == 'amarilla') {
      return Colors.yellow[700]!;
    }

    if (tipo == 'roja') {
      return Colors.red;
    }

    if (tipo == 'azul') {
      return Colors.blue;
    }

    return Colors.grey;
  }
}
