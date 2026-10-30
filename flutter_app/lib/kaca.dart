// Komponen tampilan gaya light glassmorphism: latar aurora warna-warni yang
// bergerak pelan, kartu kaca berkilau dengan border gradasi, dan efek
// kartu naik saat kursor lewat.

import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

const warnaTeks = Color(0xFF1E1B4B);
const warnaTeksRedup = Color(0xA61E1B4B);
const warnaUngu = Color(0xFF7C3AED);
const warnaPink = Color(0xFFEC4899);
const warnaHijau = Color(0xFF10B981);
const warnaKuning = Color(0xFFF59E0B);

const gradasiUtama = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [warnaUngu, warnaPink],
);

/// Latar aurora: dasar terang + gumpalan warna yang melayang pelan.
/// Gumpalan dibuat dengan RadialGradient (tepinya sudah lembut), bukan
/// blur filter, supaya tetap ringan walau dianimasikan di HP.
class LatarAurora extends StatefulWidget {
  const LatarAurora({super.key, required this.child, this.bergerak = true});

  final Widget child;

  /// Dimatikan di test, karena animasi tanpa akhir bikin pumpAndSettle macet.
  final bool bergerak;

  @override
  State<LatarAurora> createState() => _LatarAuroraState();
}

class _LatarAuroraState extends State<LatarAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waktu = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    if (widget.bergerak) _waktu.repeat();
  }

  @override
  void dispose() {
    _waktu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8), Color(0xFFECFEFF)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _waktu,
            builder: (context, _) {
              final t = _waktu.value * 2 * pi;
              return Stack(
                children: [
                  _gumpalan(Alignment(-0.9 + 0.25 * sin(t), -0.8 + 0.2 * cos(t)),
                      const Color(0xFFA78BFA), 1.1),
                  _gumpalan(Alignment(0.9 + 0.2 * cos(t), -0.6 + 0.25 * sin(t)),
                      const Color(0xFFF472B6), 0.95),
                  _gumpalan(Alignment(0.7 + 0.25 * sin(t + 2), 0.9 + 0.15 * cos(t)),
                      const Color(0xFF67E8F9), 1.0),
                  _gumpalan(Alignment(-0.7 + 0.2 * cos(t + 1), 0.8 + 0.2 * sin(t + 1)),
                      const Color(0xFFFDBA74), 0.85),
                ],
              );
            },
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }

  Widget _gumpalan(Alignment posisi, Color warna, double skala) {
    return Align(
      alignment: posisi,
      child: FractionallySizedBox(
        widthFactor: 0.75 * skala,
        heightFactor: 0.75 * skala,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [warna.withAlpha(0xB3), warna.withAlpha(0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu kaca. Blurnya sengaja tipis biar latar aurora tetap kelihatan
/// warnanya, plus kilau miring dan border gradasi biar kesan kacanya kuat.
class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Kalau diisi, kartu jadi kartu aksen berwarna (bukan kaca bening).
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final sudut = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: sudut,
        boxShadow: const [
          BoxShadow(
            color: Color(0x146D28D9),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: sudut,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: CustomPaint(
            foregroundPainter: _BorderGradasi(radius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: sudut,
                gradient: gradient ??
                    const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      // Kilau: atas-kiri lebih putih, bawah-kanan lebih bening.
                      colors: [Color(0x99FFFFFF), Color(0x40FFFFFF)],
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _BorderGradasi extends CustomPainter {
  _BorderGradasi(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = Offset.zero & size;
    final pena = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF2FFFFFF), Color(0x26FFFFFF), Color(0x80FFFFFF)],
        stops: [0, 0.55, 1],
      ).createShader(kotak);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kotak.deflate(0.7), Radius.circular(radius)),
      pena,
    );
  }

  @override
  bool shouldRepaint(_BorderGradasi lama) => lama.radius != radius;
}

/// Versi Flutter dari `whileHover={{ y: -5 }}` di framer-motion:
/// anak widget naik 5 piksel dan sedikit membesar saat kursor di atasnya.
class AngkatSaatHover extends StatefulWidget {
  const AngkatSaatHover({super.key, required this.child});

  final Widget child;

  @override
  State<AngkatSaatHover> createState() => _AngkatSaatHoverState();
}

class _AngkatSaatHoverState extends State<AngkatSaatHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Tombol pill dengan gradasi ungu-pink.
class TombolGradasi extends StatelessWidget {
  const TombolGradasi({
    super.key,
    required this.label,
    required this.onPressed,
    this.ikon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradasiUtama,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x557C3AED),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (ikon != null) ...[
                  Icon(ikon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan berbentuk pill kaca (dipakai buat mode, level, bahasa, panjang kata).
class PilihanKaca extends StatelessWidget {
  const PilihanKaca({
    super.key,
    required this.label,
    required this.dipilih,
    required this.onTap,
  });

  final String label;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: dipilih ? gradasiUtama : null,
          color: dipilih ? null : const Color(0x80FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dipilih ? const Color(0x00FFFFFF) : const Color(0xCCFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: dipilih ? Colors.white : warnaTeks,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
