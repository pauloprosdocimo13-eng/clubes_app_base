import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../configuracion/configuracion_app.dart';
import '../../tusede/servicios/contexto_club.dart';
import '../../tusede/servicios/servicio_datos_club.dart';

class PantallaAdminPagosConfig extends StatefulWidget {
  final ConfiguracionApp config;

  const PantallaAdminPagosConfig({
    super.key,
    required this.config,
  });

  @override
  State<PantallaAdminPagosConfig> createState() =>
      _PantallaAdminPagosConfigState();
}

class _PantallaAdminPagosConfigState extends State<PantallaAdminPagosConfig> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _cbuController = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _linkController.dispose();
    _cbuController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    if (mounted) {
      setState(() => _cargando = true);
    }

    try {
      final doc = await ServicioDatosClub.pagosConfiguracion.get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _linkController.text = (data['link_mp'] ?? '').toString();
        _cbuController.text = (data['alias_cbu'] ?? '').toString();
      } else {
        _linkController.clear();
        _cbuController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando configuración de pagos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (_guardando) return;

    setState(() => _guardando = true);

    try {
      final user = ServicioDatosClub.usuarioAuthActual;

      await ServicioDatosClub.pagosConfiguracion.set(
        <String, dynamic>{
          'link_mp': _linkController.text.trim(),
          'alias_cbu': _cbuController.text.trim(),
          'actualizado_el': FieldValue.serverTimestamp(),
          'actualizado_por_email': user?.email ?? 'Desconocido',
          'actualizado_por_uid': user?.uid ?? '',
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Configuración de pagos guardada en '
            '${ServicioDatosClub.origenDescripcion}!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando configuración: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ContextoClub.colorPrimario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Pagos'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Club: ${ContextoClub.nombreClub}\n'
                          'Datos: ${ServicioDatosClub.origenDescripcion}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Icon(
                  Icons.payment,
                  size: 80,
                  color: color,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Datos de Cobro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Estos datos aparecerán en el Carnet Digital de los socios '
                  'al momento de querer realizar un pago.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // LINK MERCADO PAGO
                TextField(
                  controller: _linkController,
                  enabled: !_guardando,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Link de Mercado Pago (URL)',
                    hintText: 'https://mpago.la/...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Generá un link de cobro general en tu cuenta de MP '
                  'y pegalo acá.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                // ALIAS / CBU
                TextField(
                  controller: _cbuController,
                  enabled: !_guardando,
                  decoration: const InputDecoration(
                    labelText: 'Alias / CBU (Opcional)',
                    hintText: 'CLUB.FUTBOL.MP',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Para aquellos socios que prefieran hacer '
                  'transferencia bancaria.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _guardando ? null : _guardarConfiguracion,
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'GUARDAR CAMBIOS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
