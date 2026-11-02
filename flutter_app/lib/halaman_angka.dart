import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'harian.dart';
import 'kaca.dart';
import 'komputer.dart';
import 'simpanan.dart';

/// Satu ronde yang sudah selesai, untuk statistik, grafik, dan riwayat.
class Ronde {
  const Ronde({
    required this.mode,
    required this.level,
    required this.rahasia,
    required this.percobaan,
    required this.menang,
  });

  final Mode mode;
  final Level level;
  final int rahasia;
  final int percobaan;
  final bool menang;

  Map<String, Object?> keJson() => {
        'mode': mode.name,
        'level': level.nama,
        'rahasia': rahasia,
        'percobaan': percobaan,
        'menang': menang,
      };

  /// Null kalau datanya rusak atau mode/levelnya sudah tidak ada.
  static Ronde? dariJson(Object? data) {
    if (data is! Map) return null;
    final mode = Mode.values.where((m) => m.name == data['mode']).firstOrNull;
    final level =
        daftarLevel.where((l) => l.nama == data['level']).firstOrNull;
    final rahasia = data['rahasia'];
    final percobaan = data['percobaan'];
    final menang = data['menang'];
    if (mode == null ||
        level == null ||
        rahasia is! int ||
        percobaan is! int ||
        percobaan < 1 ||
        menang is! bool) {
      return null;
    }
    return Ronde(
      mode: mode,
      level: level,
      rahasia: rahasia,
      percobaan: percobaan,
      menang: menang,
    );
  }
}

/// Jenis permainan di halaman Tebak Angka.
enum _Jenis { bebas, harian, komputer }

/// Kunci rekor: rekor dihitung per mode dan per level, karena menang di
/// Mudah dalam 3 percobaan nggak sebanding dengan menang di Sulit.
String kunciRekor(Mode mode, Level level) => '${mode.name}|${level.nama}';

Color warnaSuhu(Suhu suhu) => switch (suhu) {
      Suhu.membeku => const Color(0xFF3B82F6),
      Suhu.dingin => const Color(0xFF06B6D4),
      Suhu.sejuk => const Color(0xFF10B981),
      Suhu.hangat => const Color(0xFFF59E0B),
      Suhu.panas => const Color(0xFFF97316),
      Suhu.membara => const Color(0xFFEF4444),
    };

String teksArah(Arah arah) => switch (arah) {
      Arah.pertama => '',
      Arah.mendekat => 'Makin dekat dari tebakan sebelumnya',
      Arah.menjauh => 'Makin jauh dari tebakan sebelumnya',
      Arah.sama => 'Jaraknya sama dengan tebakan sebelumnya',
    };

IconData ikonArah(Arah arah) => switch (arah) {
      Arah.pertama => Icons.radio_button_unchecked,
      Arah.mendekat => Icons.trending_up,
      Arah.menjauh => Icons.trending_down,
      Arah.sama => Icons.trending_flat,
    };

class HalamanAngka extends StatefulWidget {
  const HalamanAngka({super.key, this.simpanan, this.jam = DateTime.now});

  /// Null = statistik nggak disimpan (hilang saat app ditutup).
  final Simpanan? simpanan;

  /// Sumber waktu untuk tantangan harian. Bisa diganti di test.
  final DateTime Function() jam;

  @override
  State<HalamanAngka> createState() => _HalamanAngkaState();
}

class _HalamanAngkaState extends State<HalamanAngka> {
  final _input = TextEditingController();
  final _fokus = FocusNode();

  Mode _mode = Mode.panasDingin;
  Level _level = daftarLevel.first;
  TebakAngkaGame? _game; // null = belum ada ronde yang dimulai
  String? _pesan;
  final List<HasilTebakan> _tebakan = []; // ronde sekarang, terbaru di depan
  final List<Ronde> _ronde = []; // ronde selesai, terbaru di depan

  // Total sepanjang masa. Dihitung terpisah dari _ronde, karena riwayat
  // yang disimpan dibatasi (lihat _maksSimpan).
  int _jumlahMenang = 0;
  int _jumlahKalah = 0;
  final Map<String, int> _rekorPer = {};

  static const _kunciSimpanan = 'tebak_angka.v1';
  static const _maksSimpan = 50;

  // ---------- tantangan harian ----------

  static const _kunciHarian = 'harian_angka.v1';

  _Jenis _jenis = _Jenis.bebas; // pilihan di layar
  bool _gameHarian = false; // ronde yang sedang/terakhir jalan itu harian

  // Progres harian: tanggal dan tebakan yang sudah dikirim. Disimpan tiap
  // tebakan, jadi menutup app di tengah jalan nggak bisa dipakai buat
  // mengulang dengan angka yang sama.
  String? _harianTanggal;
  final List<int> _harianTebakan = [];

  // ---------- komputer yang menebak ----------

  KomputerMenebak? _komputer;
  int _komputerMenang = 0;
  int _komputerKalah = 0;

  void _mulaiKomputer() {
    setState(() {
      _game = null;
      _gameHarian = false;
      _tebakan.clear();
      _komputer = KomputerMenebak(_level);
      _pesan = 'Pikirkan satu angka antara ${_level.bawah} dan '
          '${_level.atas}. Jangan diketik, cukup diingat.';
    });
  }

  void _jawabKomputer(Jawaban jawaban) {
    final k = _komputer;
    if (k == null || k.selesai) return;
    setState(() {
      k.jawab(jawaban);
      switch (k.status) {
        case StatusKomputer.menang:
          _komputerMenang++;
          _pesan = 'Yes! Aku menebak angkamu dalam ${k.percobaan} percobaan.';
        case StatusKomputer.kalah:
          _komputerKalah++;
          _pesan = 'Aku kalah, percobaan habis. Angkamu ada di antara '
              '${k.bawah} dan ${k.atas}.';
        case StatusKomputer.bertentangan:
          // Nggak dihitung menang/kalah, sama seperti versi Python.
          _pesan = 'Hmm, jawabanmu saling bertentangan. '
              'Nggak ada angka yang cocok.';
        case StatusKomputer.berjalan:
          _pesan = null;
      }
    });
    if (k.selesai) _simpan();
  }

  @override
  void initState() {
    super.initState();
    _muat();
    _muatHarian();
  }

  void _muatHarian() {
    final data = widget.simpanan?.baca(_kunciHarian);
    if (data == null) return;
    final tanggal = data['tanggal'];
    final tebakan = data['tebakan'];
    if (tanggal is! String || tebakan is! List) return;
    _harianTanggal = tanggal;
    _harianTebakan.addAll([
      for (final t in tebakan)
        if (t is int && t >= levelHarian.bawah && t <= levelHarian.atas) t,
    ]);
  }

  void _simpanHarian() {
    widget.simpanan?.tulis(_kunciHarian, {
      'tanggal': _harianTanggal,
      'tebakan': _harianTebakan,
    });
  }

  /// Bangun ulang ronde harian hari ini dari tebakan yang tersimpan.
  (TebakAngkaGame, List<HasilTebakan>) _putarUlangHarian() {
    final sekarang = widget.jam();
    final game = TebakAngkaGame.denganRahasia(
        levelHarian, angkaHarian(sekarang));
    final hasil = <HasilTebakan>[];
    if (_harianTanggal == kunciTanggal(sekarang)) {
      for (final angka in _harianTebakan) {
        if (game.selesai) break;
        hasil.add(game.tebak(angka));
      }
    }
    return (game, hasil);
  }

  void _mulaiHarian() {
    final sekarang = widget.jam();
    if (_harianTanggal != kunciTanggal(sekarang)) {
      _harianTanggal = kunciTanggal(sekarang);
      _harianTebakan.clear();
      _simpanHarian();
    }
    final (game, hasil) = _putarUlangHarian();
    if (game.selesai) return;
    setState(() {
      _komputer = null;
      _game = game;
      _gameHarian = true;
      _tebakan
        ..clear()
        ..addAll(hasil.reversed);
      _pesan = hasil.isEmpty
          ? 'Tantangan #${nomorHarian(sekarang)}: semua pemain dapat angka '
              'yang sama hari ini.'
          : 'Lanjut dari tebakan terakhirmu.';
      _input.clear();
    });
    _fokus.requestFocus();
  }

  Future<void> _salinHasilHarian() async {
    final (game, hasil) = _putarUlangHarian();
    final teks =
        teksBagikanAngka(nomorHarian(widget.jam()), hasil, game.menang);
    await Clipboard.setData(ClipboardData(text: teks));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hasil disalin. Tempel di chat atau story.')),
    );
  }

  void _muat() {
    final data = widget.simpanan?.baca(_kunciSimpanan);
    if (data == null) return;

    _mode = Mode.values.where((m) => m.name == data['mode']).firstOrNull ??
        _mode;
    _level =
        daftarLevel.where((l) => l.nama == data['level']).firstOrNull ?? _level;
    _jumlahMenang = angkaAman(data['menang']);
    _jumlahKalah = angkaAman(data['kalah']);
    final komputer = data['komputer'];
    if (komputer is Map) {
      _komputerMenang = angkaAman(komputer['menang']);
      _komputerKalah = angkaAman(komputer['kalah']);
    }

    final rekor = data['rekor'];
    if (rekor is Map) {
      for (final MapEntry(:key, :value) in rekor.entries) {
        if (key is String && value is int && value >= 1) _rekorPer[key] = value;
      }
    }
    final ronde = data['ronde'];
    if (ronde is List) {
      _ronde.addAll(ronde.map(Ronde.dariJson).whereType<Ronde>());
    }
  }

  void _simpan() {
    widget.simpanan?.tulis(_kunciSimpanan, {
      'mode': _mode.name,
      'level': _level.nama,
      'menang': _jumlahMenang,
      'kalah': _jumlahKalah,
      'komputer': {'menang': _komputerMenang, 'kalah': _komputerKalah},
      'rekor': _rekorPer,
      'ronde': [for (final r in _ronde.take(_maksSimpan)) r.keJson()],
    });
  }

  void _pilihMode(Mode mode) {
    setState(() => _mode = mode);
    _simpan();
  }

  void _pilihLevel(Level level) {
    setState(() => _level = level);
    _simpan();
  }

  @override
  void dispose() {
    _input.dispose();
    _fokus.dispose();
    super.dispose();
  }

  // ---------- statistik ----------

  int get _jumlahRonde => _jumlahMenang + _jumlahKalah;

  String get _winRate => _jumlahRonde == 0
      ? '-'
      : '${(_jumlahMenang * 100 / _jumlahRonde).round()}%';

  /// Mode dan level yang rekornya ditampilkan: ronde yang sedang jalan,
  /// atau pilihan di layar pilih level.
  Mode get _modeTampil => _game?.mode ?? _mode;
  Level get _levelTampil => _game?.level ?? _level;

  String get _rekor {
    final nilai = _rekorPer[kunciRekor(_modeTampil, _levelTampil)];
    return nilai == null ? '-' : '$nilai percobaan';
  }

  /// Riwayat dan grafik cuma menampilkan ronde terakhir sebanyak ini.
  static const _maksTampil = 10;

  /// Contoh: "10 dari 15 ronde terakhir. Hitam menang, abu-abu kalah"
  String _keteranganJumlah(String tambahan) {
    final bagian = <String>[
      if (_jumlahRonde > _maksTampil)
        '$_maksTampil dari $_jumlahRonde ronde terakhir.',
      if (tambahan.isNotEmpty) tambahan,
    ];
    return bagian.join(' ');
  }

  // ---------- aksi ----------

  void _mulai() {
    setState(() {
      _komputer = null;
      _gameHarian = false;
      _game = TebakAngkaGame(_level, mode: _mode);
      _pesan = 'Aku sudah pilih angka antara ${_level.bawah} dan ${_level.atas}.';
      _tebakan.clear();
      _input.clear();
    });
    _fokus.requestFocus();
  }

  void _kirim() {
    final game = _game;
    if (game == null || game.selesai) return;

    final parse = parseTebakan(_input.text, game.level);
    if (parse.error != null) {
      setState(() => _pesan = parse.error);
      // Teks salah tetap terlihat, tapi diblok semua: ketikan berikutnya
      // langsung menimpa, nggak menumpuk jadi "999".
      _input.selection =
          TextSelection(baseOffset: 0, extentOffset: _input.text.length);
      _fokus.requestFocus();
      return;
    }

    final hasil = game.tebak(parse.angka!);
    if (_gameHarian) {
      _harianTebakan.add(hasil.angka);
      _simpanHarian();
    }

    setState(() {
      _input.clear();
      _tebakan.insert(0, hasil);

      if (hasil.benar) {
        _pesan = 'Benar! Angkanya ${game.rahasia}. '
            'Kamu menang dalam ${game.percobaan} percobaan.';
      } else if (game.selesai) {
        _pesan = 'Percobaan habis. Angka yang benar: ${game.rahasia}.';
      } else if (hasil.suhu != null) {
        _pesan = '${hasil.angka}: ${hasil.suhu!.label}!';
      } else if (hasil.petunjukBaru != null) {
        _pesan = '${hasil.angka} bukan jawabannya. Ada petunjuk baru.';
      } else {
        _pesan = '${hasil.angka} bukan jawabannya. Petunjuk sudah habis.';
      }

      if (game.selesai) {
        _ronde.insert(
          0,
          Ronde(
            mode: game.mode,
            level: game.level,
            rahasia: game.rahasia,
            percobaan: game.percobaan,
            menang: game.menang,
          ),
        );
        if (_ronde.length > _maksSimpan) _ronde.removeLast();
        if (game.menang) {
          _jumlahMenang++;
          final kunci = kunciRekor(game.mode, game.level);
          final lama = _rekorPer[kunci];
          if (lama == null || game.percobaan < lama) {
            _rekorPer[kunci] = game.percobaan;
            _pesan = '$_pesan Rekor baru!';
          }
        } else {
          _jumlahKalah++;
        }
      }
    });
    if (game.selesai) _simpan();

    if (!game.selesai) _fokus.requestFocus();
  }

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        final lebar = batas.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lebar)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _kartuMain()),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _kartuStatistik()),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _kartuGrafik()),
                      ],
                    )
                  else ...[
                    _kartuMain(),
                    const SizedBox(height: 20),
                    _kartuStatistik(),
                    const SizedBox(height: 20),
                    _kartuGrafik(),
                  ],
                  const SizedBox(height: 20),
                  _kartuRiwayat(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _judul(String teks) => Text(
        teks,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: warnaTeks,
        ),
      );

  Widget _label(String teks) => Text(
        teks,
        style: const TextStyle(color: warnaTeksRedup, fontSize: 13),
      );

  Widget _kartuMain() {
    final game = _game;
    final komputer = _komputer;

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _judul('Ronde sekarang'),
          const SizedBox(height: 16),
          if (game != null && !game.selesai)
            ..._areaMain(game)
          else if (komputer != null && !komputer.selesai)
            ..._areaKomputer(komputer)
          else
            ..._areaPilih(),
          if (_pesan != null) ...[
            const SizedBox(height: 16),
            Text(
              _pesan!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: warnaTeks,
              ),
            ),
          ],
          if (_tebakan.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label('Tebakan ronde ini'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in _tebakan) _chipTebakan(t)],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _areaPilih() => [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (jenis, label) in const [
              (_Jenis.bebas, 'Main bebas'),
              (_Jenis.harian, 'Tantangan harian'),
              (_Jenis.komputer, 'Komputer menebak'),
            ])
              PilihanKaca(
                label: label,
                dipilih: _jenis == jenis,
                onTap: () => setState(() => _jenis = jenis),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...switch (_jenis) {
          _Jenis.bebas => _areaPilihBebas(),
          _Jenis.harian => _areaHarian(),
          _Jenis.komputer => _areaPilihKomputer(),
        },
      ];

  Widget _pilihanLevel() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final level in daftarLevel)
            PilihanKaca(
              label: level.nama,
              dipilih: level == _level,
              onTap: () => _pilihLevel(level),
            ),
        ],
      );

  List<Widget> _areaPilihKomputer() => [
        _label('Kamu pikirkan angkanya, aku yang menebak. Aku pakai binary '
            'search: selalu menebak tengah-tengah, jadi tiap jawabanmu '
            'memotong kemungkinan jadi setengah.'),
        const SizedBox(height: 14),
        _label('Pilih level'),
        const SizedBox(height: 6),
        _pilihanLevel(),
        const SizedBox(height: 6),
        _label('Angka ${_level.bawah}-${_level.atas}, aku punya '
            '${_level.nyawa} percobaan'),
        const SizedBox(height: 6),
        _label('Skor komputer: $_komputerMenang menang, $_komputerKalah kalah'),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: 'Mulai',
            ikon: Icons.play_arrow_rounded,
            onPressed: _mulaiKomputer,
          ),
        ),
      ];

  List<Widget> _areaKomputer(KomputerMenebak k) => [
        _label('Level ${k.level.nama} - tebakan ke-${k.percobaan} '
            'dari ${k.level.nyawa}'),
        const SizedBox(height: 4),
        Text(
          'Aku tebak ${k.tebakan}',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: warnaTeks,
          ),
        ),
        const SizedBox(height: 14),
        _barRentang(k),
        const SizedBox(height: 6),
        _label('Sisa kemungkinan: ${k.sisaKemungkinan} angka '
            '(${k.bawah}-${k.atas})'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PilihanKaca(
              label: 'Terlalu besar',
              dipilih: false,
              onTap: () => _jawabKomputer(Jawaban.terlaluBesar),
            ),
            PilihanKaca(
              label: 'Terlalu kecil',
              dipilih: false,
              onTap: () => _jawabKomputer(Jawaban.terlaluKecil),
            ),
            TombolUtama(
              label: 'Benar!',
              onPressed: () => _jawabKomputer(Jawaban.benar),
            ),
          ],
        ),
      ];

  /// Bar seluruh rentang level, dengan bagian yang masih mungkin disorot
  /// hitam dan penanda di posisi tebakan. Kelihatan menyempit tiap jawaban.
  Widget _barRentang(KomputerMenebak k) {
    final lebarLevel = k.level.atas - k.level.bawah + 1;
    final mulai = (k.bawah - k.level.bawah) / lebarLevel;
    final akhir = (k.atas - k.level.bawah + 1) / lebarLevel;
    final posisi = (k.tebakan - k.level.bawah + 0.5) / lebarLevel;

    return LayoutBuilder(
      builder: (context, batas) {
        final w = batas.maxWidth;
        return SizedBox(
          height: 22,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 7,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x260F172A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                left: w * mulai,
                width: (w * (akhir - mulai)).clamp(4.0, w),
                top: 7,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: warnaHitam,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                left: (w * posisi - 11).clamp(0.0, w - 22),
                top: 0,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: warnaHitam, width: 4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _areaHarian() {
    final sekarang = widget.jam();
    final (game, hasil) = _putarUlangHarian();
    final nomor = nomorHarian(sekarang);

    if (game.selesai) {
      return [
        _label('Tantangan #$nomor'),
        const SizedBox(height: 4),
        Text(
          game.menang
              ? 'Kamu menang dalam ${hasil.length} percobaan.'
              : 'Belum beruntung. Angkanya ${game.rahasia}.',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: warnaTeks,
          ),
        ),
        const SizedBox(height: 6),
        _label('Tantangan berikutnya besok.'),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: 'Salin hasil',
            ikon: Icons.share_outlined,
            onPressed: _salinHasilHarian,
          ),
        ),
      ];
    }

    return [
      _label('Tantangan #$nomor - Panas-Dingin, angka '
          '${levelHarian.bawah}-${levelHarian.atas}, '
          '${levelHarian.nyawa} percobaan'),
      const SizedBox(height: 6),
      _label('Semua pemain dapat angka yang sama hari ini, '
          'dan cuma bisa dimainkan sekali.'),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: TombolUtama(
          label: hasil.isEmpty ? 'Mulai' : 'Lanjutkan',
          ikon: Icons.play_arrow_rounded,
          onPressed: _mulaiHarian,
        ),
      ),
    ];
  }

  List<Widget> _areaPilihBebas() => [
        _label('Mode'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in Mode.values)
              PilihanKaca(
                label: m.nama,
                dipilih: m == _mode,
                onTap: () => _pilihMode(m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _label(_mode.deskripsi),
        const SizedBox(height: 14),
        _label('Pilih level'),
        const SizedBox(height: 6),
        _pilihanLevel(),
        const SizedBox(height: 6),
        _label('Angka ${_level.bawah}-${_level.atas}, ${_level.nyawa} percobaan'),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: 'Mulai',
            ikon: Icons.play_arrow_rounded,
            onPressed: _mulai,
          ),
        ),
      ];

  List<Widget> _areaMain(TebakAngkaGame game) {
    final terakhir = _tebakan.isEmpty ? null : _tebakan.first;
    return [
      _label('${game.mode.nama} - Level ${game.level.nama} '
          '(${game.level.bawah}-${game.level.atas})'),
      const SizedBox(height: 4),
      Text(
        'Sisa percobaan: ${game.sisa} dari ${game.level.nyawa}',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: warnaTeks,
        ),
      ),
      const SizedBox(height: 10),
      _barGradasi(game.sisa / game.level.nyawa),
      const SizedBox(height: 18),
      if (game.mode == Mode.panasDingin) ...[
        _meteranSuhu(terakhir?.suhu),
        if (terakhir != null && terakhir.arah != Arah.pertama) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(ikonArah(terakhir.arah), size: 18, color: warnaTeksRedup),
              const SizedBox(width: 6),
              Expanded(child: _label(teksArah(terakhir.arah))),
            ],
          ),
        ],
      ] else
        _daftarPetunjuk(game),
      const SizedBox(height: 18),
      Row(
        // Key wajib di sini. Baris "makin dekat/jauh" di atas baru muncul
        // mulai tebakan kedua; tanpa key, Flutter menganggap baris input
        // ini widget baru, membuangnya, dan bikin ulang TextField-nya,
        // sehingga fokus dan sambungan keyboard hilang.
        key: const ValueKey('baris-input'),
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _fokus,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxTebakanDigits),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _kirim(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: warnaTeks,
              ),
              decoration: InputDecoration(
                hintText: 'Tebakan kamu',
                filled: true,
                fillColor: const Color(0x99FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xCCFFFFFF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xCCFFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: warnaHitam, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TombolUtama(label: 'Tebak', onPressed: _kirim),
        ],
      ),
    ];
  }

  Widget _barGradasi(double nilai) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: const Color(0x331E1B4B),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          widthFactor: nilai.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: warnaHitam),
          ),
        ),
      ),
    );
  }

  /// Meteran dari biru (membeku) sampai merah (membara), dengan penanda
  /// yang bergeser ke suhu tebakan terakhir.
  Widget _meteranSuhu(Suhu? suhu) {
    final posisi = suhu == null ? 0.0 : suhu.index / (Suhu.values.length - 1);
    final warna = suhu == null ? warnaTeksRedup : warnaSuhu(suhu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.thermostat, color: warna),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: warna,
                ),
                child: Text(suhu?.label ?? 'Ayo tebak dulu'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [for (final s in Suhu.values) warnaSuhu(s)],
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                alignment: Alignment(posisi * 2 - 1, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: suhu == null ? 0 : 1,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: warna, width: 4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _daftarPetunjuk(TebakAngkaGame game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Petunjuk (${game.petunjukTerbuka.length} terbuka)'),
        const SizedBox(height: 8),
        for (final p in game.petunjukTerbuka)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x8CFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xCCFFFFFF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: warnaTeksRedup),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: warnaTeks,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _chipTebakan(HasilTebakan t) {
    final suhu = t.suhu;
    final Color warna;
    final String keterangan;
    if (t.benar) {
      warna = warnaHijau;
      keterangan = 'benar';
    } else if (suhu != null) {
      warna = warnaSuhu(suhu);
      keterangan = suhu.label.toLowerCase();
    } else {
      warna = warnaTeks;
      keterangan = 'salah';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withAlpha(0x2E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: warna.withAlpha(0x99)),
      ),
      child: Text(
        '${t.angka} $keterangan',
        style: TextStyle(color: warna, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _kartuStatistik() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kartuAngka(
                'Menang',
                '$_jumlahMenang',
                Icons.emoji_events_outlined,
                aksen: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _kartuAngka('Kalah', '$_jumlahKalah', Icons.close)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _kartuAngka('Win rate', _winRate, Icons.percent)),
            const SizedBox(width: 16),
            Expanded(
              child: _kartuAngka(
                'Rekor ${_modeTampil.nama} ${_levelTampil.nama}',
                _rekor,
                Icons.bolt,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kartuAngka(String judul, String nilai, IconData ikon,
      {bool aksen = false}) {
    final warna = aksen ? Colors.white : warnaTeks;
    final warnaRedup = aksen ? const Color(0xD9FFFFFF) : warnaTeksRedup;

    return AngkatSaatHover(
      child: KartuKaca(
        gelap: aksen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 18, color: warnaRedup),
                const SizedBox(width: 6),
                Expanded(child: Text(judul, style: TextStyle(color: warnaRedup))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              nilai,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: warna,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuGrafik() {
    // 10 ronde terakhir, yang paling lama di kiri.
    final data = _ronde.take(_maksTampil).toList().reversed.toList();
    final tertinggi = data.isEmpty
        ? 1
        : data.map((r) => r.percobaan).reduce((a, b) => a > b ? a : b);

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _judul('Percobaan per ronde'),
          const SizedBox(height: 4),
          _label(_keteranganJumlah('Hitam menang, abu-abu kalah')),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: data.isEmpty
                ? Center(child: _label('Belum ada ronde selesai.'))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final r in data)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${r.percobaan}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: warnaTeks,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: 140 * r.percobaan / tertinggi,
                                  ),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, tinggi, _) => Container(
                                    height: tinggi,
                                    decoration: BoxDecoration(
                                      color: r.menang
                                          ? warnaHitam
                                          : const Color(0x8094A3B8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kartuRiwayat() {
    const gayaKepala = TextStyle(color: warnaTeksRedup, fontSize: 12);
    const gayaIsi = TextStyle(color: warnaTeks, fontWeight: FontWeight.w500);

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _judul('Riwayat ronde'),
          if (_jumlahRonde > _maksTampil) ...[
            const SizedBox(height: 4),
            _label(_keteranganJumlah('')),
          ],
          const SizedBox(height: 12),
          if (_ronde.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _label('Selesaikan satu ronde, hasilnya muncul di sini.'),
            )
          else ...[
            const Row(
              children: [
                Expanded(child: Text('Mode', style: gayaKepala)),
                Expanded(child: Text('Level', style: gayaKepala)),
                Expanded(child: Text('Angka', style: gayaKepala)),
                Expanded(child: Text('Percobaan', style: gayaKepala)),
                Expanded(child: Text('Hasil', style: gayaKepala)),
              ],
            ),
            const Divider(color: Color(0x331E1B4B)),
            for (final r in _ronde.take(_maksTampil))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(r.mode.nama, style: gayaIsi)),
                    Expanded(child: Text(r.level.nama, style: gayaIsi)),
                    Expanded(child: Text('${r.rahasia}', style: gayaIsi)),
                    Expanded(child: Text('${r.percobaan}', style: gayaIsi)),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: r.menang ? warnaHitam : const Color(0x4D94A3B8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r.menang ? 'Menang' : 'Kalah',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: r.menang ? Colors.white : warnaTeks,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
