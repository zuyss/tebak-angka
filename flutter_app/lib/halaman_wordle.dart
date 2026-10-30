import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kaca.dart';
import 'wordle.dart';

typedef PemuatKamus = Future<KamusWordle> Function(Bahasa bahasa, int panjang);

/// Muat daftar kata dari folder assets/kata.
Future<KamusWordle> muatKamusDariAset(Bahasa bahasa, int panjang) async {
  Future<List<String>> baca(String jenis) async {
    final data =
        await rootBundle.load('assets/kata/${bahasa.kode}_${panjang}_$jenis.txt');
    // Decode sendiri, bukan rootBundle.loadString: loadString memindahkan
    // file di atas 50 KB ke isolate lain, dan itu bikin widget test macet.
    return KamusWordle.parse(utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
  }

  return KamusWordle(
    jawaban: await baca('jawaban'),
    valid: (await baca('valid')).toSet(),
  );
}

class HalamanWordle extends StatefulWidget {
  const HalamanWordle({
    super.key,
    required this.pemuatKamus,
    required this.aktif,
  });

  final PemuatKamus pemuatKamus;

  /// True kalau halaman ini sedang tampil (buat ambil fokus keyboard).
  final bool aktif;

  @override
  State<HalamanWordle> createState() => _HalamanWordleState();
}

class _HalamanWordleState extends State<HalamanWordle> {
  final _random = Random();
  final _cache = <(Bahasa, int), KamusWordle>{};
  final _fokus = FocusNode();

  Bahasa _bahasa = Bahasa.id;
  int _panjang = 5;
  WordleGame? _game;
  bool _memuat = false;
  String _ketikan = '';
  String? _pesan;
  int _getar = 0; // naik tiap tebakan ditolak, memicu animasi goyang

  int _main = 0;
  int _menang = 0;
  int _beruntun = 0;

  @override
  void initState() {
    super.initState();
    // setState belum boleh dipanggil di initState, jadi status awal
    // diisi langsung lalu daftar kata dimuat.
    _memuat = true;
    _muatLaluMulai();
  }

  @override
  void didUpdateWidget(HalamanWordle lama) {
    super.didUpdateWidget(lama);
    if (widget.aktif && !lama.aktif) _fokus.requestFocus();
  }

  @override
  void dispose() {
    _fokus.dispose();
    super.dispose();
  }

  void _kataBaru() {
    setState(() {
      _memuat = true;
      _pesan = null;
      _ketikan = '';
      _getar = 0;
    });
    _muatLaluMulai();
  }

  Future<void> _muatLaluMulai() async {
    final kunci = (_bahasa, _panjang);
    final KamusWordle kamus;
    final tersimpan = _cache[kunci];
    if (tersimpan != null) {
      kamus = tersimpan;
    } else {
      try {
        kamus = await widget.pemuatKamus(_bahasa, _panjang);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _memuat = false;
          _game = null;
          _pesan = 'Daftar kata gagal dimuat.';
        });
        return;
      }
      _cache[kunci] = kamus;
    }

    // Selama memuat, bahasa atau panjang mungkin sudah diganti lagi.
    if (!mounted || kunci != (_bahasa, _panjang)) return;
    setState(() {
      var jawaban = kamus.acakJawaban(_random);
      if (jawaban == _game?.jawaban && kamus.jawaban.length > 1) {
        jawaban = kamus.acakJawaban(_random);
      }
      _game = WordleGame(jawaban: jawaban, kamus: kamus);
      _memuat = false;
    });
    if (widget.aktif) _fokus.requestFocus();
  }

  void _gantiBahasa(Bahasa bahasa) {
    if (bahasa == _bahasa) return;
    _bahasa = bahasa;
    _kataBaru();
  }

  void _gantiPanjang(int panjang) {
    if (panjang == _panjang) return;
    _panjang = panjang;
    _kataBaru();
  }

  void _ketik(String huruf) {
    final game = _game;
    if (_memuat || game == null || game.selesai) return;
    if (_ketikan.length >= game.panjang) return;
    setState(() => _ketikan += huruf.toLowerCase());
  }

  void _hapus() {
    if (_memuat || _ketikan.isEmpty) return;
    setState(() => _ketikan = _ketikan.substring(0, _ketikan.length - 1));
  }

  void _kirim() {
    final game = _game;
    if (_memuat || game == null) return;
    if (game.selesai) {
      // Permainan sudah selesai: Enter langsung mulai kata baru.
      _kataBaru();
      return;
    }

    final error = game.tebak(_ketikan);
    setState(() {
      if (error != null) {
        _pesan = error;
        _getar++;
        return;
      }
      _ketikan = '';
      _pesan = null;
      // Reset, supaya baris berikutnya nggak ikut goyang. Penanda goyang
      // dibuat ulang dari nol saat ada tebakan yang ditolak lagi.
      _getar = 0;
      if (game.selesai) {
        _main++;
        if (game.menang) {
          _menang++;
          _beruntun++;
          _pesan = 'Mantap! Ketebak dalam ${game.tebakan.length} tebakan.';
        } else {
          _beruntun = 0;
          _pesan = 'Jawabannya ${game.jawaban.toUpperCase()}.';
        }
      }
    });
  }

  KeyEventResult _tombolFisik(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final kunci = event.logicalKey;
    if (kunci == LogicalKeyboardKey.enter ||
        kunci == LogicalKeyboardKey.numpadEnter) {
      // Enter yang ditahan (KeyRepeatEvent) diabaikan, biar nggak
      // mengirim tebakan berkali-kali.
      if (event is KeyDownEvent) _kirim();
      return KeyEventResult.handled;
    }
    if (kunci == LogicalKeyboardKey.backspace) {
      _hapus();
      return KeyEventResult.handled;
    }
    final huruf = event.character;
    if (huruf != null && RegExp(r'^[a-zA-Z]$').hasMatch(huruf)) {
      _ketik(huruf);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _fokus,
      onKeyEvent: _tombolFisik,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kartuPengaturan(),
                const SizedBox(height: 20),
                _papan(),
                if (_pesan != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _pesan!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: warnaTeks,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _keyboard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuPengaturan() {
    const gayaLabel = TextStyle(color: warnaTeksRedup, fontSize: 13);
    return KartuKaca(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bahasa', style: gayaLabel),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in Bahasa.values)
                PilihanKaca(
                  label: b.nama,
                  dipilih: b == _bahasa,
                  onTap: () => _gantiBahasa(b),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Jumlah huruf', style: gayaLabel),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in panjangTersedia)
                PilihanKaca(
                  label: '$p huruf',
                  dipilih: p == _panjang,
                  onTap: () => _gantiPanjang(p),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TombolUtama(
                label: 'Kata baru',
                ikon: Icons.refresh,
                onPressed: _memuat ? null : _kataBaru,
              ),
              Text(
                'Main $_main   Menang $_menang   Beruntun $_beruntun',
                style: const TextStyle(
                  color: warnaTeks,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _papan() {
    final game = _game;
    if (_memuat) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (game == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, batas) {
        const jarak = 8.0;
        final ukuran = min(
          58.0,
          (batas.maxWidth - jarak * (game.panjang - 1)) / game.panjang,
        );

        return Column(
          children: [
            for (var baris = 0; baris < maksTebakan; baris++) ...[
              _baris(game, baris, ukuran, jarak),
              if (baris < maksTebakan - 1) const SizedBox(height: jarak),
            ],
          ],
        );
      },
    );
  }

  Widget _baris(WordleGame game, int baris, double ukuran, double jarak) {
    final sudahDinilai = baris < game.tebakan.length;
    final sedangDiketik = baris == game.tebakan.length && !game.selesai;

    Widget isi = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var kolom = 0; kolom < game.panjang; kolom++) ...[
          if (sudahDinilai)
            _KotakBerbalik(
              // Kunci unik per sel: animasi flip cuma jalan sekali,
              // saat baris ini pertama kali dinilai.
              key: ValueKey('sel-$baris-$kolom'),
              tunda: kolom,
              child: _KotakHuruf(
                huruf: game.tebakan[baris].$1[kolom],
                status: game.tebakan[baris].$2[kolom],
                ukuran: ukuran,
              ),
            )
          else
            _KotakHuruf(
              huruf: sedangDiketik && kolom < _ketikan.length
                  ? _ketikan[kolom]
                  : '',
              status: StatusHuruf.kosong,
              ukuran: ukuran,
            ),
          if (kolom < game.panjang - 1) SizedBox(width: jarak),
        ],
      ],
    );

    if (sedangDiketik && _getar > 0) {
      isi = TweenAnimationBuilder<double>(
        key: ValueKey('getar-$_getar'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (context, v, child) => Transform.translate(
          offset: Offset(sin(v * pi * 6) * 10 * (1 - v), 0),
          child: child,
        ),
        child: isi,
      );
    }
    return isi;
  }

  Widget _keyboard() {
    final status = _game?.statusKeyboard ?? const <String, StatusHuruf>{};
    const barisHuruf = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

    Widget tombol(String huruf) => Expanded(
          flex: 2,
          child: _TombolKey(
            key: ValueKey('tombol-$huruf'),
            label: huruf.toUpperCase(),
            status: status[huruf] ?? StatusHuruf.kosong,
            onTap: () => _ketik(huruf),
          ),
        );

    return Column(
      children: [
        for (var i = 0; i < barisHuruf.length; i++) ...[
          Row(
            children: [
              if (i == 2)
                Expanded(
                  flex: 3,
                  child: _TombolKey(
                    key: const ValueKey('tombol-enter'),
                    label: 'ENTER',
                    status: StatusHuruf.kosong,
                    onTap: _kirim,
                  ),
                ),
              if (i == 1) const Spacer(),
              for (final h in barisHuruf[i].split('')) tombol(h),
              if (i == 1) const Spacer(),
              if (i == 2)
                Expanded(
                  flex: 3,
                  child: _TombolKey(
                    key: const ValueKey('tombol-hapus'),
                    ikon: Icons.backspace_outlined,
                    status: StatusHuruf.kosong,
                    onTap: _hapus,
                  ),
                ),
            ],
          ),
          if (i < barisHuruf.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Warna isi untuk huruf yang sudah dinilai; null = belum dinilai (kaca).
Color? _warnaStatus(StatusHuruf status) => switch (status) {
      StatusHuruf.benar => warnaHijau,
      StatusHuruf.ada => warnaKuning,
      StatusHuruf.salah => warnaAbu,
      StatusHuruf.kosong => null,
    };

class _KotakHuruf extends StatelessWidget {
  const _KotakHuruf({
    required this.huruf,
    required this.status,
    required this.ukuran,
  });

  final String huruf;
  final StatusHuruf status;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final isi = _warnaStatus(status);
    final terisi = huruf.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isi ??
            (terisi ? const Color(0xB3FFFFFF) : const Color(0x59FFFFFF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isi != null
              ? isi
              : (terisi ? warnaHitam : const Color(0xE6FFFFFF)),
          width: isi == null && terisi ? 2.0 : 1.2,
        ),
        boxShadow: isi == null
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Text(
        huruf.toUpperCase(),
        style: TextStyle(
          fontSize: ukuran * 0.45,
          fontWeight: FontWeight.w800,
          color: isi == null ? warnaTeks : Colors.white,
        ),
      ),
    );
  }
}

/// Efek kartu dibalik (flip) saat huruf dinilai, dengan jeda per kolom.
class _KotakBerbalik extends StatelessWidget {
  const _KotakBerbalik({super.key, required this.tunda, required this.child});

  final int tunda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const durasiFlip = 320;
    const jedaPerKolom = 140;
    final total = durasiFlip + tunda * jedaPerKolom;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(tunda * jedaPerKolom / total, 1, curve: Curves.easeOut),
      builder: (context, v, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX((1 - v) * pi / 2),
        child: child,
      ),
      child: child,
    );
  }
}

class _TombolKey extends StatelessWidget {
  const _TombolKey({
    super.key,
    this.label,
    this.ikon,
    required this.status,
    required this.onTap,
  });

  final String? label;
  final IconData? ikon;
  final StatusHuruf status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isi = _warnaStatus(status);
    final warnaIsi = isi == null ? warnaTeks : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: isi ?? const Color(0x99FFFFFF),
              border: Border.all(color: isi ?? const Color(0xE6FFFFFF)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: ikon != null
                    ? Icon(ikon, size: 20, color: warnaIsi)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: warnaIsi,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
