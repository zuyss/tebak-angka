import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'kaca.dart';

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
}

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
  const HalamanAngka({super.key});

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

  /// Riwayat dan grafik cuma menampilkan ronde terakhir sebanyak ini.
  static const _maksTampil = 10;

  /// Contoh: "10 dari 15 ronde terakhir. Hitam menang, abu-abu kalah"
  String _keteranganJumlah(String tambahan) {
    final bagian = <String>[
      if (_ronde.length > _maksTampil)
        '$_maksTampil dari ${_ronde.length} ronde terakhir.',
      if (tambahan.isNotEmpty) tambahan,
    ];
    return bagian.join(' ');
  }

  // ---------- aksi ----------

  void _mulai() {
    setState(() {
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
      }
    });

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

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _judul('Ronde sekarang'),
          const SizedBox(height: 16),
          if (game != null && !game.selesai)
            ..._areaMain(game)
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
                onTap: () => setState(() => _mode = m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _label(_mode.deskripsi),
        const SizedBox(height: 14),
        _label('Pilih level'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in daftarLevel)
              PilihanKaca(
                label: level.nama,
                dipilih: level == _level,
                onTap: () => setState(() => _level = level),
              ),
          ],
        ),
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
                      boxShadow: [
                        BoxShadow(
                          color: warna.withAlpha(0x80),
                          blurRadius: 12,
                        ),
                      ],
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
            Expanded(child: _kartuAngka('Rekor tercepat', _rekor, Icons.bolt)),
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
          if (_ronde.length > _maksTampil) ...[
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
