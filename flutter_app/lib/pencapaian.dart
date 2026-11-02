// Pencapaian (badge): lencana yang terbuka saat pemain melakukan sesuatu.
// Disimpan permanen dan sengaja nggak ikut terhapus oleh "Hapus statistik".

import 'package:flutter/material.dart';

import 'pengaturan.dart';
import 'simpanan.dart';

class Lencana {
  const Lencana(this.id, this.ikon, this.judul, this.syarat, this.judulEn,
      this.syaratEn);

  final String id;
  final IconData ikon;
  final String judul;
  final String syarat;
  final String judulEn;
  final String syaratEn;
}

const List<Lencana> daftarLencana = [
  Lencana('menang_pertama', Icons.flag_outlined, 'Langkah pertama',
      'Menang tebak angka untuk pertama kali.', 'First step',
      'Win a number guess for the first time.'),
  Lencana('sekali_tebak', Icons.auto_awesome_outlined, 'Cenayang',
      'Menang tebak angka dalam 1 percobaan.', 'Psychic',
      'Win a number guess in 1 try.'),
  Lencana('panas_sulit', Icons.local_fire_department_outlined, 'Tahan panas',
      'Menang Panas-Dingin di level Sulit.', 'Heatproof',
      'Win Hot-Cold on Hard.'),
  Lencana('detektif_sulit', Icons.search, 'Sherlock',
      'Menang mode Detektif di level Sulit.', 'Sherlock',
      'Win Detective mode on Hard.'),
  Lencana('komputer_curang', Icons.sentiment_dissatisfied_outlined,
      'Ketahuan bohong', 'Bikin komputer sadar jawabanmu bertentangan.',
      'Caught lying', 'Make the computer notice your answers contradict.'),
  Lencana('harian_pertama', Icons.calendar_today_outlined, 'Rutinitas baru',
      'Selesaikan satu tantangan harian.', 'New routine',
      'Finish a daily challenge.'),
  Lencana('harian_3', Icons.event_repeat_outlined, 'Tiga hari',
      'Selesaikan tantangan harian 3 hari berturut-turut.', 'Three days',
      'Finish the daily challenge 3 days in a row.'),
  Lencana('harian_7', Icons.workspace_premium_outlined, 'Seminggu penuh',
      'Selesaikan tantangan harian 7 hari berturut-turut.', 'Full week',
      'Finish the daily challenge 7 days in a row.'),
  Lencana('wordle_pertama', Icons.abc, 'Penyusun kata',
      'Menang Wordle untuk pertama kali.', 'Wordsmith',
      'Win Wordle for the first time.'),
  Lencana('wordle_cepat', Icons.bolt, 'Kilat',
      'Menang Wordle dalam 2 tebakan atau kurang.', 'Lightning',
      'Win Wordle in 2 guesses or fewer.'),
  Lencana('wordle_sulit', Icons.shield_outlined, 'Tanpa ampun',
      'Menang Wordle dengan mode sulit.', 'No mercy',
      'Win Wordle in hard mode.'),
  Lencana('wordle_7', Icons.straighten_outlined, 'Kata panjang',
      'Menang Wordle 7 huruf.', 'Long word', 'Win a 7-letter Wordle.'),
  Lencana('wordle_beruntun', Icons.trending_up, 'Tak terhentikan',
      'Menang Wordle 5 kali beruntun.', 'Unstoppable',
      'Win Wordle 5 times in a row.'),
  Lencana('hacker_pertama', Icons.lock_open_outlined, 'Akses diterima',
      'Bobol PIN untuk pertama kali.', 'Access granted',
      'Crack a PIN for the first time.'),
  Lencana('hacker_elite', Icons.terminal, 'Elite', 'Bobol PIN tingkat Elite.',
      'Elite', 'Crack an Elite PIN.'),
  Lencana('duel_pertama', Icons.people_outline, 'Lawan tanding',
      'Selesaikan satu duel 2 pemain.', 'Sparring partner',
      'Finish a 2-player duel.'),
];

class Pencapaian extends ChangeNotifier {
  Pencapaian({this.simpanan}) {
    final data = simpanan?.baca(_kunci);
    if (data == null) return;
    final terbuka = data['terbuka'];
    if (terbuka is List) {
      final idSah = {for (final b in daftarLencana) b.id};
      _terbuka.addAll(terbuka.whereType<String>().where(idSah.contains));
    }
    final terakhir = data['harianTerakhir'];
    if (terakhir is String) _harianTerakhir = terakhir;
    _harianBeruntun = angkaAman(data['harianBeruntun']);
  }

  final Simpanan? simpanan;
  static const _kunci = 'pencapaian.v1';

  final Set<String> _terbuka = {};
  String? _harianTerakhir;
  int _harianBeruntun = 0;

  bool terbuka(String id) => _terbuka.contains(id);
  int get jumlahTerbuka => _terbuka.length;
  int get harianBeruntun => _harianBeruntun;

  /// Buka badge [id]. Kembalikan badge-nya kalau baru terbuka sekarang,
  /// null kalau sudah terbuka sebelumnya (atau id-nya nggak dikenal).
  Lencana? buka(String id) {
    final badge = daftarLencana.where((b) => b.id == id).firstOrNull;
    if (badge == null || !_terbuka.add(id)) return null;
    _simpan();
    notifyListeners();
    return badge;
  }

  /// Catat tantangan harian yang selesai di [tanggal] ("YYYY-MM-DD").
  /// Kembalikan badge yang baru terbuka karenanya.
  List<Lencana> catatHarian(String tanggal) {
    if (tanggal != _harianTerakhir) {
      _harianBeruntun =
          _selisihHari(_harianTerakhir, tanggal) == 1 ? _harianBeruntun + 1 : 1;
      _harianTerakhir = tanggal;
      _simpan();
    }
    return [
      if (buka('harian_pertama') case final b?) b,
      if (_harianBeruntun >= 3)
        if (buka('harian_3') case final b?) b,
      if (_harianBeruntun >= 7)
        if (buka('harian_7') case final b?) b,
    ];
  }

  static int? _selisihHari(String? dari, String ke) {
    DateTime? urai(String? t) {
      final b = t?.split('-');
      if (b == null || b.length != 3) return null;
      final angka = b.map(int.tryParse).toList();
      if (angka.contains(null)) return null;
      return DateTime.utc(angka[0]!, angka[1]!, angka[2]!);
    }

    final a = urai(dari), b = urai(ke);
    if (a == null || b == null) return null;
    return b.difference(a).inDays;
  }

  void _simpan() {
    simpanan?.tulis(_kunci, {
      'terbuka': _terbuka.toList(),
      'harianTerakhir': _harianTerakhir,
      'harianBeruntun': _harianBeruntun,
    });
  }
}

class PencapaianScope extends InheritedNotifier<Pencapaian> {
  const PencapaianScope({
    super.key,
    required Pencapaian pencapaian,
    required super.child,
  }) : super(notifier: pencapaian);

  static Pencapaian? dari(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PencapaianScope>()?.notifier;

  static Pencapaian? baca(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PencapaianScope>()?.notifier;
}

/// Tampilkan notifikasi untuk lencana yang baru terbuka. Beberapa lencana
/// sekaligus digabung jadi satu notifikasi, dan notifikasinya muncul di
/// atas layar supaya nggak menutupi keyboard Wordle atau kolom input.
void umumkanLencana(BuildContext context, Iterable<Lencana?> lencana) {
  final baru = lencana.whereType<Lencana>().toList();
  if (baru.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final tinggiLayar = MediaQuery.maybeSizeOf(context)?.height ?? 600;
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.up,
      // Margin bawah besar = snackbar "naik" ke bagian atas layar.
      margin: EdgeInsets.fromLTRB(16, 0, 16, tinggiLayar - 140),
      content: Row(
        children: [
          Icon(baru.first.ikon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(
                'Pencapaian terbuka: ${baru.map((l) => l.judul).join(', ')}',
                'Achievement unlocked: ${baru.map((l) => l.judulEn).join(', ')}',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Helper untuk halaman: buka beberapa badge sekaligus dan umumkan yang baru.
void bukaLencana(BuildContext context, List<String> id) {
  final p = PencapaianScope.baca(context);
  if (p == null) return;
  umumkanLencana(context, [for (final i in id) p.buka(i)]);
}

/// Helper untuk halaman: catat tantangan harian yang selesai.
void catatHarianSelesai(BuildContext context, String tanggal) {
  final p = PencapaianScope.baca(context);
  if (p == null) return;
  umumkanLencana(context, p.catatHarian(tanggal));
}
