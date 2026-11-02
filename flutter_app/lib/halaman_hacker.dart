import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hacker.dart';
import 'kaca.dart';
import 'simpanan.dart';

const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Consolas', 'Courier New', 'Courier'],
);
const _hijauTerminal = Color(0xFF4ADE80);
const _redupTerminal = Color(0x99FFFFFF);

class HalamanHacker extends StatefulWidget {
  const HalamanHacker({super.key, this.simpanan, required this.aktif});

  /// Null = statistik nggak disimpan (hilang saat app ditutup).
  final Simpanan? simpanan;

  /// True kalau halaman ini sedang tampil (buat ambil fokus kolom input).
  final bool aktif;

  @override
  State<HalamanHacker> createState() => _HalamanHackerState();
}

class _HalamanHackerState extends State<HalamanHacker> {
  final _input = TextEditingController();
  final _fokus = FocusNode();

  TingkatHacker _tingkat = daftarTingkatHacker[1];
  late HackerGame _game; // dibuat di initState, setelah tingkat dimuat
  String? _pesan;

  int _main = 0;
  int _menang = 0;
  final Map<String, int> _rekor = {}; // nama tingkat -> percobaan tersedikit

  static const _kunciSimpanan = 'hacker.v1';

  @override
  void initState() {
    super.initState();
    _muat();
    _game = HackerGame(_tingkat);
  }

  @override
  void didUpdateWidget(HalamanHacker lama) {
    super.didUpdateWidget(lama);
    if (widget.aktif && !lama.aktif) _fokus.requestFocus();
  }

  @override
  void dispose() {
    _input.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _muat() {
    final data = widget.simpanan?.baca(_kunciSimpanan);
    if (data == null) return;
    _tingkat = daftarTingkatHacker
            .where((t) => t.nama == data['tingkat'])
            .firstOrNull ??
        _tingkat;
    _main = angkaAman(data['main']);
    _menang = angkaAman(data['menang']);
    if (_menang > _main) _menang = _main;
    final rekor = data['rekor'];
    if (rekor is Map) {
      for (final MapEntry(:key, :value) in rekor.entries) {
        if (key is String && value is int && value >= 1) _rekor[key] = value;
      }
    }
  }

  void _simpan() {
    widget.simpanan?.tulis(_kunciSimpanan, {
      'tingkat': _tingkat.nama,
      'main': _main,
      'menang': _menang,
      'rekor': _rekor,
    });
  }

  void _baru([TingkatHacker? tingkat]) {
    setState(() {
      if (tingkat != null) _tingkat = tingkat;
      _game = HackerGame(_tingkat);
      _pesan = null;
      _input.clear();
    });
    if (tingkat != null) _simpan();
    _fokus.requestFocus();
  }

  void _coba() {
    final game = _game;
    if (game.selesai) {
      _baru();
      return;
    }
    final error = game.tebak(_input.text);
    if (error != null) {
      setState(() => _pesan = error);
      _input.selection =
          TextSelection(baseOffset: 0, extentOffset: _input.text.length);
      _fokus.requestFocus();
      return;
    }
    setState(() {
      _input.clear();
      _pesan = null;
      if (game.selesai) {
        _main++;
        if (game.menang) {
          _menang++;
          final lama = _rekor[_tingkat.nama];
          final n = game.riwayat.length;
          if (lama == null || n < lama) _rekor[_tingkat.nama] = n;
        }
      }
    });
    if (game.selesai) {
      _simpan();
    } else {
      _fokus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kartuPengaturan(),
              const SizedBox(height: 20),
              _terminal(),
              const SizedBox(height: 20),
              _kartuAturan(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kartuPengaturan() {
    const gayaLabel = TextStyle(color: warnaTeksRedup, fontSize: 13);
    final rekor = _rekor[_tingkat.nama];
    return KartuKaca(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tingkat keamanan', style: gayaLabel),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in daftarTingkatHacker)
                PilihanKaca(
                  label: '${t.nama} (${t.panjang} digit)',
                  dipilih: t == _tingkat,
                  onTap: () => _baru(t),
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
                label: 'PIN baru',
                ikon: Icons.refresh,
                onPressed: _baru,
              ),
              Text(
                'Dibobol $_menang dari $_main   '
                'Rekor ${_tingkat.nama}: ${rekor == null ? '-' : '$rekor percobaan'}',
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

  Widget _terminal() {
    final game = _game;
    final p = _tingkat.panjang;

    return KartuKaca(
      gelap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '\$ bobol --pin ${'*' * p}   sisa ${game.sisa}/${_tingkat.nyawa}',
            style: _mono.copyWith(color: _redupTerminal, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final (tebakan, hasil) in game.riwayat)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(
                TextSpan(
                  style: _mono.copyWith(color: Colors.white, fontSize: 15),
                  children: [
                    TextSpan(
                      text: '> ${tebakan.split('').join(' ')}   ',
                    ),
                    TextSpan(
                      text: '${hasil.tepat} tepat',
                      style: const TextStyle(color: _hijauTerminal),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: '${hasil.salahTempat} salah tempat',
                      style: const TextStyle(color: Color(0xFFFBBF24)),
                    ),
                  ],
                ),
              ),
            ),
          if (game.selesai) ...[
            const SizedBox(height: 10),
            Text(
              game.menang
                  ? 'AKSES DITERIMA. PIN ${game.pin} dibobol dalam '
                      '${game.riwayat.length} percobaan.'
                  : 'AKSES DIBLOKIR. PIN-nya ${game.pin}.',
              style: _mono.copyWith(
                color: game.menang ? _hijauTerminal : const Color(0xFFF87171),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            // Key: baris ini tetap widget yang sama saat riwayat bertambah,
            // supaya kolom input nggak kehilangan fokus (lihat halaman_angka).
            key: const ValueKey('baris-input-hacker'),
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _fokus,
                  enabled: !game.selesai,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(p),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _coba(),
                  cursorColor: _hijauTerminal,
                  style: _mono.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 6,
                  ),
                  decoration: InputDecoration(
                    hintText: '0' * p,
                    hintStyle: _mono.copyWith(
                      color: const Color(0x40FFFFFF),
                      fontSize: 20,
                      letterSpacing: 6,
                    ),
                    filled: true,
                    fillColor: const Color(0x14FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _hijauTerminal, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: _hijauTerminal,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _coba,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    child: Text(
                      game.selesai ? 'Lagi' : 'Coba',
                      style: const TextStyle(
                        color: warnaHitam,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_pesan != null) ...[
            const SizedBox(height: 10),
            Text(
              _pesan!,
              style: _mono.copyWith(color: const Color(0xFFF87171)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuAturan() {
    const gaya = TextStyle(color: warnaTeksRedup, fontSize: 13, height: 1.4);
    return const KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara main',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: warnaTeks,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tebak PIN rahasia. Digit boleh kembar. Tiap percobaan dibalas '
            'dua angka: "tepat" = digit benar di posisi yang benar, '
            '"salah tempat" = digit ada di PIN tapi di posisi lain. '
            'Pakai petunjuknya untuk menyempitkan kemungkinan.',
            style: gaya,
          ),
          SizedBox(height: 8),
          Text(
            'Contoh: PIN 4721, tebakan 1724 -> 2 tepat (7 dan 2), '
            '2 salah tempat (1 dan 4).',
            style: gaya,
          ),
        ],
      ),
    );
  }
}
