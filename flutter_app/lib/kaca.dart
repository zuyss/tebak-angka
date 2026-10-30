// Komponen tampilan kaca putih bening: latar netral yang bergerak pelan,
// kartu kaca dengan garis tepi putih tajam, dan aksen hitam pekat.
//
// Soal performa (penting): di Windows, Flutter 3.47 memakai renderer
// Impeller, yang TIDAK punya raster cache. Selama latar bergerak, seluruh
// layar digambar ulang dari nol setiap frame. Karena itu:
// - nggak ada BackdropFilter (blur sungguhan) di kartu,
// - nggak ada BoxShadow dengan blurRadius (tiap bayangan = satu blur
//   Gaussian per frame); kedalaman dibuat dari garis tepi saja,
// - latar diperbarui 30x per detik, bukan 60x: geraknya sangat pelan,
//   jadi bedanya nggak kelihatan, tapi kerja GPU saat diam turun separuh.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

const warnaTeks = Color(0xFF0F172A);
const warnaTeksRedup = Color(0x990F172A);
const warnaHitam = Color(0xFF0F172A);
const warnaGaris = Color(0x1F0F172A);
const warnaHijau = Color(0xFF16A34A);
const warnaKuning = Color(0xFFD97706);
const warnaAbu = Color(0xFF94A3B8);

/// Latar netral dengan bayangan-bayangan lembut yang melayang pelan.
/// Bayangan ini yang bikin tepi kaca kelihatan; di atas latar putih polos,
/// kaca putih nggak terlihat.
class LatarBening extends StatefulWidget {
  const LatarBening({super.key, required this.child, this.bergerak = true});

  final Widget child;

  /// Dimatikan di test, karena animasi tanpa akhir bikin pumpAndSettle macet.
  final bool bergerak;

  @override
  State<LatarBening> createState() => _LatarBeningState();
}

class _LatarBeningState extends State<LatarBening>
    with WidgetsBindingObserver {
  /// Posisi siklus animasi, 0..1. Painter mendengarkan ini lewat `repaint`.
  final _waktu = ValueNotifier<double>(0);
  final _stopwatch = Stopwatch();
  Timer? _timer;
  bool _appTerlihat = true;

  static const _siklus = Duration(seconds: 40);
  static const _jedaFrame = Duration(milliseconds: 33); // ~30 fps

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aturAnimasi();
  }

  @override
  void didUpdateWidget(LatarBening lama) {
    super.didUpdateWidget(lama);
    _aturAnimasi();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Window di-minimize atau app di-background: berhenti menggambar.
    _appTerlihat = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _aturAnimasi();
  }

  /// Animasi jalan kecuali dimatikan, app tersembunyi, atau pengguna
  /// menyalakan setting "kurangi animasi" di sistem operasinya.
  void _aturAnimasi() {
    final gerak = widget.bergerak &&
        _appTerlihat &&
        !MediaQuery.disableAnimationsOf(context);
    if (gerak && _timer == null) {
      _stopwatch.start();
      _timer = Timer.periodic(_jedaFrame, (_) {
        // Hitung dari jam, bukan jumlah tick: Timer di Windows nggak
        // presisi, tapi posisinya tetap halus.
        final ms = _stopwatch.elapsedMilliseconds % _siklus.inMilliseconds;
        _waktu.value = ms / _siklus.inMilliseconds;
      });
    } else if (!gerak && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _stopwatch.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _waktu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _PelukisLatar(_waktu)),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

/// Satu bayangan: posisi dasar, seberapa jauh dia melayang, warna, ukuran,
/// dan fase (biar nggak bergerak serempak).
class _Bayangan {
  const _Bayangan(this.x, this.y, this.ayunX, this.ayunY, this.warna,
      this.ukuran, this.fase);

  final double x, y, ayunX, ayunY;
  final Color warna;
  final double ukuran;
  final double fase;
}

class _PelukisLatar extends CustomPainter {
  // repaint: waktu -> cuma painter ini yang digambar ulang tiap frame,
  // tanpa membangun ulang widget apa pun.
  _PelukisLatar(this.waktu) : super(repaint: waktu);

  final ValueListenable<double> waktu;

  static const _dasar = [Color(0xFFE6EBF1), Color(0xFFF5F6F8), Color(0xFFE2E6EB)];

  static const _bayangan = [
    _Bayangan(0.05, 0.05, 0.10, 0.08, Color(0xFFB3C1D1), 0.85, 0.0),
    _Bayangan(0.95, 0.30, 0.08, 0.12, Color(0xFFD9CEC1), 0.70, 1.7),
    _Bayangan(0.60, 1.00, 0.14, 0.06, Color(0xFFBCC8D6), 0.95, 3.4),
    _Bayangan(0.00, 0.85, 0.07, 0.10, Color(0xFFE0D6CB), 0.60, 4.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final layar = Offset.zero & size;
    canvas.drawRect(
      layar,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _dasar,
        ).createShader(layar),
    );

    final t = waktu.value * 2 * pi;
    final sisiPanjang = max(size.width, size.height);
    for (final b in _bayangan) {
      final pusat = Offset(
        size.width * (b.x + b.ayunX * sin(t + b.fase)),
        size.height * (b.y + b.ayunY * cos(t + b.fase)),
      );
      final jari = sisiPanjang * 0.45 * b.ukuran;
      canvas.drawCircle(
        pusat,
        jari,
        Paint()
          ..shader = RadialGradient(
            colors: [b.warna, b.warna.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: pusat, radius: jari)),
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisLatar lama) => lama.waktu != waktu;
}

/// Kartu kaca putih bening. Dengan [gelap], kartu jadi kaca hitam
/// (dipakai untuk kartu yang mau ditonjolkan).
class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gelap = false,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool gelap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final sudut = BorderRadius.circular(radius);
    // RepaintBoundary: kartu jadi layer sendiri, jadi saat latar di
    // belakangnya bergerak, isi kartu nggak ikut digambar ulang.
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _GarisTepi(radius, gelap),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: sudut,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gelap
                  ? const [Color(0xF00F172A), Color(0xE61E293B)]
                  // Lebih buram dari sebelumnya, ganti efek blur.
                  : const [Color(0xA6FFFFFF), Color(0x66FFFFFF)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Garis tepi kaca: putih tajam di pojok kiri atas, memudar ke kanan bawah,
/// seperti pantulan cahaya di tepi kaca.
class _GarisTepi extends CustomPainter {
  _GarisTepi(this.radius, this.gelap);

  final double radius;
  final bool gelap;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = Offset.zero & size;
    final pena = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gelap
            ? const [Color(0x59FFFFFF), Color(0x0DFFFFFF), Color(0x26FFFFFF)]
            : const [Color(0xFFFFFFFF), Color(0x40FFFFFF), Color(0x290F172A)],
        stops: const [0, 0.55, 1],
      ).createShader(kotak);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kotak.deflate(0.6), Radius.circular(radius)),
      pena,
    );
  }

  @override
  bool shouldRepaint(_GarisTepi lama) =>
      lama.radius != radius || lama.gelap != gelap;
}

/// Versi Flutter dari `whileHover={{ y: -5 }}` di framer-motion.
/// Dipakai di kartu kecil saja: menggeser kartu besar berarti nge-blur
/// ulang area yang lebar selama animasi.
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
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Tombol utama: pill hitam pekat.
class TombolUtama extends StatelessWidget {
  const TombolUtama({
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
    final aktif = onPressed != null;
    return Material(
      color: aktif ? warnaHitam : warnaAbu,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        hoverColor: const Color(0x1FFFFFFF),
        splashColor: const Color(0x33FFFFFF),
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
    );
  }
}

/// Pilihan berbentuk pill (mode, level, bahasa, panjang kata).
/// Yang dipilih hitam, yang lain kaca bening.
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: dipilih ? warnaHitam : const Color(0x8CFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dipilih ? warnaHitam : const Color(0xFFFFFFFF),
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
      ),
    );
  }
}
