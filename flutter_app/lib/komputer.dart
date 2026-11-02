// Mode "komputer yang menebak": pemain memikirkan angka, komputer menebak
// pakai binary search. Logikanya sama dengan komputer_menebak() di versi
// Python (tebak_angka.py), tanpa Flutter supaya gampang dites.

import 'game.dart';

enum Jawaban { terlaluBesar, terlaluKecil, benar }

enum StatusKomputer {
  berjalan,
  menang,
  kalah,

  /// Jawaban pemain saling bertentangan: nggak ada angka yang cocok.
  bertentangan,
}

class KomputerMenebak {
  KomputerMenebak(this.level)
      : bawah = level.bawah,
        atas = level.atas,
        tebakan = (level.bawah + level.atas) ~/ 2;

  final Level level;

  /// Rentang yang masih mungkin. Menyempit setengahnya tiap jawaban.
  int bawah;
  int atas;

  /// Tebakan komputer saat ini.
  int tebakan;

  /// Tebakan ke berapa yang sedang ditanyakan (mulai 1).
  int percobaan = 1;

  StatusKomputer status = StatusKomputer.berjalan;

  bool get selesai => status != StatusKomputer.berjalan;

  /// Banyaknya angka yang masih mungkin.
  int get sisaKemungkinan => atas >= bawah ? atas - bawah + 1 : 0;

  void jawab(Jawaban jawaban) {
    if (selesai) {
      throw StateError('Permainan sudah selesai, mulai lagi.');
    }
    switch (jawaban) {
      case Jawaban.benar:
        status = StatusKomputer.menang;
        return;
      case Jawaban.terlaluBesar:
        atas = tebakan - 1;
      case Jawaban.terlaluKecil:
        bawah = tebakan + 1;
    }

    // Cek bertentangan dulu, baru jatah habis: sama urutannya dengan
    // versi Python, jadi kebohongan di tebakan terakhir tetap ketahuan.
    if (bawah > atas) {
      status = StatusKomputer.bertentangan;
    } else if (percobaan >= level.nyawa) {
      status = StatusKomputer.kalah;
    } else {
      percobaan++;
      tebakan = (bawah + atas) ~/ 2;
    }
  }
}
