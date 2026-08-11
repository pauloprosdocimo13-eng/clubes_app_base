import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class EtiquetaVersion extends StatefulWidget {
  const EtiquetaVersion({super.key});

  @override
  State<EtiquetaVersion> createState() => _EtiquetaVersionState();
}

class _EtiquetaVersionState extends State<EtiquetaVersion> {
  String _version = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _obtenerVersion();
  }

  Future<void> _obtenerVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        // Muestra algo como: "Versión 1.0.2 (Build 5)"
        _version =
            "Versión ${packageInfo.version} (Build ${packageInfo.buildNumber})";
      });
    } catch (e) {
      setState(() {
        _version = "Versión desconocida";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Center(
        child: Text(
          _version,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
