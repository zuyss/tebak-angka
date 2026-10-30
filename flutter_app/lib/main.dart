import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'kaca.dart';

void main() => runApp(const TebakAngkaApp());

class TebakAngkaApp extends StatelessWidget {
  const TebakAngkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tebak Angka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: warnaAksen),
      home: const Dashboard(),
    );
  }
}

/// Satu ronde yang sudah selesai, untuk statistik, grafik, dan riwayat.
class Ronde {
  const Ronde({
    required this.level,
    required this.rahasia,
    required this.percobaan,
    required this.menang,
    required this.waktu,
  });

  final Level level;
  final int rahasia;
  final int percobaan;
  final bool menang;
  final DateTime waktu;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _input = TextEditingController();
  final _fokus = FocusNode();

  Level _levelDipilih = daftarLevel.first;
  TebakAngkaGame? _game; // null = belum ada ronde yang dimulai
  String? _pesan;
  final List<(int, Hasil)> _tebakan = []; // tebakan di ronde sekarang
  final List<Ronde> _ronde = []; // ronde selesai, terbaru di depan

  @override
  void dispose() {
    _input.dispose();
    _fokus.dispose();
    super.dispose();
  }

  // ---------- statistik ----------

  int get _jumlahMenang => _ronde.where((r) => r.menang).length;
  int get _jumlahKalah => _ronde.length - _jumlahMenang;

  String get _winRate => _ronde.isEmpty
      ? '-'
      : '${(_jumlahMenang * 100 / _ronde.length).round()}%';

  String get _rekor {
    final menang = _ronde.where((r) => r.menang).map((r) => r.percobaan);
    if (menang.isEmpty) return '-';
    return '${menang.reduce((a, b) => a < b ? a : b)} percobaan';
  }

  // ---------- aksi ----------

  void _mulai() {
    setState(() {
      _game = TebakAngkaGame(_levelDipilih);
      _pesan = 'Aku sudah pilih angka antara '
          '${_levelDipilih.bawah} dan ${_levelDipilih.atas}.';
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
      return;
    }

    final angka = parse.angka!;
    final hasil = game.tebak(angka);

    setState(() {
      _input.clear();
      _tebakan.insert(0, (angka, hasil));

      if (hasil == Hasil.benar) {
        _pesan = 'Benar! Angkanya ${game.rahasia}. '
            'Kamu menang dalam ${game.percobaan} percobaan.';
      } else if (game.selesai) {
        _pesan = 'Percobaan habis. Angka yang benar: ${game.rahasia}.';
      } else {
        _pesan = _label(hasil);
      }

      if (game.selesai) {
        _ronde.insert(
          0,
          Ronde(
            level: game.level,
            rahasia: game.rahasia,
            percobaan: game.percobaan,
            menang: game.menang,
            waktu: DateTime.now(),
          ),
        );
      }
    });

    if (!game.selesai) _fokus.requestFocus();
  }

  String _label(Hasil hasil) => switch (hasil) {
        Hasil.benar => 'Benar!',
        Hasil.terlaluKecil => 'Terlalu kecil.',
        Hasil.terlaluBesar => 'Terlalu besar.',
      };

  IconData _ikon(Hasil hasil) => switch (hasil) {
        Hasil.benar => Icons.check_circle,
        Hasil.terlaluKecil => Icons.arrow_upward, // kekecilan, naikin
        Hasil.terlaluBesar => Icons.arrow_downward, // kegedean, turunin
      };

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _jam(DateTime w) =>
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LatarHangat(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, batas) {
              final lebar = batas.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 24),
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
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0x99FFFFFF),
          child: Icon(Icons.casino_outlined, color: warnaTeks),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sapaan(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Tebak Angka Dashboard',
                style: TextStyle(color: Color(0xCCFFFFFF)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _judul(String teks) => Text(
        teks,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: warnaTeks,
        ),
      );

  ButtonStyle get _tombolGelap => FilledButton.styleFrom(
        backgroundColor: warnaGelap,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      );

  Widget _kartuMain() {
    final game = _game;

    return AngkatSaatHover(
      child: KartuKaca(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _judul('Ronde sekarang'),
            const SizedBox(height: 16),
            if (game != null && !game.selesai) ...[
              Text(
                'Level ${game.level.nama} (${game.level.bawah}-${game.level.atas})',
                style: const TextStyle(color: warnaTeksRedup),
              ),
              const SizedBox(height: 4),
              Text(
                'Sisa percobaan: ${game.sisa} dari ${game.level.nyawa}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: warnaTeks,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: game.sisa / game.level.nyawa,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0x33000000),
                color: warnaAksen,
              ),
              const SizedBox(height: 20),
              Row(
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
                      decoration: InputDecoration(
                        hintText: 'Tebakan kamu',
                        filled: true,
                        fillColor: const Color(0x99FFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: _tombolGelap,
                    onPressed: _kirim,
                    child: const Text('Tebak'),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Pilih level',
                style: TextStyle(color: warnaTeksRedup),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final level in daftarLevel)
                    ChoiceChip(
                      label: Text(level.nama),
                      selected: level == _levelDipilih,
                      onSelected: (_) => setState(() => _levelDipilih = level),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Angka ${_levelDipilih.bawah}-${_levelDipilih.atas}, '
                '${_levelDipilih.nyawa} percobaan',
                style: const TextStyle(color: warnaTeksRedup),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: _tombolGelap,
                onPressed: _mulai,
                child: const Text('Mulai'),
              ),
            ],
            if (_pesan != null) ...[
              const SizedBox(height: 16),
              Text(
                _pesan!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: warnaTeks,
                ),
              ),
            ],
            if (_tebakan.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tebakan ronde ini',
                style: TextStyle(color: warnaTeksRedup),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _tebakan)
                    Chip(
                      avatar: Icon(_ikon(t.$2), size: 18),
                      label: Text('${t.$1}'),
                      backgroundColor: const Color(0x99FFFFFF),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
          ],
        ),
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
            Expanded(
              child: _kartuAngka('Kalah', '$_jumlahKalah', Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _kartuAngka('Win rate', _winRate, Icons.percent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _kartuAngka('Rekor tercepat', _rekor, Icons.bolt),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kartuAngka(String judul, String nilai, IconData ikon,
      {bool aksen = false}) {
    final warna = aksen ? Colors.white : warnaTeks;
    final warnaRedup = aksen ? const Color(0xCCFFFFFF) : warnaTeksRedup;

    return AngkatSaatHover(
      child: KartuKaca(
        gradient: aksen
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE62BB58F), Color(0xE61F8A70)],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 18, color: warnaRedup),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(judul, style: TextStyle(color: warnaRedup)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              nilai,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
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
    final data = _ronde.take(10).toList().reversed.toList();
    final tertinggi = data.isEmpty
        ? 1
        : data.map((r) => r.percobaan).reduce((a, b) => a > b ? a : b);

    return AngkatSaatHover(
      child: KartuKaca(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul('Percobaan per ronde'),
            const SizedBox(height: 4),
            const Text(
              'Hijau menang, gelap kalah',
              style: TextStyle(color: warnaTeksRedup, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: data.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada ronde selesai.',
                        style: TextStyle(color: warnaTeksRedup),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final r in data)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
                                  Container(
                                    height: 140 * r.percobaan / tertinggi,
                                    decoration: BoxDecoration(
                                      color:
                                          r.menang ? warnaAksen : warnaGelap,
                                      borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }

  Widget _kartuRiwayat() {
    const gayaKepala = TextStyle(color: warnaTeksRedup, fontSize: 12);
    const gayaIsi = TextStyle(color: warnaTeks);

    return AngkatSaatHover(
      child: KartuKaca(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _judul('Riwayat ronde'),
            const SizedBox(height: 12),
            if (_ronde.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Selesaikan satu ronde, hasilnya muncul di sini.',
                  style: TextStyle(color: warnaTeksRedup),
                ),
              )
            else ...[
              const Row(
                children: [
                  Expanded(child: Text('Level', style: gayaKepala)),
                  Expanded(child: Text('Angka', style: gayaKepala)),
                  Expanded(child: Text('Percobaan', style: gayaKepala)),
                  Expanded(child: Text('Hasil', style: gayaKepala)),
                  Expanded(child: Text('Jam', style: gayaKepala)),
                ],
              ),
              const Divider(color: Color(0x332B2420)),
              for (final r in _ronde.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
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
                              color: r.menang
                                  ? const Color(0x331F8A70)
                                  : const Color(0x331C1714),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              r.menang ? 'Menang' : 'Kalah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: r.menang ? warnaAksen : warnaGelap,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: Text(_jam(r.waktu), style: gayaIsi)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
