import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'halaman_angka.dart';
import 'halaman_wordle.dart';
import 'kaca.dart';

void main() => runApp(const TebakAngkaApp());

class TebakAngkaApp extends StatefulWidget {
  const TebakAngkaApp({
    super.key,
    this.pemuatKamus = muatKamusDariAset,
    this.latarBergerak = true,
  });

  /// Bisa diganti di test supaya nggak perlu baca file aset.
  final PemuatKamus pemuatKamus;

  /// Dimatikan di test (animasi tanpa akhir bikin pumpAndSettle macet).
  final bool latarBergerak;

  @override
  State<TebakAngkaApp> createState() => _TebakAngkaAppState();
}

class _TebakAngkaAppState extends State<TebakAngkaApp> {
  /// Tekan F3 untuk menampilkan grafik waktu per frame. Grafik atas = GPU
  /// (raster), bawah = Dart (UI). Batang merah = frame yang telat.
  bool _grafikPerforma = false;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            setState(() => _grafikPerforma = !_grafikPerforma),
      },
      child: MaterialApp(
        title: 'Tebak Angka',
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: _grafikPerforma,
        theme: ThemeData(colorSchemeSeed: warnaHitam),
        home: Beranda(
          pemuatKamus: widget.pemuatKamus,
          latarBergerak: widget.latarBergerak,
        ),
      ),
    );
  }
}

class Beranda extends StatefulWidget {
  const Beranda({
    super.key,
    required this.pemuatKamus,
    required this.latarBergerak,
  });

  final PemuatKamus pemuatKamus;
  final bool latarBergerak;

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  int _halaman = 0; // 0 = Tebak Angka, 1 = Wordle
  bool _wordlePernahDibuka = false;

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _pindah(int halaman) {
    setState(() {
      _halaman = halaman;
      if (halaman == 1) _wordlePernahDibuka = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LatarBening(
        bergerak: widget.latarBergerak,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: _header(),
                  ),
                ),
              ),
              Expanded(
                // IndexedStack: pindah halaman nggak menghapus progres.
                child: IndexedStack(
                  index: _halaman,
                  children: [
                    const HalamanAngka(),
                    // Wordle baru dibangun saat pertama dibuka, biar daftar
                    // katanya nggak dimuat kalau nggak dimainkan.
                    if (_wordlePernahDibuka)
                      HalamanWordle(
                        pemuatKamus: widget.pemuatKamus,
                        aktif: _halaman == 1,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final judul = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sapaan(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: warnaTeks,
          ),
        ),
        const Text(
          'Mau main apa hari ini?',
          style: TextStyle(color: warnaTeksRedup),
        ),
      ],
    );
    final menu = _MenuSwitch(
      pilihan: const ['Tebak Angka', 'Wordle'],
      indeks: _halaman,
      onGanti: _pindah,
    );

    return LayoutBuilder(
      builder: (context, batas) {
        if (batas.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(child: judul),
              SizedBox(width: 320, child: menu),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [judul, const SizedBox(height: 12), menu],
        );
      },
    );
  }
}

/// Menu pill kaca dengan indikator gradasi yang meluncur ke pilihan aktif.
class _MenuSwitch extends StatelessWidget {
  const _MenuSwitch({
    required this.pilihan,
    required this.indeks,
    required this.onGanti,
  });

  final List<String> pilihan;
  final int indeks;
  final ValueChanged<int> onGanti;

  @override
  Widget build(BuildContext context) {
    final posisi = pilihan.length == 1 ? 0.0 : indeks / (pilihan.length - 1);

    return KartuKaca(
      padding: const EdgeInsets.all(5),
      radius: 999,
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment(posisi * 2 - 1, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / pilihan.length,
                heightFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    // Garis tipis, bukan bayangan blur (lihat catatan di kaca.dart).
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x1A0F172A)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < pilihan.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onGanti(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            fontWeight:
                                i == indeks ? FontWeight.w800 : FontWeight.w600,
                            color: i == indeks ? warnaTeks : warnaTeksRedup,
                          ),
                          child: Text(pilihan[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
