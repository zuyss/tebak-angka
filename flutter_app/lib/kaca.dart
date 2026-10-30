// Komponen tampilan gaya "glassy": latar warna hangat, kartu kaca buram,
// dan efek kartu naik sedikit saat kursor lewat (hover).

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

const warnaTeks = Color(0xFF2B2420);
const warnaTeksRedup = Color(0x992B2420);
const warnaAksen = Color(0xFF1F8A70);
const warnaGelap = Color(0xFF1C1714);

/// Latar belakang: gradasi cokelat-krem plus beberapa gumpalan warna
/// yang di-blur, biar efek kaca di atasnya kelihatan.
class LatarHangat extends StatelessWidget {
  const LatarHangat({super.key, required this.child});

  final Widget child;

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
                colors: [
                  Color(0xFF5A4030),
                  Color(0xFFA9876A),
                  Color(0xFFE6D8C4),
                ],
              ),
            ),
          ),
        ),
        _gumpalan(top: -80, left: -60, ukuran: 320, warna: const Color(0xCC2E1F15)),
        _gumpalan(top: 140, right: -120, ukuran: 400, warna: const Color(0xAAF3E6D3)),
        _gumpalan(bottom: -140, left: 160, ukuran: 380, warna: const Color(0x997A5A42)),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _gumpalan({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double ukuran,
    required Color warna,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: ukuran,
          height: ukuran,
          decoration: BoxDecoration(shape: BoxShape.circle, color: warna),
        ),
      ),
    );
  }
}

/// Kartu kaca: isi di belakangnya di-blur, permukaannya putih transparan.
/// Kalau [gradient] diisi, kartu pakai warna gradasi itu (untuk kartu aksen).
class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final sudut = BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: sudut,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: sudut,
            // BoxDecoration nggak boleh pakai color dan gradient bareng.
            color: gradient == null ? const Color(0x73FFFFFF) : null,
            gradient: gradient,
            border: Border.all(color: const Color(0x80FFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Versi Flutter dari `whileHover={{ y: -5 }}` di framer-motion:
/// anak widget naik 5 piksel saat kursor di atasnya.
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
        child: widget.child,
      ),
    );
  }
}
