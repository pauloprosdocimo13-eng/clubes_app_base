import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../../configuracion/configuracion_app.dart';

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

  final _montoPagoManualCtrl = TextEditingController();

  // Configuración de precios
  Map<String, double> _precios = {};
  Map<String, dynamic> _configPagos = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosCompletos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _montoPagoManualCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosCompletos() async {
    try {
      // 1. Cargar Precios y Configuración
      final docPrecios = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('precios')
          .get();
      if (docPrecios.exists) {
        final data = docPrecios.data() ?? {};
        final mapPrecios = data['precios_cuotas'] ?? {};
        mapPrecios.forEach((k, v) {
          if (v is num) _precios[k] = v.toDouble();
          if (v is String) _precios[k] = double.tryParse(v) ?? 0.0;
        });
      }

      final docPagos = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('pagos')
          .get();
      if (docPagos.exists) {
        _configPagos = docPagos.data() ?? {};
      }

      // 2. Determinar Familia
      String familiaId = widget.datosSocio['familia_id'] ?? widget.socioId;

      final queryFamilia = await FirebaseFirestore.instance
          .collection('socios')
          .where('familia_id', isEqualTo: familiaId)
          .get();

      List<Map<String, dynamic>> familiaTemp = [];

      // Totales
      double sumaMes = 0;
      double sumaDeudaVieja = 0;

      for (var doc in queryFamilia.docs) {
        var data = doc.data();
        familiaTemp.add(data);

        // CALCULO DINÁMICO DE DEUDA
        final calculo = _calcularDeudaSocio(data);
        sumaMes += calculo['mes']!;
        sumaDeudaVieja += calculo['anterior']!;
      }

      // Fallback si no encuentra familia (se usa a sí mismo)
      if (familiaTemp.isEmpty) {
        familiaTemp.add(widget.datosSocio);
        final calculo = _calcularDeudaSocio(widget.datosSocio);
        sumaMes += calculo['mes']!;
        sumaDeudaVieja += calculo['anterior']!;
      }

      setState(() {
        _grupoFamiliar = familiaTemp;
        _montoCuotaMes = sumaMes;
        _deudaAnterior = sumaDeudaVieja;
        _montoTotalPagar = sumaMes + sumaDeudaVieja;

        // Sugerimos pagar el total, o al menos la cuota del mes si es muy alto
        _montoPagoManualCtrl.text = _montoTotalPagar > 0
            ? _montoTotalPagar.toStringAsFixed(0)
            : "0";

        _cargando = false;
      });
    } catch (e) {
      print("Error cargando dashboard socio: $e");
      setState(() => _cargando = false);
    }
  }

  // --- LÓGICA CORE: CALCULAR DEUDA REAL ---
  Map<String, double> _calcularDeudaSocio(Map<String, dynamic> data) {
    List<String> actividades = [];
    if (data['actividades'] != null) {
      actividades = List<String>.from(data['actividades']);
    } else if (data['actividad'] != null && data['actividad'] != 'Ninguna') {
      actividades = [data['actividad']];
    }

    double costoMensualTotal = 0;
    for (var act in actividades) {
      costoMensualTotal += _precios[act] ?? 0;
    }

    String ultimoMesPagoStr = data['ultimo_mes_pago'] ?? '';
    int mesesDeuda = 0;

    if (ultimoMesPagoStr.isEmpty) {
      mesesDeuda = 1;
    } else {
      try {
        DateTime ultimo = DateTime.parse("$ultimoMesPagoStr-01");
        DateTime ahora = DateTime.now();
        int mesesUltimo = ultimo.year * 12 + ultimo.month;
        int mesesAhora = ahora.year * 12 + ahora.month;
        mesesDeuda = mesesAhora - mesesUltimo;
      } catch (e) {
        mesesDeuda = 1;
      }
    }

    double debeMes = 0;
    double debeAnterior = 0;

    if (mesesDeuda > 0) {
      debeMes = costoMensualTotal;
      if (mesesDeuda > 1) {
        debeAnterior = costoMensualTotal * (mesesDeuda - 1);
      }
    }

    return {'mes': debeMes, 'anterior': debeAnterior};
  }

  // --- FUNCIONES DE PAGO MEJORADAS ---
  Future<void> _abrirMercadoPago(double monto) async {
    String url = _configPagos['link_mp'] ?? '';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay link de pago configurado.")),
      );
      return;
    }

    // 1. Corrección automática de URL (si falta https://)
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "https://$url";
    }

    // 2. Copiamos el monto al portapapeles (UX Truco)
    await Clipboard.setData(ClipboardData(text: monto.toStringAsFixed(0)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Monto \$${monto.toStringAsFixed(0)} copiado. Pegalo en MercadoPago.",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // 3. Intentamos abrir el link de forma robusta
    final uri = Uri.parse(url);
    try {
      // Primero probamos modo externo (abre la App de MP si está instalada)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Si falla, probamos modo plataforma (navegador por defecto)
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al abrir MP: $e")));
      }
    }
  }

  Future<void> _informarPagoWsp() async {
    String telefonoAdmin = _configPagos['telefono_wsp'] ?? '5491100000000';
    String nombre =
        "${widget.datosSocio['nombre']} ${widget.datosSocio['apellido']}";
    String monto = _montoPagoManualCtrl.text;

    String msj =
        "Hola! Soy $nombre (DNI ${widget.datosSocio['dni']}).\n"
        "Quiero informar un pago de \$$monto.\n"
        "Adjunto el comprobante a continuación:";

    final url = "https://wa.me/$telefonoAdmin?text=${Uri.encodeComponent(msj)}";
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool alDia = widget.datosSocio['al_dia'] ?? false;

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
              children: [_buildTabCarnet(alDia), _buildTabCuenta()],
            ),
    );
  }

  // ... (El resto de _buildTabCarnet es igual, lo mantengo para consistencia visual)
  Widget _buildTabCarnet(bool alDia) {
    final String nombre = widget.datosSocio['nombre'] ?? 'Socio';
    final String apellido = widget.datosSocio['apellido'] ?? '';
    final String dni = widget.datosSocio['dni'] ?? '';
    final String nroSocio = widget.datosSocio['nro_socio'] ?? '---';
    final String fotoUrl = widget.datosSocio['foto_url'] ?? '';
    String rol = 'Socio';
    if (widget.datosSocio['actividades'] != null &&
        (widget.datosSocio['actividades'] as List).isNotEmpty) {
      rol = (widget.datosSocio['actividades'] as List).first;
    } else {
      rol = widget.datosSocio['actividad'] ?? 'Socio';
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
                              color: alDia
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              alDia ? "HABILITADO" : "DEUDA",
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
                              radius: 35,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: (fotoUrl.isNotEmpty)
                                  ? NetworkImage(fotoUrl)
                                  : null,
                              child: (fotoUrl.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: 35,
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

  // ==========================================
  // PESTAÑA 2: CUENTA Y PAGOS
  // ==========================================
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
              children: [
                _filaDinero("Cuota del Mes:", _montoCuotaMes),
                if (_deudaAnterior > 0)
                  _filaDinero("Deuda Anterior:", _deudaAnterior, esDeuda: true),

                const Divider(),
                _filaDinero("TOTAL A PAGAR:", _montoTotalPagar, esTotal: true),

                if (_montoTotalPagar == 0)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 5),
                        Text(
                          "¡Estás al día!",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                const Text(
                  "Ingresá el monto que vas a abonar hoy:",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _montoPagoManualCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    prefixText: "\$ ",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
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
                    onPressed: () {
                      double monto =
                          double.tryParse(_montoPagoManualCtrl.text) ?? 0;
                      // Permitimos abrir el link siempre que sea > 0
                      if (monto > 0)
                        _abrirMercadoPago(monto);
                      else
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Ingresá un monto válido"),
                          ),
                        );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text("PAGAR CON MERCADO PAGO"),
                  ),
                ),

                if (_configPagos['alias_cbu'] != null &&
                    _configPagos['alias_cbu'] != '')
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "O transferencia bancaria:",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          "Alias: ${_configPagos['alias_cbu']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _informarPagoWsp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text("Informar Pago y Enviar Comprobante"),
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
