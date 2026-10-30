import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';

void main() => runApp(const TebakAngkaApp());

class TebakAngkaApp extends StatelessWidget {
  const TebakAngkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tebak Angka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HalamanUtama(),
    );
  }
}

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  final _input = TextEditingController();
  final _fokus = FocusNode();

  TebakAngkaGame? _game; // null = sedang di layar pilih level
  int _menang = 0;
  int _kalah = 0;
  String? _pesan;
  final List<(int, Hasil)> _riwayat = []; // tebakan terbaru di atas

  @override
  void dispose() {
    _input.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _mulai(Level level) {
    setState(() {
      _game = TebakAngkaGame(level);
      _pesan =
          'Aku sudah pilih angka antara ${level.bawah} dan ${level.atas}.';
      _riwayat.clear();
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
      _riwayat.insert(0, (angka, hasil));

      if (hasil == Hasil.benar) {
        _menang++;
        _pesan = 'Benar! Angkanya ${game.rahasia}. '
            'Kamu menang dalam ${game.percobaan} percobaan.';
      } else if (game.selesai) {
        _kalah++;
        _pesan = 'Percobaan habis. Angka yang benar: ${game.rahasia}.';
      } else {
        _pesan = _label(hasil);
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

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tebak Angka'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Menang $_menang  Kalah $_kalah')),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Biar di layar laptop yang lebar tampilannya nggak melar.
            constraints: const BoxConstraints(maxWidth: 480),
            child: game == null ? _layarPilihLevel() : _layarMain(game),
          ),
        ),
      ),
    );
  }

  Widget _layarPilihLevel() {
    final teks = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Pilih level', style: teks.headlineSmall),
        const SizedBox(height: 16),
        for (final level in daftarLevel)
          Card(
            child: ListTile(
              title: Text(level.nama),
              subtitle: Text(
                  'Angka ${level.bawah}-${level.atas}, ${level.nyawa} percobaan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _mulai(level),
            ),
          ),
      ],
    );
  }

  Widget _layarMain(TebakAngkaGame game) {
    final teks = Theme.of(context).textTheme;
    final level = game.level;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Level ${level.nama} (${level.bawah}-${level.atas})',
            style: teks.titleLarge),
        const SizedBox(height: 8),
        Text('Sisa percobaan: ${game.sisa} dari ${level.nyawa}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: game.sisa / level.nyawa),
        const SizedBox(height: 24),
        if (!game.selesai)
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
                  decoration: const InputDecoration(
                    labelText: 'Tebakan kamu',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _kirim, child: const Text('Tebak')),
            ],
          ),
        const SizedBox(height: 16),
        if (_pesan != null)
          Text(_pesan!, style: teks.titleMedium, textAlign: TextAlign.center),
        if (game.selesai) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _mulai(level),
            child: const Text('Main lagi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _game = null),
            child: const Text('Ganti level'),
          ),
        ],
        if (_riwayat.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Riwayat', style: teks.titleSmall),
          for (final r in _riwayat)
            ListTile(
              dense: true,
              leading: Icon(_ikon(r.$2)),
              title: Text('${r.$1}'),
              subtitle: Text(_label(r.$2)),
            ),
        ],
      ],
    );
  }
}
