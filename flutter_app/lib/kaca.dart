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

import 'package:flutter/foundation.dart' show ValueListenable, immutable;
import 'package:flutter/material.dart';

/// Warna yang maknanya sama di tema terang dan gelap.
const warnaHijau = Color(0xFF16A34A);
const warnaKuning = Color(0xFFD97706);
const warnaAbu = Color(0xFF94A3B8);

/// Semua warna yang berubah antara tema terang dan gelap. Dipasang sebagai
/// ThemeExtension, jadi MaterialApp otomatis memakai palet yang cocok
/// (termasuk saat tema sistem berubah). Ambil lewat `context.palet`.
@immutable
class Palet extends ThemeExtension<Palet> {
  const Palet({
    required this.teks,
    required this.teksRedup,
    required this.aksen,
    required this.diAtasAksen,
    required this.garisHalus,
    required this.jalur,
    required this.isi,
    required this.isiPilihan,
    required this.tepi,
    required this.permukaan,
    required this.dialog,
    required this.kotakKosong,
    required this.kotakTerisi,
    required this.latarDasar,
    required this.latarBayangan,
    required this.kaca,
    required this.tepiKaca,
    required this.kacaGelap,
    required this.tepiKacaGelap,
  });

  /// Teks utama dan teks sekunder.
  final Color teks, teksRedup;

  /// Warna aksen (tombol utama, pilihan aktif) dan warna isi di atasnya.
  final Color aksen, diAtasAksen;

  /// Garis tipis, dan jalur bar (progress, rentang).
  final Color garisHalus, jalur;

  /// Isi kolom input/tombol keyboard, dan isi pilihan yang belum dipilih.
  final Color isi, isiPilihan;

  /// Garis tepi kolom dan tombol.
  final Color tepi;

  /// Permukaan solid (penanda di bar, menu yang aktif) dan latar dialog.
  final Color permukaan, dialog;

  /// Kotak huruf Wordle yang kosong dan yang sudah diketik.
  final Color kotakKosong, kotakTerisi;

  /// Gradasi dasar latar (3 warna) dan warna bayangan yang melayang (4).
  final List<Color> latarDasar, latarBayangan;

  /// Gradasi kartu kaca biasa (2 warna) dan garis tepinya (3 warna).
  final List<Color> kaca, tepiKaca;

  /// Gradasi kartu kaca gelap (terminal, kartu yang ditonjolkan) dan tepinya.
  final List<Color> kacaGelap, tepiKacaGelap;

  static const terang = Palet(
    teks: Color(0xFF0F172A),
    teksRedup: Color(0x990F172A),
    aksen: Color(0xFF0F172A),
    diAtasAksen: Color(0xFFFFFFFF),
    garisHalus: Color(0x1A0F172A),
    jalur: Color(0x260F172A),
    isi: Color(0x99FFFFFF),
    isiPilihan: Color(0x8CFFFFFF),
    tepi: Color(0xE6FFFFFF),
    permukaan: Color(0xFFFFFFFF),
    dialog: Color(0xFFF8FAFC),
    kotakKosong: Color(0x59FFFFFF),
    kotakTerisi: Color(0xB3FFFFFF),
    latarDasar: [Color(0xFFE6EBF1), Color(0xFFF5F6F8), Color(0xFFE2E6EB)],
    latarBayangan: [
      Color(0xFFB3C1D1),
      Color(0xFFD9CEC1),
      Color(0xFFBCC8D6),
      Color(0xFFE0D6CB),
    ],
    kaca: [Color(0xA6FFFFFF), Color(0x66FFFFFF)],
    tepiKaca: [Color(0xFFFFFFFF), Color(0x40FFFFFF), Color(0x290F172A)],
    kacaGelap: [Color(0xF00F172A), Color(0xE61E293B)],
    tepiKacaGelap: [Color(0x59FFFFFF), Color(0x0DFFFFFF), Color(0x26FFFFFF)],
  );

  static const gelap = Palet(
    teks: Color(0xFFE2E8F0),
    teksRedup: Color(0x99E2E8F0),
    aksen: Color(0xFFF1F5F9),
    diAtasAksen: Color(0xFF0F172A),
    garisHalus: Color(0x1FFFFFFF),
    jalur: Color(0x33FFFFFF),
    isi: Color(0x14FFFFFF),
    isiPilihan: Color(0x14FFFFFF),
    tepi: Color(0x33FFFFFF),
    permukaan: Color(0xFF1E293B),
    dialog: Color(0xFF111827),
    kotakKosong: Color(0x0DFFFFFF),
    kotakTerisi: Color(0x26FFFFFF),
    latarDasar: [Color(0xFF0B1120), Color(0xFF111827), Color(0xFF0A0F1C)],
    latarBayangan: [
      Color(0xFF1E3A5F),
      Color(0xFF3B2F2A),
      Color(0xFF1E293B),
      Color(0xFF2A2433),
    ],
    kaca: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
    tepiKaca: [Color(0x4DFFFFFF), Color(0x0DFFFFFF), Color(0x40000000)],
    kacaGelap: [Color(0xF5020617), Color(0xEB0F172A)],
    tepiKacaGelap: [Color(0x40FFFFFF), Color(0x0DFFFFFF), Color(0x26FFFFFF)],
  );

  @override
  Palet copyWith() => this;

  /// Tema berganti tanpa animasi warna: cukup lompat di tengah jalan.
  @override
  Palet lerp(Palet? other, double t) => other == null || t < 0.5 ? this : other;
}

extension PaletDariContext on BuildContext {
  Palet get palet => Theme.of(this).extension<Palet>() ?? Palet.terang;
}

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
            child: CustomPaint(painter: _PelukisLatar(_waktu, context.palet)),
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
  const _Bayangan(
      this.x, this.y, this.ayunX, this.ayunY, this.ukuran, this.fase);

  final double x, y, ayunX, ayunY;
  final double ukuran;
  final double fase;
}

class _PelukisLatar extends CustomPainter {
  // repaint: waktu -> cuma painter ini yang digambar ulang tiap frame,
  // tanpa membangun ulang widget apa pun.
  _PelukisLatar(this.waktu, this.palet) : super(repaint: waktu);

  final ValueListenable<double> waktu;
  final Palet palet;

  /// Warna tiap bayangan diambil dari palet.latarBayangan, urut.
  static const _bayangan = [
    _Bayangan(0.05, 0.05, 0.10, 0.08, 0.85, 0.0),
    _Bayangan(0.95, 0.30, 0.08, 0.12, 0.70, 1.7),
    _Bayangan(0.60, 1.00, 0.14, 0.06, 0.95, 3.4),
    _Bayangan(0.00, 0.85, 0.07, 0.10, 0.60, 4.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final layar = Offset.zero & size;
    canvas.drawRect(
      layar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palet.latarDasar,
        ).createShader(layar),
    );

    final t = waktu.value * 2 * pi;
    final sisiPanjang = max(size.width, size.height);
    for (var i = 0; i < _bayangan.length; i++) {
      final b = _bayangan[i];
      final warna = palet.latarBayangan[i % palet.latarBayangan.length];
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
            colors: [warna, warna.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: pusat, radius: jari)),
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisLatar lama) =>
      lama.waktu != waktu || lama.palet != palet;
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
    final p = context.palet;
    // RepaintBoundary: kartu jadi layer sendiri, jadi saat latar di
    // belakangnya bergerak, isi kartu nggak ikut digambar ulang.
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter:
            _GarisTepi(radius, gelap ? p.tepiKacaGelap : p.tepiKaca),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: sudut,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // Kaca biasa dibuat agak buram, ganti efek blur.
              colors: gelap ? p.kacaGelap : p.kaca,
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
  _GarisTepi(this.radius, this.warna);

  final double radius;

  /// 3 warna: pojok kiri atas, tengah, pojok kanan bawah.
  final List<Color> warna;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = Offset.zero & size;
    final pena = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: warna,
        stops: const [0, 0.55, 1],
      ).createShader(kotak);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kotak.deflate(0.6), Radius.circular(radius)),
      pena,
    );
  }

  @override
  bool shouldRepaint(_GarisTepi lama) =>
      lama.radius != radius || lama.warna != warna;
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
    final p = context.palet;
    return Material(
      color: aktif ? p.aksen : warnaAbu,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        hoverColor: p.diAtasAksen.withAlpha(0x1F),
        splashColor: p.diAtasAksen.withAlpha(0x33),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ikon != null) ...[
                Icon(ikon, color: p.diAtasAksen, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: p.diAtasAksen,
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
    final p = context.palet;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: dipilih ? p.aksen : p.isiPilihan,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dipilih ? p.aksen : p.tepi,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: dipilih ? p.diAtasAksen : p.teks,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
