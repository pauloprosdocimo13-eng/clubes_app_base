import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../configuracion/configuracion_app.dart';
import '../../configuracion/admin_permisos.dart';

// --- IMPORTAMOS TODOS LOS MÓDULOS DE GESTIÓN ---
import '../admin/pantalla_admin_socios.dart';
import '../admin/pantalla_admin_precios.dart';
import '../admin/pantalla_admin_pagos_config.dart';
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

// --- EL MÓDULO QUE FALTABA IMPORTAR ---
import '../pantalla_admin_publicidad.dart';

// --- IMPORTAMOS LOS MÓDULOS DE SEGURIDAD Y USUARIOS ---
import '../admin/pantalla_admin_usuarios.dart';
import '../admin/pantalla_admin_matriz_permisos.dart';
import '../admin/pantalla_admin_config_club.dart';

class PantallaAdminDesktop extends StatefulWidget {
  final ConfiguracionApp config;
  const PantallaAdminDesktop({super.key, required this.config});

  @override
  State<PantallaAdminDesktop> createState() => _PantallaAdminDesktopState();
}

class _PantallaAdminDesktopState extends State<PantallaAdminDesktop> {
  int _selectedIndex = 0;
  String _rolUsuario = '';

  @override
  void initState() {
    super.initState();
    _cargarRol();
  }

  Future<void> _cargarRol() async {
    await AdminPermisos.inicializarMatriz();
    String rol = await AdminPermisos.obtenerRol();
    if (mounted) {
      setState(() {
        _rolUsuario = rol;
      });
    }
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('configuracion')
            .doc('general')
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> modulosActivos = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            modulosActivos =
                data['modulos_activos'] as Map<String, dynamic>? ?? {};
          }

          final List<Widget> pantallas = [];
          final List<_MenuItemData> menuItems = [];

          void agregarModulo(
            Widget pantalla,
            IconData icon,
            String label, {
            bool requiereModulo = false,
            String? keyModulo,
          }) {
            if (!AdminPermisos.puedeVer(_rolUsuario, label)) return;

            if (requiereModulo && keyModulo != null) {
              if (modulosActivos[keyModulo] != true) return;
            }

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
            'Escanear Ingreso',
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
            'Padrón Socios',
          );
          agregarModulo(
            PantallaAdminPrecios(config: widget.config),
            Icons.price_change,
            'Config. Precios',
          );
          agregarModulo(
            PantallaAdminPagosConfig(config: widget.config),
            Icons.account_balance,
            'Configurar Pagos',
          );

          // --- 4. GESTIÓN DEL CLUB ---
          agregarModulo(
            PantallaAdminEspacios(config: widget.config),
            Icons.stadium,
            'Configurar Espacios',
          );

          agregarModulo(
            PantallaAdminTienda(config: widget.config),
            Icons.store,
            'Tienda Oficial',
            requiereModulo: true,
            keyModulo: 'tienda',
          );

          agregarModulo(
            PantallaAdminSorteos(config: widget.config),
            Icons.local_activity,
            'Gestionar Rifas',
            requiereModulo: true,
            keyModulo: 'sorteos',
          );

          // --- 5. COMUNICACIÓN Y CONTENIDO ---
          agregarModulo(
            PantallaAdminNoticias(config: widget.config),
            Icons.newspaper,
            'Publicar Noticia',
          );
          agregarModulo(
            PantallaAdminAvisoEntrada(config: widget.config),
            Icons.campaign,
            'Configurar Pop-up',
          );

          // --- MÓDULO PUBLICIDAD AGREGADO ---
          agregarModulo(
            PantallaAdminPublicidad(config: widget.config),
            Icons.monetization_on,
            'Sponsors / Banners',
            requiereModulo: true,
            keyModulo: 'publicidad',
          );

          agregarModulo(
            PantallaAdminStream(config: widget.config),
            Icons.live_tv,
            'Configurar Streaming',
            requiereModulo: true,
            keyModulo: 'stream',
          );

          agregarModulo(
            PantallaAdminVotacion(config: widget.config),
            Icons.how_to_vote,
            'Votación Figura',
            requiereModulo: true,
            keyModulo: 'votacion',
          );

          // --- 6. CONFIGURACIÓN TÉCNICA ---
          agregarModulo(
            PantallaAdminDeportes(config: widget.config),
            Icons.settings,
            'Configurar Tiras',
          );

          // --- 7. SEGURIDAD Y USUARIOS ---
          if (_rolUsuario == 'admin') {
            pantallas.add(PantallaAdminConfigClub(config: widget.config));
            menuItems.add(_MenuItemData(Icons.tune, 'Configuración Club'));

            pantallas.add(PantallaAdminUsuarios(config: widget.config));
            menuItems.add(
              _MenuItemData(Icons.admin_panel_settings, 'Gestión de Usuarios'),
            );

            pantallas.add(PantallaAdminMatrizPermisos(config: widget.config));
            menuItems.add(_MenuItemData(Icons.security, 'Matriz de Permisos'));
          }

          if (_selectedIndex >= pantallas.length) {
            _selectedIndex = 0;
          }

          return Row(
            children: [
              // --- SIDEBAR LATERAL (MENÚ) ---
              Container(
                width: 260,
                color: const Color(0xFF1E1E2C),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
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
                    if (_rolUsuario.isNotEmpty && _rolUsuario != 'admin')
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _rolUsuario.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

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
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () =>
                                  setState(() => _selectedIndex = index),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(color: Colors.white10),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white54),
                      title: const Text(
                        "Cerrar Sesión",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      onTap: _cerrarSesion,
                    ),
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
                  child: pantallas.isNotEmpty
                      ? pantallas[_selectedIndex]
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        },
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
