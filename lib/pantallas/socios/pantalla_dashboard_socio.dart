import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../configuracion/configuracion_app.dart';
import '../../servicios/servicio_firebase.dart';

class PantallaDashboardSocio extends StatefulWidget {
  final ConfiguracionApp config;
  final String socioId;
  final Map<String, dynamic> datosSocio;

  const PantallaDashboardSocio({
    super.key,
    required this.config,
    required this.socioId,
    required this.datosSocio,
  });

  @override
  State<PantallaDashboardSocio> createState() => _PantallaDashboardSocioState();
}

class _PantallaDashboardSocioState extends State<PantallaDashboardSocio>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Datos del grupo familiar
  List<Map<String, dynamic>> _grupoFamiliar = [];
  bool _cargando = true;

  // Lógica de Deuda
  double _montoCuotaMes = 0;
  double _deudaAnterior = 0;
  double _montoTotalPagar = 0;

  // Estado visual inteligente
  bool _estadoAlDiaDinamico = true;

  // Listas para el desglose visual
  List<Map<String, dynamic>> _desgloseMes = [];
  List<Map<String, dynamic>> _desgloseAnterior = [];

  // Configuración de precios y WhatsApp
  Map<String, double> _precios = {};
  Map<String, dynamic> _configPagos = {};
  String _telefonoWsp = '5491100000000';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosCompletos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN REFACTORIZADA LIMPIA ---
  Future<void> _cargarDatosCompletos() async {
    try {
      final servicio = ServicioFirebase();

      // 1. Cargar Precios desde la capa de servicios
      _precios = await servicio.obtenerPreciosCuotas();

      // 2. Cargar Pagos desde la capa de servicios
      _configPagos = await servicio.obtenerConfigPagos();

      // 3. Cargar Teléfono WhatsApp desde la capa de servicios
      _telefonoWsp = await servicio.obtenerTelefonoWsp(_configPagos);

      // 4. Determinar Familia y traer miembros desde la capa de servicios
      String familiaId = widget.datosSocio['familia_id'] ?? widget.socioId;
      List<Map<String, dynamic>> familiaTemp = await servicio.obtenerGrupoFamiliar(familiaId);

      double sumaMes = 0;
      double sumaDeudaVieja = 0;
      List<Map<String, dynamic>> tempDesgloseMes = [];
      List<Map<String, dynamic>> tempDesgloseAnterior = [];

      for (var data in familiaTemp) {
        final calculo = _calcularDeudaSocio(data);
        sumaMes += calculo['mes'];
        sumaDeudaVieja += calculo['anterior'];

        tempDesgloseMes.addAll(calculo['desgloseMes']);
        tempDesgloseAnterior.addAll(calculo['desgloseAnterior']);
      }

      // Fallback por si la query de familia falla o no devuelve datos
      if (familiaTemp.isEmpty) {
        familiaTemp.add(widget.datosSocio);
        final calculo = _calcularDeudaSocio(widget.datosSocio);
        sumaMes += calculo['mes'];
        sumaDeudaVieja += calculo['anterior'];
        tempDesgloseMes.addAll(calculo['desgloseMes']);
        tempDesgloseAnterior.addAll(calculo['desgloseAnterior']);
      }

      if (mounted) {
        // --- LÓGICA INTELIGENTE DEL ESTADO DEL CARNET ---
        bool alDiaTemp = true;

        // Si hay deuda matemática pendiente de pagar
        if (sumaMes + sumaDeudaVieja > 0) {
          // Si debe de meses anteriores, o si debe este mes y ya pasó el día 10
          if (sumaDeudaVieja > 0 || DateTime.now().day > 10) {
            alDiaTemp = false;
          }
        }

        setState(() {
          _grupoFamiliar = familiaTemp;
          _montoCuotaMes = sumaMes;
          _deudaAnterior = sumaDeudaVieja;
          _montoTotalPagar = sumaMes + sumaDeudaVieja;

          _desgloseMes = tempDesgloseMes;
          _desgloseAnterior = tempDesgloseAnterior;

          _estadoAlDiaDinamico = alDiaTemp;

          _cargando = false;
        });

        // Alerta de Deuda Inteligente (Solo salta si matemáticamente debe plata y se venció el plazo)
        if (!_estadoAlDiaDinamico) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _mostrarAlertaDeuda();
          });
        }
      }
    } catch (e) {
      print("Error cargando dashboard socio: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarAlertaDeuda() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 10),
            const Text(
              "Aviso de Deuda",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Registramos pagos pendientes en tu cuenta.\n\n"
          "Por favor, regularizá tu situación para mantener tu carnet habilitado y seguir disfrutando de las actividades del club.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CERRAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1);
            },
            child: const Text("PAGAR AHORA"),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calcularDeudaSocio(Map<String, dynamic> data) {
    Set<String> setActividades = {};
    if (data['actividades'] != null && data['actividades'] is List) {
      for (var a in data['actividades']) {
        setActividades.addAll(
          a.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
        );
      }
    } else if (data['actividad'] != null) {
      setActividades.addAll(
        (data['actividad'] ?? '')
            .toString()
            .split(RegExp(r'[,+]'))
            .map((e) => e.trim()),
      );
    }

    setActividades.removeWhere((e) => e.isEmpty || e == 'Ninguna');
    List<String> actividadesFinal = setActividades.toList();

    if (actividadesFinal.isEmpty) {
      actividadesFinal = ['Cuota Social'];
    }

    int descuentoGlobalViejo = (data['porcentaje_descuento'] ?? 0).toInt();

    String ultimoMesPagoStr = data['ultimo_mes_pago'] ?? '';
    int mesesDeuda = 0;

    if (ultimoMesPagoStr.isEmpty) {
      mesesDeuda = 1;
    } else {
      try {
        DateTime ultimo = DateTime.parse("$ultimoMesPagoStr-01");
        DateTime ahora = DateTime.now();
        int diff =
            (ahora.year * 12 + ahora.month) - (ultimo.year * 12 + ultimo.month);
        mesesDeuda = diff;
      } catch (e) {
        mesesDeuda = 1;
      }
    }

    double debeMes = 0;
    double debeAnterior = 0;
    List<Map<String, dynamic>> desgloseMesLocal = [];
    List<Map<String, dynamic>> desgloseAnteriorLocal = [];

    String nombreSocio = data['nombre'] ?? 'Socio';

    if (mesesDeuda > 0) {
      for (var act in actividadesFinal) {
        double precioActividad = _precios[act] ?? 0;

        if (descuentoGlobalViejo > 0) {
          if (descuentoGlobalViejo >= 100) {
            precioActividad = 0;
          } else {
            precioActividad =
                precioActividad -
                (precioActividad * (descuentoGlobalViejo / 100));
          }
        }

        debeMes += precioActividad;

        desgloseMesLocal.add({
          'nombre': nombreSocio,
          'concepto': precioActividad == 0 ? "$act (Becado)" : act,
          'monto': precioActividad,
        });

        if (mesesDeuda > 1) {
          double deudaAtrasadaActividad = precioActividad * (mesesDeuda - 1);
          debeAnterior += deudaAtrasadaActividad;

          if (deudaAtrasadaActividad > 0) {
            desgloseAnteriorLocal.add({
              'nombre': nombreSocio,
              'concepto': "$act (${mesesDeuda - 1} mes/es atrasados)",
              'monto': deudaAtrasadaActividad,
            });
          }
        }
      }
    }

    return {
      'mes': debeMes,
      'anterior': debeAnterior,
      'desgloseMes': desgloseMesLocal,
      'desgloseAnterior': desgloseAnteriorLocal,
    };
  }

  Future<void> _abrirMercadoPagoTransferencia() async {
    String aliasDelClub = _configPagos['alias_cbu'] ?? '';

    if (aliasDelClub.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aún no hay un Alias configurado en el sistema."),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: aliasDelClub));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Alias copiado. Abriendo Mercado Pago..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    final Uri webUrl = Uri.parse("https://www.mercadopago.com.ar");

    try {
      if (kIsWeb) {
        await launchUrl(webUrl);
      } else {
        final Uri appScheme = Uri.parse("mercadopago://");
        try {
          bool abrioApp = await launchUrl(
            appScheme,
            mode: LaunchMode.externalApplication,
          );
          if (!abrioApp) {
            await launchUrl(webUrl, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print("Error crítico al abrir MP: $e");
    }
  }

  Future<void> _informarPagoWsp() async {
    String telefonoLimpio = _telefonoWsp.replaceAll(RegExp(r'[^0-9]'), '');

    String nombre =
        "${widget.datosSocio['nombre']} ${widget.datosSocio['apellido']}";
    String monto = _montoTotalPagar.toStringAsFixed(0);

    String msj =
        "Hola! Soy $nombre (DNI ${widget.datosSocio['dni']}).\n"
        "Acabo de realizar una transferencia por \$$monto correspondiente a mi cuota.\n"
        "Adjunto el comprobante a continuación:";

    final url =
        "https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(msj)}";

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo abrir WhatsApp.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Panel de Socio"),
        backgroundColor: widget.config.colorPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white70,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: "MI CARNET", icon: Icon(Icons.badge)),
            Tab(text: "MI CUENTA", icon: Icon(Icons.account_balance_wallet)),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabCarnet(_estadoAlDiaDinamico),
                _buildTabCuenta(),
              ],
            ),
    );
  }

  Widget _buildTabCarnet(bool alDiaDinamico) {
    final String nombre = widget.datosSocio['nombre'] ?? 'Socio';
    final String apellido = widget.datosSocio['apellido'] ?? '';
    final String dni = widget.datosSocio['dni'] ?? '';
    final String nroSocio = widget.datosSocio['nro_socio'] ?? '---';
    final String fotoUrl = widget.datosSocio['foto_url'] ?? '';
    final bool aptoFisico = widget.datosSocio['apto_fisico'] == true;

    Set<String> setActsVisual = {};
    if (widget.datosSocio['actividades'] != null &&
        widget.datosSocio['actividades'] is List) {
      for (var a in widget.datosSocio['actividades']) {
        setActsVisual.addAll(
          a.toString().split(RegExp(r'[,+]')).map((e) => e.trim()),
        );
      }
    } else if (widget.datosSocio['actividad'] != null) {
      setActsVisual.addAll(
        (widget.datosSocio['actividad'] ?? '')
            .toString()
            .split(RegExp(r'[,+]'))
            .map((e) => e.trim()),
      );
    }
    setActsVisual.removeWhere((e) => e.isEmpty || e == 'Ninguna');

    String rol = 'Socio';
    if (setActsVisual.isNotEmpty) {
      rol = setActsVisual.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.config.colorPrimario,
                  widget.config.colorPrimario.withOpacity(0.8),
                  Colors.black87,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  bottom: -30,
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      widget.config.rutaLogo,
                      height: 200,
                      width: 200,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(widget.config.rutaLogo, height: 40),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.config.nombreApp.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                rol.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: alDiaDinamico
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              alDiaDinamico ? "HABILITADO" : "DEUDA",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: (fotoUrl.isNotEmpty)
                                  ? NetworkImage(fotoUrl)
                                  : null,
                              child: (fotoUrl.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "$nombre $apellido".toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "DNI: $dni",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "SOCIO N°: $nroSocio",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      aptoFisico
                                          ? Icons.health_and_safety
                                          : Icons.health_and_safety_outlined,
                                      color: aptoFisico
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      aptoFisico
                                          ? "APTO FÍSICO AL DÍA"
                                          : "FALTA APTO FÍSICO",
                                      style: TextStyle(
                                        color: aptoFisico
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!alDiaDinamico || _montoTotalPagar > 0)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: alDiaDinamico ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: alDiaDinamico ? Colors.green : Colors.red[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    alDiaDinamico ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: alDiaDinamico ? Colors.green : Colors.red[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alDiaDinamico ? 'Cuota al día' : 'Tenés pagos pendientes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: alDiaDinamico ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                        if (_montoTotalPagar > 0)
                          Text(
                            'Total adeudado: \$${_montoTotalPagar.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: alDiaDinamico ? Colors.green[700] : Colors.red[700],
                              fontSize: 13,
                            ),
                          )
                        else
                          Text(
                            'Podés ingresar con tu carnet habilitado',
                            style: TextStyle(color: Colors.green[700], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (_montoTotalPagar > 0)
                    TextButton(
                      onPressed: () => _tabController.animateTo(1),
                      child: const Text('Ver cuenta'),
                    ),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 10,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.config.colorPrimario.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: -10,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          Column(
            children: [
              const Text(
                "Escanea este código al ingresar",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: QrImageView(
                  data: widget.socioId,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.socioId,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabCuenta() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TarjetaInfo(
            titulo: "Estado de Cuenta",
            icono: Icons.monetization_on,
            colorIcono: Colors.green,
            contenido: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_montoTotalPagar == 0)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        SizedBox(width: 10),
                        Text(
                          "¡Estás al día!",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // --- DESGLOSE DE CUOTA ACTUAL ---
                  if (_desgloseMes.isNotEmpty) ...[
                    const Text(
                      "Detalle Cuota Actual:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._desgloseMes.map(
                      (item) => _filaDesglose(
                        item['nombre'],
                        item['concepto'],
                        item['monto'],
                      ),
                    ),
                    const Divider(height: 25),
                  ],

                  // --- DESGLOSE DE DEUDA ANTERIOR ---
                  if (_desgloseAnterior.isNotEmpty) ...[
                    const Text(
                      "Detalle Deuda Atrasada:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._desgloseAnterior.map(
                      (item) => _filaDesglose(
                        item['nombre'],
                        item['concepto'],
                        item['monto'],
                        esDeuda: true,
                      ),
                    ),
                    const Divider(height: 25),
                  ],

                  // --- TOTAL ---
                  _filaDinero(
                    "TOTAL A PAGAR:",
                    _montoTotalPagar,
                    esTotal: true,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          _TarjetaInfo(
            titulo: "Realizar Pago",
            icono: Icons.payment,
            colorIcono: Colors.blue,
            contenido: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_montoTotalPagar > 0) ...[
                  Text(
                    "Total a abonar: \$${_montoTotalPagar.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "¿Cómo pagar con transferencia?",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "1. Tocá el botón azul de abajo. Eso va a copiar automáticamente nuestro Alias y te va a abrir la app de Mercado Pago.",
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "2. Pegá el alias y transferí exactamente \$${_montoTotalPagar.toStringAsFixed(0)}.",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "3. Guardá el comprobante y tocale al botón verde de enviar por WhatsApp para que la administración te lo acredite.",
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  if (_configPagos['alias_cbu'] != null &&
                      _configPagos['alias_cbu'] != '')
                    Center(
                      child: SelectableText(
                        "Alias: ${_configPagos['alias_cbu']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009EE3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _abrirMercadoPagoTransferencia,
                      icon: const Icon(Icons.copy),
                      label: const Text("COPIAR ALIAS Y ABRIR MP"),
                    ),
                  ),
                ] else ...[
                  const Text(
                    "No tenés pagos pendientes para realizar en este momento.",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _montoTotalPagar > 0 ? _informarPagoWsp : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(
                      color: _montoTotalPagar > 0 ? Colors.green : Colors.grey,
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text("Informar Pago por WhatsApp"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_grupoFamiliar.length > 1) ...[
            const Text(
              "Grupo Familiar Vinculado",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ..._grupoFamiliar.map((familiar) {
              bool alDia = familiar['al_dia'] ?? false;
              String nombre = "${familiar['nombre']} ${familiar['apellido']}";
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.person,
                    color: widget.config.colorPrimario,
                  ),
                  title: Text(nombre),
                  subtitle: Text(familiar['dni'] ?? ''),
                  trailing: alDia
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.access_time, color: Colors.red),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _filaDesglose(
    String nombre,
    String concepto,
    double monto, {
    bool esDeuda = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  concepto,
                  style: TextStyle(
                    color: esDeuda ? Colors.red[300] : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "\$${monto.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: esDeuda
                  ? Colors.red
                  : (monto == 0 ? Colors.green : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaDinero(
    String label,
    double monto, {
    bool esTotal = false,
    bool esDeuda = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: esTotal ? 16 : 14,
            ),
          ),
          Text(
            "\$${monto.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: esTotal ? 18 : 14,
              color: esDeuda
                  ? Colors.red
                  : (esTotal ? Colors.black : Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaInfo extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color colorIcono;
  final Widget contenido;

  const _TarjetaInfo({
    required this.titulo,
    required this.icono,
    required this.colorIcono,
    required this.contenido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorIcono.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorIcono, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          contenido,
        ],
      ),
    );
  }
}