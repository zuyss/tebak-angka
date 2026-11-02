import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'duel.dart';
import 'game.dart';
import 'harian.dart';
import 'kaca.dart';
import 'komputer.dart';
import 'pencapaian.dart';
import 'pengaturan.dart';
import 'rahasia.dart' show cocokUlar, kodeArsip;
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
enum _Jenis { bebas, harian, komputer, duel }

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

String teksArah(BuildContext context, Arah arah) => switch (arah) {
      Arah.pertama => '',
      Arah.mendekat => context.tr('Makin dekat dari tebakan sebelumnya', 'Closer than your last guess'),
      Arah.menjauh => context.tr('Makin jauh dari tebakan sebelumnya', 'Further than your last guess'),
      Arah.sama => context.tr('Jaraknya sama dengan tebakan sebelumnya', 'Same distance as your last guess'),
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
      _duel = null;
      _gameDuel = false;
      _gameHarian = false;
      _tebakan.clear();
      _komputer = KomputerMenebak(_level);
      _pesan = context.tr('Pikirkan satu angka antara ${_level.bawah} dan '
          '${_level.atas}. Jangan diketik, cukup diingat.', 'Think of a number between ${_level.bawah} and ${_level.atas}. No need to type it, just remember it.');
    });
  }

  void _jawabKomputer(Jawaban jawaban) {
    final k = _komputer;
    if (k == null || k.selesai) return;
    PengaturanScope.baca(context)
        ?.getarkan(kuat: jawaban == Jawaban.benar);
    setState(() {
      k.jawab(jawaban);
      switch (k.status) {
        case StatusKomputer.menang:
          _komputerMenang++;
          _pesan = context.tr('Yes! Aku menebak angkamu dalam ${k.percobaan} percobaan.', 'Yes! I guessed your number in ${k.percobaan} tries.');
        case StatusKomputer.kalah:
          _komputerKalah++;
          _pesan = context.tr('Aku kalah, percobaan habis. Angkamu ada di antara '
              '${k.bawah} dan ${k.atas}.', 'I lost, out of tries. Your number is between ${k.bawah} and ${k.atas}.');
        case StatusKomputer.bertentangan:
          // Nggak dihitung menang/kalah, sama seperti versi Python.
          _pesan = context.tr('Hmm, jawabanmu saling bertentangan. '
              'Nggak ada angka yang cocok.', 'Hmm, your answers contradict each other. No number fits.');
        case StatusKomputer.berjalan:
          _pesan = null;
      }
    });
    if (k.selesai) _simpan();
    if (k.status == StatusKomputer.bertentangan) {
      bukaLencana(context, ['komputer_curang']);
    }
  }

  // ---------- duel 2 pemain ----------

  Duel? _duel;
  bool _gameDuel = false; // ronde yang sedang jalan adalah giliran duel
  final _inputRahasia = TextEditingController();

  bool get _duelMenungguRahasia =>
      _duel?.tahap == TahapDuel.rahasia1 || _duel?.tahap == TahapDuel.rahasia2;

  void _mulaiDuel() {
    setState(() {
      _game = null;
      _komputer = null;
      _gameHarian = false;
      _gameDuel = false;
      _tebakan.clear();
      _inputRahasia.clear();
      _duel = Duel(nyawa: _level.nyawa);
      _pesan = null;
    });
  }

  void _batalDuel() {
    setState(() {
      _duel = null;
      _game = null;
      _gameDuel = false;
      _tebakan.clear();
      _pesan = context.tr('Duel dibatalkan.', 'Duel cancelled.');
    });
  }

  void _kunciRahasia() {
    final duel = _duel;
    if (duel == null || !_duelMenungguRahasia) return;
    final parse = parseTebakan(_inputRahasia.text, _level);
    if (parse.error != null) {
      setState(() => _pesan = context.dua(parse.error!));
      return;
    }
    final penebak = duel.tahap == TahapDuel.rahasia1 ? 2 : 1;
    setState(() {
      duel.rahasiaSiap();
      _game = TebakAngkaGame.denganRahasia(_level, parse.angka!);
      _gameDuel = true;
      _inputRahasia.clear();
      _tebakan.clear();
      _pesan = context.tr('Pemain $penebak, giliranmu menebak.', 'Player $penebak, your turn to guess.');
    });
    _fokus.requestFocus();
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
      _duel = null;
      _gameDuel = false;
      _game = game;
      _gameHarian = true;
      _tebakan
        ..clear()
        ..addAll(hasil.reversed);
      _pesan = hasil.isEmpty
          ? context.tr('Tantangan #${nomorHarian(sekarang)}: semua pemain dapat angka '
              'yang sama hari ini.', 'Challenge #${nomorHarian(sekarang)}: every player gets the same number today.')
          : context.tr('Lanjut dari tebakan terakhirmu.', 'Continuing from your last guess.');
      _input.clear();
    });
    _fokus.requestFocus();
  }

  Future<void> _salinHasilHarian() async {
    final (game, hasil) = _putarUlangHarian();
    final teks =
        teksBagikanAngka(nomorHarian(widget.jam()), hasil, game.menang,
            inggris: context.inggris);
    await Clipboard.setData(ClipboardData(text: teks));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Hasil disalin. Tempel di chat atau story.', 'Result copied. Paste it in a chat or story.'))),
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
    _inputRahasia.dispose();
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
        context.tr('$_maksTampil dari $_jumlahRonde ronde terakhir.', 'Last $_maksTampil of $_jumlahRonde rounds.'),
      if (tambahan.isNotEmpty) tambahan,
    ];
    return bagian.join(' ');
  }

  // ---------- aksi ----------

  void _mulai() {
    setState(() {
      _duel = null;
      _gameDuel = false;
      _komputer = null;
      _gameHarian = false;
      _game = TebakAngkaGame(_level, mode: _mode);
      _pesan = context.tr('Aku sudah pilih angka antara ${_level.bawah} dan ${_level.atas}.', 'I have picked a number between ${_level.bawah} and ${_level.atas}.');
      _tebakan.clear();
      _input.clear();
    });
    _fokus.requestFocus();
  }

  void _kirim() {
    final game = _game;
    if (game == null || game.selesai) return;

    // Rahasia: kode arsip lengkap diketik di sini (angkanya terlalu besar
    // untuk level mana pun, jadi biasanya cuma ditolak).
    final pencapaian = PencapaianScope.baca(context);
    if (pencapaian != null &&
        pencapaian.fragmenLengkap &&
        !pencapaian.terbuka('arsip') &&
        kodeArsip(_input.text)) {
      setState(() {
        _input.clear();
        _pesan = context.tr(
            'Arsip terbuka. Tema rahasia "Fosfor" sekarang ada di Pengaturan.',
            'Archive unlocked. The secret "Phosphor" theme is now in Settings.');
      });
      bukaLencana(context, ['arsip']);
      _fokus.requestFocus();
      return;
    }

    final parse = parseTebakan(_input.text, game.level);
    if (parse.error != null) {
      setState(() => _pesan = context.dua(parse.error!));
      // Teks salah tetap terlihat, tapi diblok semua: ketikan berikutnya
      // langsung menimpa, nggak menumpuk jadi "999".
      _input.selection =
          TextSelection(baseOffset: 0, extentOffset: _input.text.length);
      _fokus.requestFocus();
      return;
    }

    final hasil = game.tebak(parse.angka!);
    PengaturanScope.baca(context)?.getarkan(kuat: game.selesai);
    if (_gameHarian) {
      _harianTebakan.add(hasil.angka);
      _simpanHarian();
    }

    final duel = _duel;
    if (_gameDuel && duel != null) {
      setState(() {
        _input.clear();
        _tebakan.insert(0, hasil);
        final penebak = duel.pemainAktif;
        if (game.selesai) {
          duel.selesaiMenebak(menang: game.menang, percobaan: game.percobaan);
          _gameDuel = false;
          _pesan = game.menang
              ? context.tr('Pemain $penebak menebak ${game.rahasia} dalam '
                  '${game.percobaan} percobaan.', 'Player $penebak guessed ${game.rahasia} in ${game.percobaan} tries.')
              : context.tr('Pemain $penebak gagal. Angkanya ${game.rahasia}.', 'Player $penebak failed. The number was ${game.rahasia}.');
          if (duel.tahap == TahapDuel.selesai) {
            _pesan = '$_pesan ${_teksHasilDuel(duel)}';
          } else {
            _pesan = context.tr('$_pesan Sekarang Pemain 2 bikin angka rahasia.', '$_pesan Now Player 2 picks a secret number.');
          }
        } else {
          _pesan = context.tr('${hasil.angka}: ${hasil.suhu!.label}!', '${hasil.angka}: ${hasil.suhu!.labelEn}!');
        }
      });
      if (!game.selesai) _fokus.requestFocus();
      if (duel.tahap == TahapDuel.selesai) {
        bukaLencana(context, ['duel_pertama']);
      }
      return;
    }

    // Rahasia: menang di percobaan terakhir memberi fragmen arsip.
    final fragmen = game.menang && game.sisa == 0 && !_gameHarian
        ? catatFragmen(context, 'angka')
        : null;

    setState(() {
      _input.clear();
      _tebakan.insert(0, hasil);

      if (hasil.benar) {
        _pesan = context.tr('Benar! Angkanya ${game.rahasia}. '
            'Kamu menang dalam ${game.percobaan} percobaan.', 'Correct! The number is ${game.rahasia}. You won in ${game.percobaan} tries.');
      } else if (game.selesai) {
        _pesan = context.tr('Percobaan habis. Angka yang benar: ${game.rahasia}.', 'Out of tries. The right number was ${game.rahasia}.');
      } else if (hasil.suhu != null) {
        _pesan = context.tr('${hasil.angka}: ${hasil.suhu!.label}!', '${hasil.angka}: ${hasil.suhu!.labelEn}!');
      } else if (hasil.petunjukBaru != null) {
        _pesan = context.tr('${hasil.angka} bukan jawabannya. Ada petunjuk baru.', '${hasil.angka} is not it. New clue unlocked.');
      } else {
        _pesan = context.tr('${hasil.angka} bukan jawabannya. Petunjuk sudah habis.', '${hasil.angka} is not it. No clues left.');
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
            _pesan = context.tr('$_pesan Rekor baru!', '$_pesan New record!');
          }
        } else {
          _jumlahKalah++;
        }
      }
      if (fragmen != null) _pesan = '$_pesan $fragmen';
    });

    // Rahasia: lima tebakan pertama tertentu di level Sedang membangunkan ular.
    final pencapaianUlar = PencapaianScope.baca(context);
    if (!_gameHarian &&
        game.level == daftarLevel[1] &&
        _tebakan.length == 5 &&
        pencapaianUlar != null &&
        !pencapaianUlar.terbuka('ular') &&
        cocokUlar(_tebakan.reversed.map((h) => h.angka))) {
      setState(() {
        _pesan = context.tr(
            'Sssst... sesuatu merayap keluar dari terminal. Cek menu root.',
            'Hsssss... something crawled out of the terminal. Check the root menu.');
      });
      bukaLencana(context, ['ular']);
    }

    if (game.selesai) {
      _simpan();
      final sulit = game.level == daftarLevel.last;
      if (game.menang) {
        bukaLencana(context, [
          'menang_pertama',
          if (game.percobaan == 1) 'sekali_tebak',
          if (sulit && game.mode == Mode.panasDingin) 'panas_sulit',
          if (sulit && game.mode == Mode.detektif) 'detektif_sulit',
        ]);
      }
      final tanggal = _harianTanggal;
      if (_gameHarian && tanggal != null) catatHarianSelesai(context, tanggal);
    } else {
      _fokus.requestFocus();
    }
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
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.palet.teks,
        ),
      );

  Widget _label(String teks) => Text(
        teks,
        style: TextStyle(color: context.palet.teksRedup, fontSize: 13),
      );

  Widget _kartuMain() {
    final game = _game;
    final komputer = _komputer;

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _judul(context.tr('Ronde sekarang', 'Current round')),
          const SizedBox(height: 16),
          if (game != null && !game.selesai)
            ..._areaMain(game)
          else if (komputer != null && !komputer.selesai)
            ..._areaKomputer(komputer)
          else if (_duelMenungguRahasia)
            ..._areaRahasiaDuel()
          else
            ..._areaPilih(),
          if (_pesan != null) ...[
            const SizedBox(height: 16),
            Text(
              _pesan!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.palet.teks,
              ),
            ),
          ],
          if (_tebakan.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label(context.tr('Tebakan ronde ini', 'Guesses this round')),
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
            for (final (jenis, label) in [
              (_Jenis.bebas, context.tr('Main bebas', 'Free play')),
              (_Jenis.harian, context.tr('Tantangan harian', 'Daily challenge')),
              (_Jenis.komputer, context.tr('Komputer menebak', 'Computer guesses')),
              (_Jenis.duel, 'Duel'),
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
          _Jenis.duel => _areaPilihDuel(),
        },
      ];

  Widget _pilihanLevel() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final level in daftarLevel)
            PilihanKaca(
              label: context.tr(level.nama, level.namaEn),
              dipilih: level == _level,
              onTap: () => _pilihLevel(level),
            ),
        ],
      );

  String _teksHasilDuel(Duel duel) => switch (duel.hasil) {
        HasilDuel.pemain1 => context.tr('Pemain 1 menang!', 'Player 1 wins!'),
        HasilDuel.pemain2 => context.tr('Pemain 2 menang!', 'Player 2 wins!'),
        HasilDuel.seri => context.tr('Seri!', 'Draw!'),
        null => '',
      };

  List<Widget> _areaPilihDuel() {
    final duel = _duel;
    return [
      _label(context.tr('Dua pemain, satu perangkat. Pemain 1 bikin angka rahasia, '
          'Pemain 2 menebak (pakai petunjuk Panas-Dingin). Lalu gantian. '
          'Yang butuh percobaan paling sedikit menang.', 'Two players, one device. Player 1 picks a secret number, Player 2 guesses it (with Hot-Cold hints). Then swap. Fewest tries wins.')),
      const SizedBox(height: 14),
      _label(context.tr('Pilih level', 'Choose a level')),
      const SizedBox(height: 6),
      _pilihanLevel(),
      const SizedBox(height: 6),
      _label(context.tr('Angka ${_level.bawah}-${_level.atas}, '
          '${_level.nyawa} percobaan per giliran', 'Numbers ${_level.bawah}-${_level.atas}, ${_level.nyawa} tries per turn')),
      if (duel != null && duel.tahap == TahapDuel.selesai) ...[
        const SizedBox(height: 14),
        Text(
          _teksHasilDuel(duel),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.palet.teks,
          ),
        ),
        const SizedBox(height: 4),
        _label(context.tr('Pemain 1: ${duel.teksSkor(duel.skor1)}   '
            'Pemain 2: ${duel.teksSkor(duel.skor2)}', 'Player 1: ${duel.teksSkor(duel.skor1, inggris: true)}   Player 2: ${duel.teksSkor(duel.skor2, inggris: true)}')),
      ],
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: TombolUtama(
          label: duel == null ? context.tr('Mulai duel', 'Start duel') : context.tr('Duel lagi', 'Rematch'),
          ikon: Icons.people_outline,
          onPressed: _mulaiDuel,
        ),
      ),
    ];
  }

  List<Widget> _areaRahasiaDuel() {
    final duel = _duel!;
    final pembuat = duel.pemainAktif;
    final penebak = pembuat == 1 ? 2 : 1;
    return [
      _label(context.tr('Duel - Level ${_level.nama}', 'Duel - Level ${_level.namaEn}')),
      const SizedBox(height: 4),
      Text(
        context.tr('Pemain $pembuat, bikin angka rahasia', 'Player $pembuat, pick a secret number'),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.palet.teks,
        ),
      ),
      const SizedBox(height: 4),
      _label(context.tr('Angka ${_level.bawah}-${_level.atas}. '
          'Pemain $penebak jangan lihat layar dulu!', 'Numbers ${_level.bawah}-${_level.atas}. Player $penebak, do not look at the screen yet!')),
      if (duel.skor2 != null) ...[
        const SizedBox(height: 4),
        _label(context.tr('Skor Pemain 2: ${duel.teksSkor(duel.skor2)}', 'Player 2 score: ${duel.teksSkor(duel.skor2, inggris: true)}')),
      ],
      const SizedBox(height: 14),
      Row(
        key: const ValueKey('baris-rahasia-duel'),
        children: [
          Expanded(
            child: TextField(
              controller: _inputRahasia,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxTebakanDigits),
              ],
              onSubmitted: (_) => _kunciRahasia(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.palet.teks,
              ),
              decoration: InputDecoration(
                hintText: context.tr('Angka rahasia', 'Secret number'),
                filled: true,
                fillColor: context.palet.isi,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TombolUtama(label: context.tr('Kunci', 'Lock'), onPressed: _kunciRahasia),
        ],
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _batalDuel,
          child: Text(context.tr('Batal duel', 'Cancel duel')),
        ),
      ),
    ];
  }

  List<Widget> _areaPilihKomputer() => [
        _label(context.tr('Kamu pikirkan angkanya, aku yang menebak. Aku pakai binary '
            'search: selalu menebak tengah-tengah, jadi tiap jawabanmu '
            'memotong kemungkinan jadi setengah.', 'You think of the number, I guess it. I use binary search: always guessing the middle, so each answer cuts the possibilities in half.')),
        const SizedBox(height: 14),
        _label(context.tr('Pilih level', 'Choose a level')),
        const SizedBox(height: 6),
        _pilihanLevel(),
        const SizedBox(height: 6),
        _label(context.tr('Angka ${_level.bawah}-${_level.atas}, aku punya '
            '${_level.nyawa} percobaan', 'Numbers ${_level.bawah}-${_level.atas}, I get ${_level.nyawa} tries')),
        const SizedBox(height: 6),
        _label(context.tr('Skor komputer: $_komputerMenang menang, $_komputerKalah kalah', 'Computer score: $_komputerMenang won, $_komputerKalah lost')),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: context.tr('Mulai', 'Start'),
            ikon: Icons.play_arrow_rounded,
            onPressed: _mulaiKomputer,
          ),
        ),
      ];

  List<Widget> _areaKomputer(KomputerMenebak k) => [
        _label(context.tr('Level ${k.level.nama} - tebakan ke-${k.percobaan} '
            'dari ${k.level.nyawa}', 'Level ${k.level.namaEn} - guess ${k.percobaan} of ${k.level.nyawa}')),
        const SizedBox(height: 4),
        Text(
          context.tr('Aku tebak ${k.tebakan}', 'My guess: ${k.tebakan}'),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: context.palet.teks,
          ),
        ),
        const SizedBox(height: 14),
        _barRentang(k),
        const SizedBox(height: 6),
        _label(context.tr('Sisa kemungkinan: ${k.sisaKemungkinan} angka '
            '(${k.bawah}-${k.atas})', 'Possibilities left: ${k.sisaKemungkinan} numbers (${k.bawah}-${k.atas})')),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PilihanKaca(
              label: context.tr('Terlalu besar', 'Too high'),
              dipilih: false,
              onTap: () => _jawabKomputer(Jawaban.terlaluBesar),
            ),
            PilihanKaca(
              label: context.tr('Terlalu kecil', 'Too low'),
              dipilih: false,
              onTap: () => _jawabKomputer(Jawaban.terlaluKecil),
            ),
            TombolUtama(
              label: context.tr('Benar!', 'Correct!'),
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
                    color: context.palet.jalur,
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
                    color: context.palet.aksen,
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
                    color: context.palet.permukaan,
                    border: Border.all(color: context.palet.aksen, width: 4),
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
        _label(context.tr('Tantangan #$nomor', 'Challenge #$nomor')),
        const SizedBox(height: 4),
        Text(
          game.menang
              ? context.tr('Kamu menang dalam ${hasil.length} percobaan.', 'You won in ${hasil.length} tries.')
              : context.tr('Belum beruntung. Angkanya ${game.rahasia}.', 'Not this time. The number was ${game.rahasia}.'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.palet.teks,
          ),
        ),
        const SizedBox(height: 6),
        _label(context.tr('Tantangan berikutnya besok.', 'Next challenge tomorrow.')),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: context.tr('Salin hasil', 'Copy result'),
            ikon: Icons.share_outlined,
            onPressed: _salinHasilHarian,
          ),
        ),
      ];
    }

    return [
      _label(context.tr('Tantangan #$nomor - Panas-Dingin, angka '
          '${levelHarian.bawah}-${levelHarian.atas}, '
          '${levelHarian.nyawa} percobaan', 'Challenge #$nomor - Hot-Cold, numbers ${levelHarian.bawah}-${levelHarian.atas}, ${levelHarian.nyawa} tries')),
      const SizedBox(height: 6),
      _label(context.tr('Semua pemain dapat angka yang sama hari ini, '
          'dan cuma bisa dimainkan sekali.', 'Every player gets the same number today, and it can only be played once.')),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: TombolUtama(
          label: hasil.isEmpty ? context.tr('Mulai', 'Start') : context.tr('Lanjutkan', 'Continue'),
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
                label: context.tr(m.nama, m.namaEn),
                dipilih: m == _mode,
                onTap: () => _pilihMode(m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _label(context.tr(_mode.deskripsi, _mode.deskripsiEn)),
        const SizedBox(height: 14),
        _label(context.tr('Pilih level', 'Choose a level')),
        const SizedBox(height: 6),
        _pilihanLevel(),
        const SizedBox(height: 6),
        _label(context.tr('Angka ${_level.bawah}-${_level.atas}, ${_level.nyawa} percobaan', 'Numbers ${_level.bawah}-${_level.atas}, ${_level.nyawa} tries')),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TombolUtama(
            label: context.tr('Mulai', 'Start'),
            ikon: Icons.play_arrow_rounded,
            onPressed: _mulai,
          ),
        ),
      ];

  List<Widget> _areaMain(TebakAngkaGame game) {
    final terakhir = _tebakan.isEmpty ? null : _tebakan.first;
    return [
      _label(_gameDuel
          ? context.tr('Duel - Pemain ${_duel?.pemainAktif} menebak '
              '(${game.level.bawah}-${game.level.atas})', 'Duel - Player ${_duel?.pemainAktif} guessing (${game.level.bawah}-${game.level.atas})')
          : context.tr('${game.mode.nama} - Level ${game.level.nama} '
              '(${game.level.bawah}-${game.level.atas})', '${game.mode.namaEn} - Level ${game.level.namaEn} (${game.level.bawah}-${game.level.atas})')),
      const SizedBox(height: 4),
      Text(
        context.tr('Sisa percobaan: ${game.sisa} dari ${game.level.nyawa}', 'Tries left: ${game.sisa} of ${game.level.nyawa}'),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.palet.teks,
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
              Icon(ikonArah(terakhir.arah), size: 18, color: context.palet.teksRedup),
              const SizedBox(width: 6),
              Expanded(child: _label(teksArah(context, terakhir.arah))),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.palet.teks,
              ),
              decoration: InputDecoration(
                hintText: context.tr('Tebakan kamu', 'Your guess'),
                filled: true,
                fillColor: context.palet.isi,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: context.palet.tepi),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: context.palet.tepi),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: context.palet.aksen, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TombolUtama(label: context.tr('Tebak', 'Guess'), onPressed: _kirim),
        ],
      ),
    ];
  }

  Widget _barGradasi(double nilai) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: context.palet.jalur,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          widthFactor: nilai.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.palet.aksen),
          ),
        ),
      ),
    );
  }

  /// Meteran dari biru (membeku) sampai merah (membara), dengan penanda
  /// yang bergeser ke suhu tebakan terakhir.
  Widget _meteranSuhu(Suhu? suhu) {
    final posisi = suhu == null ? 0.0 : suhu.index / (Suhu.values.length - 1);
    final warna = suhu == null ? context.palet.teksRedup : warnaSuhu(suhu);

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
                child: Text(suhu?.label ?? context.tr('Ayo tebak dulu', 'Make a guess')),
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
                      color: context.palet.permukaan,
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
        _label(context.tr('Petunjuk (${game.petunjukTerbuka.length} terbuka)', 'Clues (${game.petunjukTerbuka.length} unlocked)')),
        const SizedBox(height: 8),
        for (final p in game.petunjukTerbuka)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.palet.isiPilihan,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.palet.tepi),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: context.palet.teksRedup),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.dua(p),
                      style: TextStyle(
                        color: context.palet.teks,
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
      keterangan = context.tr('benar', 'correct');
    } else if (suhu != null) {
      warna = warnaSuhu(suhu);
      keterangan = context.tr(suhu.label, suhu.labelEn).toLowerCase();
    } else {
      warna = context.palet.teks;
      keterangan = context.tr('salah', 'wrong');
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
                context.tr('Menang', 'Won'),
                '$_jumlahMenang',
                Icons.emoji_events_outlined,
                aksen: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _kartuAngka(context.tr('Kalah', 'Lost'), '$_jumlahKalah', Icons.close)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _kartuAngka('Win rate', _winRate, Icons.percent)),
            const SizedBox(width: 16),
            Expanded(
              child: _kartuAngka(
                context.tr('Rekor ${_modeTampil.nama} ${_levelTampil.nama}', 'Best ${_modeTampil.namaEn} ${_levelTampil.namaEn}'),
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
    final warna = aksen ? Colors.white : context.palet.teks;
    final warnaRedup = aksen ? const Color(0xD9FFFFFF) : context.palet.teksRedup;

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
          _judul(context.tr('Percobaan per ronde', 'Tries per round')),
          const SizedBox(height: 4),
          _label(_keteranganJumlah(context.tr('Warna pekat menang, abu-abu kalah', 'Solid = won, gray = lost'))),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: data.isEmpty
                ? Center(child: _label(context.tr('Belum ada ronde selesai.', 'No finished rounds yet.')))
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palet.teks,
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
                                          ? context.palet.aksen
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
    final gayaKepala = TextStyle(color: context.palet.teksRedup, fontSize: 12);
    final gayaIsi = TextStyle(color: context.palet.teks, fontWeight: FontWeight.w500);

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _judul(context.tr('Riwayat ronde', 'Round history')),
          if (_jumlahRonde > _maksTampil) ...[
            const SizedBox(height: 4),
            _label(_keteranganJumlah('')),
          ],
          const SizedBox(height: 12),
          if (_ronde.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _label(context.tr('Selesaikan satu ronde, hasilnya muncul di sini.', 'Finish a round and it will show up here.')),
            )
          else ...[
            Row(
              children: [
                Expanded(child: Text('Mode', style: gayaKepala)),
                Expanded(child: Text('Level', style: gayaKepala)),
                Expanded(child: Text(context.tr('Angka', 'Number'), style: gayaKepala)),
                Expanded(child: Text(context.tr('Percobaan', 'Tries'), style: gayaKepala)),
                Expanded(child: Text(context.tr('Hasil', 'Result'), style: gayaKepala)),
              ],
            ),
            Divider(color: context.palet.jalur),
            for (final r in _ronde.take(_maksTampil))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(context.tr(r.mode.nama, r.mode.namaEn),
                            style: gayaIsi)),
                    Expanded(
                        child: Text(context.tr(r.level.nama, r.level.namaEn),
                            style: gayaIsi)),
                    Expanded(child: Text('${r.rahasia}', style: gayaIsi)),
                    Expanded(child: Text('${r.percobaan}', style: gayaIsi)),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: r.menang ? context.palet.aksen : const Color(0x4D94A3B8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r.menang ? context.tr('Menang', 'Won') : context.tr('Kalah', 'Lost'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: r.menang ? context.palet.diAtasAksen : context.palet.teks,
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
