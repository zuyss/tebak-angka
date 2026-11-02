// Halaman "root": game-game rahasia. Menunya baru muncul setelah salah
// satu game di sini terbuka (lihat rahasia.dart untuk cara membukanya).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kaca.dart';
import 'pencapaian.dart';
import 'pengaturan.dart';
import 'rahasia.dart';
import 'simpanan.dart';

const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Consolas', 'Courier New', 'Courier'],
);
const _hijau = Color(0xFF4ADE80);
const _redup = Color(0x99FFFFFF);
const _merah = Color(0xFFF87171);
const _kuning = Color(0xFFFBBF24);

enum _Game { sandi, ular, brankas }

class HalamanRahasia extends StatefulWidget {
  const HalamanRahasia({super.key, this.simpanan, required this.aktif});

  final Simpanan? simpanan;

  /// False saat halaman lain yang tampil: game yang berjalan dijeda.
  final bool aktif;

  @override
  State<HalamanRahasia> createState() => _HalamanRahasiaState();
}

class _HalamanRahasiaState extends State<HalamanRahasia> {
  static const _kunciSimpanan = 'rahasia.v1';

  _Game? _pilihan;

  int _rekorSandi = 0;
  int _rekorUlar = 0;
  int? _rekorBrankas; // selisih ms terkecil

  @override
  void initState() {
    super.initState();
    final data = widget.simpanan?.baca(_kunciSimpanan);
    if (data != null) {
      _rekorSandi = angkaAman(data['sandi']);
      _rekorUlar = angkaAman(data['ular']);
      final brankas = data['brankas'];
      if (brankas is int && brankas >= 0) _rekorBrankas = brankas;
    }
  }

  void _simpan() {
    widget.simpanan?.tulis(_kunciSimpanan, {
      'sandi': _rekorSandi,
      'ular': _rekorUlar,
      'brankas': _rekorBrankas,
    });
  }

  String _id(_Game g) => switch (g) {
        _Game.sandi => 'root',
        _Game.ular => 'ular',
        _Game.brankas => 'brankas',
      };

  String _nama(_Game g) => switch (g) {
        _Game.sandi => context.tr('Pemecah Sandi', 'Cipher Breaker'),
        _Game.ular => context.tr('Ular', 'Snake'),
        _Game.brankas => context.tr('Brankas Waktu', 'Time Vault'),
      };

  @override
  Widget build(BuildContext context) {
    final p = PencapaianScope.dari(context);
    bool terbuka(_Game g) => p?.terbuka(_id(g)) ?? false;
    // Pilihan bawaan: game pertama yang sudah terbuka.
    var pilihan = _pilihan;
    if (pilihan == null || !terbuka(pilihan)) {
      pilihan = _Game.values.where(terbuka).firstOrNull;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KartuKaca(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in _Game.values)
                      PilihanKaca(
                        label: terbuka(g) ? _nama(g) : '???',
                        dipilih: g == pilihan,
                        onTap: () {
                          if (terbuka(g)) setState(() => _pilihan = g);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              switch (pilihan) {
                _Game.sandi => _GameSandi(
                    rekor: _rekorSandi,
                    onRekor: (skor) {
                      setState(() => _rekorSandi = skor);
                      _simpan();
                    },
                  ),
                _Game.ular => _GameUlar(
                    aktif: widget.aktif,
                    rekor: _rekorUlar,
                    onRekor: (n) {
                      setState(() => _rekorUlar = n);
                      _simpan();
                    },
                  ),
                _Game.brankas => _GameBrankas(
                    rekor: _rekorBrankas,
                    onRekor: (ms) {
                      setState(() => _rekorBrankas = ms);
                      _simpan();
                    },
                  ),
                null => KartuKaca(
                    gelap: true,
                    child: Text(
                      context.tr('Akses ditolak.', 'Access denied.'),
                      style: _mono.copyWith(color: _merah),
                    ),
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol hijau gaya terminal.
class _TombolTerminal extends StatelessWidget {
  const _TombolTerminal({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _hijau,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _dekorasiTerminal(String petunjuk) => InputDecoration(
      hintText: petunjuk,
      hintStyle: _mono.copyWith(color: const Color(0x40FFFFFF)),
      filled: true,
      fillColor: const Color(0x14FFFFFF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _hijau, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

// ---------- Pemecah Sandi ----------

class _GameSandi extends StatefulWidget {
  const _GameSandi({required this.rekor, required this.onRekor});

  final int rekor;
  final ValueChanged<int> onRekor;

  @override
  State<_GameSandi> createState() => _GameSandiState();
}

class _GameSandiState extends State<_GameSandi> {
  final _input = TextEditingController();
  final _fokus = FocusNode();
  SandiGame _game = SandiGame();
  String? _pesan;
  bool _pesanBenar = false;
  bool _transmisi = false;

  @override
  void dispose() {
    _input.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _baru() {
    setState(() {
      _game = SandiGame();
      _pesan = null;
      _transmisi = false;
      _input.clear();
    });
    _fokus.requestFocus();
  }

  void _kirim() {
    final game = _game;
    if (game.selesai) {
      _baru();
      return;
    }
    final teks = _input.text.trim();
    if (teks.isEmpty) return;
    final asli = game.asli;
    final benar = game.jawab(teks);
    PengaturanScope.baca(context)?.getarkan(kuat: game.selesai);
    setState(() {
      _input.clear();
      _pesanBenar = benar;
      if (benar) {
        _pesan = context.tr('Benar: $asli', 'Correct: $asli');
      } else if (game.selesai) {
        _pesan = context.tr('Koneksi terputus. Jawabannya: $asli',
            'Connection lost. The answer was: $asli');
      } else {
        _pesan = context.tr('Salah. Sisa nyawa ${game.nyawa}.',
            'Wrong. ${game.nyawa} lives left.');
      }
      if (game.skor >= skorPesanUlar) _transmisi = true;
    });
    if (game.selesai && game.skor > widget.rekor) widget.onRekor(game.skor);
    if (!game.selesai) _fokus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final gaya = _mono.copyWith(color: _redup, fontSize: 13);
    return KartuKaca(
      gelap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '\$ decrypt --caesar   ${context.tr('skor', 'score')} ${game.skor}'
            '   ${context.tr('nyawa', 'lives')} ${game.nyawa}/${game.nyawaAwal}'
            '   ${context.tr('rekor', 'best')} ${widget.rekor}',
            style: gaya,
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              game.selesai ? '------' : game.sandi.toUpperCase(),
              key: const ValueKey('teks-sandi'),
              style: _mono.copyWith(
                color: Colors.white,
                fontSize: 30,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              game.petunjukDipakai && !game.selesai
                  ? context.tr('geser = ${game.geser}', 'shift = ${game.geser}')
                  : context.tr('setiap huruf digeser sejauh N',
                      'every letter is shifted by N'),
              style: gaya,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            key: const ValueKey('baris-input-sandi'),
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _fokus,
                  enabled: !game.selesai,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  ],
                  onSubmitted: (_) => _kirim(),
                  cursorColor: _hijau,
                  style: _mono.copyWith(color: Colors.white, fontSize: 18),
                  decoration:
                      _dekorasiTerminal(context.tr('kata asli', 'plain word')),
                ),
              ),
              const SizedBox(width: 12),
              _TombolTerminal(
                label: game.selesai
                    ? context.tr('Lagi', 'Again')
                    : context.tr('Kirim', 'Send'),
                onTap: _kirim,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!game.selesai && !game.petunjukDipakai)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => game.lihatGeser()),
                child: Text(
                  context.tr('Lihat geser (poin jadi 1)',
                      'Reveal shift (worth 1 point)'),
                  style: _mono.copyWith(color: _kuning, fontSize: 13),
                ),
              ),
            ),
          if (_pesan != null) ...[
            const SizedBox(height: 6),
            Text(
              _pesan!,
              style: _mono.copyWith(color: _pesanBenar ? _hijau : _merah),
            ),
          ],
          if (_transmisi) ...[
            const SizedBox(height: 14),
            Text(
              context.tr('>> transmisi terenkripsi, geser tidak diketahui:',
                  '>> encrypted transmission, unknown shift:'),
              style: _mono.copyWith(color: _hijau, fontSize: 13),
            ),
            const SizedBox(height: 4),
            SelectableText(
              context.dua(pesanUlar),
              style: _mono.copyWith(color: _hijau, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            context.tr(
                'Pecahkan sandi Caesar: tiap huruf kata asli digeser sejauh N '
                    'huruf (misalnya geser 3: a jadi d). Benar +2 poin, '
                    'salah kehilangan nyawa.',
                'Break the Caesar cipher: every letter of the plain word is '
                    'shifted N places (shift 3: a becomes d). Correct is +2, '
                    'wrong costs a life.'),
            style: gaya,
          ),
        ],
      ),
    );
  }
}

// ---------- Ular ----------

class _GameUlar extends StatefulWidget {
  const _GameUlar({
    required this.aktif,
    required this.rekor,
    required this.onRekor,
  });

  final bool aktif;
  final int rekor;
  final ValueChanged<int> onRekor;

  @override
  State<_GameUlar> createState() => _GameUlarState();
}

class _GameUlarState extends State<_GameUlar> {
  final _fokus = FocusNode();
  UlarGame _game = UlarGame();
  Timer? _timer;
  bool _jalan = false;
  bool _pesanBrankas = false;

  @override
  void didUpdateWidget(_GameUlar lama) {
    super.didUpdateWidget(lama);
    if (!widget.aktif && _jalan) _jeda();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fokus.dispose();
    super.dispose();
  }

  void _mulai() {
    if (_game.selesai) {
      _game = UlarGame();
      _pesanBrankas = false;
    }
    setState(() => _jalan = true);
    _fokus.requestFocus();
    _jadwalkan();
  }

  void _jeda() {
    _timer?.cancel();
    setState(() => _jalan = false);
  }

  void _jadwalkan() {
    _timer?.cancel();
    _timer = Timer(_game.jeda, _langkah);
  }

  void _langkah() {
    if (!mounted || !_jalan) return;
    final game = _game;
    setState(() {
      game.langkah();
      if (game.dimakan >= makananPesanBrankas) _pesanBrankas = true;
      if (game.selesai) _jalan = false;
    });
    if (game.selesai) {
      PengaturanScope.baca(context)?.getarkan(kuat: true);
      if (game.dimakan > widget.rekor) widget.onRekor(game.dimakan);
      return;
    }
    _jadwalkan();
  }

  void _belok(ArahUlar arah) {
    if (!_jalan) return;
    _game.belok(arah);
  }

  KeyEventResult _tombol(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final arah = switch (k) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => ArahUlar.atas,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => ArahUlar.bawah,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => ArahUlar.kiri,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD =>
        ArahUlar.kanan,
      _ => null,
    };
    if (arah != null) {
      _belok(arah);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      _jalan ? _jeda() : _mulai();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _usap(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 150) return;
    if (v.dx.abs() > v.dy.abs()) {
      _belok(v.dx > 0 ? ArahUlar.kanan : ArahUlar.kiri);
    } else {
      _belok(v.dy > 0 ? ArahUlar.bawah : ArahUlar.atas);
    }
  }

  Widget _tombolArah(IconData ikon, ArahUlar arah) => IconButton(
        onPressed: () => _belok(arah),
        icon: Icon(ikon, color: Colors.white),
        style: IconButton.styleFrom(backgroundColor: const Color(0x1FFFFFFF)),
      );

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final gaya = _mono.copyWith(color: _redup, fontSize: 13);
    return KartuKaca(
      gelap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '\$ ./ular   ${context.tr('makan', 'eaten')} ${game.dimakan}'
            '   ${context.tr('rekor', 'best')} ${widget.rekor}',
            style: gaya,
          ),
          const SizedBox(height: 12),
          Focus(
            focusNode: _fokus,
            onKeyEvent: _tombol,
            child: GestureDetector(
              onPanEnd: _usap,
              onTap: () => _fokus.requestFocus(),
              child: AspectRatio(
                aspectRatio: game.lebar / game.tinggi,
                child: RepaintBoundary(
                  child: CustomPaint(painter: _PelukisUlar(game)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (game.selesai)
            Text(
              context.tr('ULAR TABRAKAN. ${game.dimakan} makanan.',
                  'SNAKE CRASHED. ${game.dimakan} food eaten.'),
              style: _mono.copyWith(color: _merah, fontWeight: FontWeight.w700),
            ),
          if (_pesanBrankas) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('>> pesan dari perut ular:', '>> message from the belly:'),
              style: _mono.copyWith(color: _hijau, fontSize: 13),
            ),
            const SizedBox(height: 4),
            SelectableText(
              context.dua(pesanBrankas),
              style: _mono.copyWith(color: _hijau, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _TombolTerminal(
                label: _jalan
                    ? context.tr('Jeda', 'Pause')
                    : game.selesai
                        ? context.tr('Main lagi', 'Play again')
                        : context.tr('Mulai', 'Start'),
                onTap: _jalan ? _jeda : _mulai,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tombolArah(Icons.keyboard_arrow_left, ArahUlar.kiri),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tombolArah(Icons.keyboard_arrow_up, ArahUlar.atas),
                      _tombolArah(Icons.keyboard_arrow_down, ArahUlar.bawah),
                    ],
                  ),
                  _tombolArah(Icons.keyboard_arrow_right, ArahUlar.kanan),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
                'Panah/WASD atau usap untuk belok, Spasi untuk jeda. '
                    'Jangan tabrak dinding atau badan sendiri.',
                'Arrows/WASD or swipe to turn, Space to pause. '
                    'Do not hit the walls or yourself.'),
            style: gaya,
          ),
        ],
      ),
    );
  }
}

class _PelukisUlar extends CustomPainter {
  _PelukisUlar(this.game)
      : _kepala = game.badan.first,
        _panjang = game.panjang,
        _makanan = game.makanan;

  final UlarGame game;
  // Salinan keadaan saat dilukis, buat shouldRepaint.
  final Titik _kepala, _makanan;
  final int _panjang;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = size.width / game.lebar;
    final garis = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, garis);
    Rect sel(Titik t) => Rect.fromLTWH(
        t.x * kotak + 1, t.y * kotak + 1, kotak - 2, kotak - 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(sel(game.makanan), Radius.circular(kotak / 2)),
      Paint()..color = _kuning,
    );
    for (var i = game.badan.length - 1; i >= 0; i--) {
      final warna = i == 0
          ? _hijau
          : Color.lerp(_hijau, const Color(0xFF14532D),
              i / game.badan.length)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(sel(game.badan[i]), Radius.circular(kotak / 4)),
        Paint()..color = warna,
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisUlar lama) =>
      lama._kepala != _kepala ||
      lama._panjang != _panjang ||
      lama._makanan != _makanan ||
      !identical(lama.game, game);
}

// ---------- Brankas Waktu ----------

class _GameBrankas extends StatefulWidget {
  const _GameBrankas({required this.rekor, required this.onRekor});

  final int? rekor;
  final ValueChanged<int> onRekor;

  @override
  State<_GameBrankas> createState() => _GameBrankasState();
}

class _GameBrankasState extends State<_GameBrankas> {
  final _stopwatch = Stopwatch();
  Timer? _timer;
  int? _hasil; // ms saat dihentikan

  /// Angka di layar menghilang setelah sekian milidetik.
  static const _batasTerlihat = 1000;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tekan() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
      final ms = _stopwatch.elapsedMilliseconds;
      final selisih = (ms - targetBrankasMs).abs();
      setState(() => _hasil = ms);
      final rekor = widget.rekor;
      if (rekor == null || selisih < rekor) widget.onRekor(selisih);
      PengaturanScope.baca(context)?.getarkan(kuat: true);
      return;
    }
    _stopwatch
      ..reset()
      ..start();
    setState(() => _hasil = null);
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      // Cukup gambar ulang selama angkanya masih terlihat.
      if (_stopwatch.elapsedMilliseconds > _batasTerlihat + 100) {
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  String _detik(int ms) => (ms / 1000).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final jalan = _stopwatch.isRunning;
    final ms = _stopwatch.elapsedMilliseconds;
    final hasil = _hasil;
    final String layar;
    if (jalan) {
      layar = ms < _batasTerlihat ? _detik(ms) : '?.??';
    } else {
      layar = hasil == null ? '0.00' : _detik(hasil);
    }
    final selisih = hasil == null ? null : (hasil - targetBrankasMs).abs();
    final rekor = widget.rekor;
    final gaya = _mono.copyWith(color: _redup, fontSize: 13);

    return KartuKaca(
      gelap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '\$ brankas --target ${_detik(targetBrankasMs)}s   '
            '${context.tr('rekor', 'best')} '
            '${rekor == null ? '-' : '$rekor ms'}',
            style: gaya,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              layar,
              key: const ValueKey('layar-brankas'),
              style: _mono.copyWith(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selisih != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                selisih == 0
                    ? context.tr('SEMPURNA. Brankas terbuka lebar.',
                        'PERFECT. The vault swings open.')
                    : context.tr('Meleset $selisih ms.', 'Off by $selisih ms.'),
                style: _mono.copyWith(
                  color: selisih <= 20 ? _hijau : _kuning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: _TombolTerminal(
              label: jalan
                  ? context.tr('Stop', 'Stop')
                  : context.tr('Mulai', 'Start'),
              onTap: _tekan,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
                'Hentikan stopwatch tepat di ${_detik(targetBrankasMs)} detik. '
                    'Angkanya menghilang setelah 1 detik, sisanya pakai '
                    'perasaan.',
                'Stop the stopwatch at exactly ${_detik(targetBrankasMs)} '
                    'seconds. The numbers vanish after 1 second, the rest is '
                    'feel.'),
            style: gaya,
          ),
        ],
      ),
    );
  }
}
