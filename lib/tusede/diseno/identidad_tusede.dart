import 'package:flutter/material.dart';

const tintaTuSede = Color(0xFF102D35);
const mentaTuSede = Color(0xFFB7F6CC);
const fondoTuSede = Color(0xFF0B1F27);
const superficieTuSede = Color(0xFF15333D);
const textoTuSede = Color(0xFFF1F7F5);

ThemeData temaTuSede() {
  final esquema = ColorScheme.fromSeed(
    seedColor: mentaTuSede,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema.copyWith(
      primary: mentaTuSede,
      onPrimary: fondoTuSede,
      secondary: mentaTuSede,
      surface: superficieTuSede,
      onSurface: textoTuSede,
    ),
    scaffoldBackgroundColor: fondoTuSede,
    appBarTheme: const AppBarTheme(
      backgroundColor: fondoTuSede,
      foregroundColor: textoTuSede,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: textoTuSede,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -.8,
        color: textoTuSede,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textoTuSede,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textoTuSede,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textoTuSede,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textoTuSede),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFFB5CBC6),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: superficieTuSede,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF34525B)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: superficieTuSede,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF48656D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF48656D)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: mentaTuSede,
      foregroundColor: fondoTuSede,
      elevation: 3,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF34525B)),
  );
}

/// Marca vectorial propia: una cancha vista desde arriba. Nítida a cualquier escala.
class MarcaTuSede extends StatelessWidget {
  final bool clara;
  const MarcaTuSede({super.key, this.clara = true});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: clara ? mentaTuSede : tintaTuSede,
          borderRadius: BorderRadius.circular(11),
        ),
        child: CustomPaint(
          painter: PintorCanchaTuSede(clara ? tintaTuSede : mentaTuSede),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'TuSede',
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          color: clara ? Colors.white : tintaTuSede,
        ),
      ),
    ],
  );
}

class PintorCanchaTuSede extends CustomPainter {
  final Color color;
  PintorCanchaTuSede(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(4),
      ),
      p,
    );
    canvas.drawLine(
      Offset(1, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      p,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * .19,
      p,
    );
  }

  @override
  bool shouldRepaint(PintorCanchaTuSede old) => old.color != color;
}

class CabeceraTuSede extends StatelessWidget {
  final String etiqueta, titulo, descripcion;
  final Widget? pie;
  const CabeceraTuSede({
    super.key,
    required this.etiqueta,
    required this.titulo,
    required this.descripcion,
    this.pie,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: tintaTuSede,
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [tintaTuSede, Color(0xFF20584F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: mentaTuSede,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                etiqueta.toUpperCase(),
                style: const TextStyle(
                  color: mentaTuSede,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          titulo,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge!.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          descripcion,
          style: const TextStyle(
            color: Color(0xFFD2E5DE),
            height: 1.6,
            fontSize: 15,
          ),
        ),
        if (pie != null) ...[const SizedBox(height: 24), pie!],
      ],
    ),
  );
}

class EscudoTuSede extends StatelessWidget {
  final String url;
  final double dimension;
  const EscudoTuSede({super.key, required this.url, this.dimension = 64});
  @override
  Widget build(BuildContext context) => Container(
    width: dimension,
    height: dimension,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2EAE5)),
    ),
    child: url.isEmpty
        ? const Icon(Icons.shield_outlined, color: tintaTuSede)
        : Image.network(
            url,
            fit: BoxFit.contain,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.shield_outlined, color: tintaTuSede),
          ),
  );
}

class EtiquetaTuSede extends StatelessWidget {
  final String texto;
  final bool oscura;
  const EtiquetaTuSede(this.texto, {super.key, this.oscura = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: oscura ? const Color(0xFF244D4F) : const Color(0xFF254A45),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: mentaTuSede,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
