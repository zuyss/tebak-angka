// Pencapaian (badge): lencana yang terbuka saat pemain melakukan sesuatu.
// Disimpan permanen dan sengaja nggak ikut terhapus oleh "Hapus statistik".

import 'package:flutter/material.dart';

import 'simpanan.dart';

class Lencana {
  const Lencana(this.id, this.judul, this.syarat, this.ikon);

  final String id;
  final String judul;
  final String syarat;
  final IconData ikon;
}

const List<Lencana> daftarLencana = [
  Lencana('menang_pertama', 'Langkah pertama',
      'Menang tebak angka untuk pertama kali.', Icons.flag_outlined),
  Lencana('sekali_tebak', 'Cenayang', 'Menang tebak angka dalam 1 percobaan.',
      Icons.auto_awesome_outlined),
  Lencana('panas_sulit', 'Tahan panas', 'Menang Panas-Dingin di level Sulit.',
      Icons.local_fire_department_outlined),
  Lencana('detektif_sulit', 'Sherlock', 'Menang mode Detektif di level Sulit.',
      Icons.search),
  Lencana('komputer_curang', 'Ketahuan bohong',
      'Bikin komputer sadar jawabanmu bertentangan.',
      Icons.sentiment_dissatisfied_outlined),
  Lencana('harian_pertama', 'Rutinitas baru',
      'Selesaikan satu tantangan harian.', Icons.calendar_today_outlined),
  Lencana('harian_3', 'Tiga hari', 'Selesaikan tantangan harian 3 hari berturut-turut.',
      Icons.event_repeat_outlined),
  Lencana('harian_7', 'Seminggu penuh',
      'Selesaikan tantangan harian 7 hari berturut-turut.',
      Icons.workspace_premium_outlined),
  Lencana('wordle_pertama', 'Penyusun kata', 'Menang Wordle untuk pertama kali.',
      Icons.abc),
  Lencana('wordle_cepat', 'Kilat', 'Menang Wordle dalam 2 tebakan atau kurang.',
      Icons.bolt),
  Lencana('wordle_sulit', 'Tanpa ampun', 'Menang Wordle dengan mode sulit.',
      Icons.shield_outlined),
  Lencana('wordle_7', 'Kata panjang', 'Menang Wordle 7 huruf.',
      Icons.straighten_outlined),
  Lencana('wordle_beruntun', 'Tak terhentikan', 'Menang Wordle 5 kali beruntun.',
      Icons.trending_up),
  Lencana('hacker_pertama', 'Akses diterima', 'Bobol PIN untuk pertama kali.',
      Icons.lock_open_outlined),
  Lencana('hacker_elite', 'Elite', 'Bobol PIN tingkat Elite.',
      Icons.terminal),
  Lencana('duel_pertama', 'Lawan tanding', 'Selesaikan satu duel 2 pemain.',
      Icons.people_outline),
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
              'Pencapaian terbuka: ${baru.map((l) => l.judul).join(', ')}',
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
