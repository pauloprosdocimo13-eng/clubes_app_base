import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../configuracion/configuracion_app.dart';

// --- IMPORTAMOS TODOS LOS MÓDULOS DE GESTIÓN ---
import '../admin/pantalla_admin_socios.dart';
import '../admin/pantalla_admin_precios.dart';
import '../admin/pantalla_admin_pagos_config.dart'; // Config CBU/Alias
import '../admin/pantalla_admin_espacios.dart';
import '../admin/pantalla_admin_calendario.dart';
import '../admin/pantalla_admin_tienda.dart';
import '../admin/pantalla_admin_sorteos.dart';
import '../pantalla_admin_noticias.dart';
import '../admin/pantalla_admin_aviso_entrada.dart';
import '../pantalla_admin_deportes.dart';
import '../admin/pantalla_admin_scanner.dart';
import '../admin/pantalla_admin_finanzas.dart';
import '../admin/pantalla_admin_asistencia.dart';
import '../admin/pantalla_admin_stream.dart';
import '../admin/votacion/pantalla_admin_votacion.dart';

class PantallaAdminDesktop extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminDesktop({super.key, required this.config});

  @override
  State<PantallaAdminDesktop> createState() => _PantallaAdminDesktopState();
}

class _PantallaAdminDesktopState extends State<PantallaAdminDesktop> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Listas para manejar la navegación
    final List<Widget> pantallas = [];
    final List<_MenuItemData> menuItems = [];

    // Función helper para agregar módulos
    void agregarModulo(Widget pantalla, IconData icon, String label) {
      pantallas.add(pantalla);
      menuItems.add(_MenuItemData(icon, label));
    }

    // --- 1. DASHBOARD PRINCIPAL ---
    agregarModulo(
      _DashboardResumen(config: widget.config),
      Icons.dashboard,
      'Inicio',
    );

    // --- 2. OPERATIVA DIARIA ---
    agregarModulo(
      PantallaAdminAsistencia(config: widget.config),
      Icons.checklist,
      'Tomar Asistencia',
    );
    agregarModulo(
      PantallaAdminCalendario(config: widget.config),
      Icons.calendar_month,
      'Agenda / Reservas',
    );
    agregarModulo(
      PantallaAdminScanner(config: widget.config),
      Icons.qr_code_scanner,
      'Escanear Carnet',
    );
    agregarModulo(
      PantallaAdminFinanzas(config: widget.config),
      Icons.attach_money,
      'Caja y Finanzas',
    );

    // --- 3. ADMINISTRACIÓN DE SOCIOS ---
    agregarModulo(
      PantallaAdminSocios(config: widget.config),
      Icons.groups,
      'Padrón de Socios',
    );
    agregarModulo(
      PantallaAdminPrecios(config: widget.config),
      Icons.price_change,
      'Config. Precios',
    );
    agregarModulo(
      PantallaAdminPagosConfig(config: widget.config),
      Icons.account_balance,
      'Datos de Cobro (CBU)',
    );
    // --- 4. GESTIÓN DEL CLUB ---
    agregarModulo(
      PantallaAdminEspacios(config: widget.config),
      Icons.stadium,
      'Canchas y Espacios',
    );
    agregarModulo(
      PantallaAdminTienda(config: widget.config),
      Icons.store,
      'Tienda Oficial',
    );
    agregarModulo(
      PantallaAdminSorteos(config: widget.config),
      Icons.local_activity,
      'Rifas y Sorteos',
    );

    // --- 5. COMUNICACIÓN Y CONTENIDO ---
    agregarModulo(
      PantallaAdminNoticias(config: widget.config),
      Icons.newspaper,
      'Noticias',
    );
    agregarModulo(
      PantallaAdminAvisoEntrada(config: widget.config),
      Icons.campaign,
      'Pop-up Inicio',
    );
    agregarModulo(
      PantallaAdminStream(config: widget.config),
      Icons.live_tv,
      'Transmisión Vivo',
    );
    agregarModulo(
      PantallaAdminVotacion(config: widget.config),
      Icons.how_to_vote,
      'Votaciones',
    );

    // --- 6. CONFIGURACIÓN TÉCNICA ---
    agregarModulo(
      PantallaAdminDeportes(config: widget.config),
      Icons.settings,
      'Config. Tiras/Dep.',
    );

    return Scaffold(
      body: Row(
        children: [
          // --- SIDEBAR LATERAL (MENÚ) ---
          Container(
            width: 260,
            color: const Color(0xFF1E1E2C),
            child: Column(
              children: [
                const SizedBox(height: 30),
                // Logo
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 35,
                  backgroundImage: AssetImage(widget.config.rutaLogo),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    widget.config.nombreApp.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Lista de Ítems
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = index == _selectedIndex;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.config.colorPrimario.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            item.icon,
                            color: isSelected
                                ? widget.config.colorPrimario
                                : Colors.white54,
                            size: 22,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),

                // Footer
                const Divider(color: Colors.white10),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    "v3.5 Panel Admin",
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // --- ÁREA DE CONTENIDO ---
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _selectedIndex < pantallas.length
                  ? pantallas[_selectedIndex]
                  : pantallas[0],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  _MenuItemData(this.icon, this.label);
}

class _DashboardResumen extends StatelessWidget {
  final ConfiguracionApp config;
  const _DashboardResumen({required this.config});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 80,
            color: config.colorPrimario.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            "Panel de Gestión: ${config.nombreApp}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Selecciona una opción del menú lateral para comenzar.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
