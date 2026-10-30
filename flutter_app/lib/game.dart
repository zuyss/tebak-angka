// Logika game tebak angka, dipisah dari tampilan (UI).
// File ini tidak meng-import Flutter sama sekali, jadi bisa dites
// dengan cepat dan dipakai ulang di platform mana pun.
//
// Aturannya sama dengan versi Python (tebak_angka.py) di root repo.

import 'dart:math';

class Level {
  const Level(this.nama, this.bawah, this.atas, this.nyawa);

  final String nama;
  final int bawah;
  final int atas;
  final int nyawa;
}

const List<Level> daftarLevel = [
  Level('Mudah', 1, 50, 10),
  Level('Sedang', 1, 100, 7),
  Level('Sulit', 1, 500, 9),
];

/// Batas panjang teks tebakan. Sama dengan MAX_TEBAKAN_DIGITS di versi Python.
const int maxTebakanDigits = 10;

enum Hasil { terlaluKecil, terlaluBesar, benar }

/// Hasil validasi input: salah satu dari [angka] atau [error] terisi.
class HasilParse {
  const HasilParse.ok(int this.angka) : error = null;
  const HasilParse.gagal(String this.error) : angka = null;

  final int? angka;
  final String? error;
}

final RegExp _hanyaDigit = RegExp(r'^[0-9]+$');

/// Ubah teks dari input jadi angka tebakan yang valid untuk [level].
///
/// Pakai regex dulu, bukan langsung int.tryParse(): int.tryParse di Dart
/// juga menerima tanda minus, tanda plus, dan format heksadesimal
/// seperti "0x1A", yang bukan tebakan yang kita mau.
HasilParse parseTebakan(String teks, Level level) {
  final bersih = teks.trim();

  if (!_hanyaDigit.hasMatch(bersih)) {
    return const HasilParse.gagal('Masukkan angka bulat ya.');
  }
  if (bersih.length > maxTebakanDigits) {
    return const HasilParse.gagal('Angkanya terlalu panjang.');
  }

  final angka = int.parse(bersih);
  if (angka < level.bawah || angka > level.atas) {
    return HasilParse.gagal(
        'Angka harus di antara ${level.bawah} dan ${level.atas}.');
  }
  return HasilParse.ok(angka);
}

/// Satu ronde permainan.
class TebakAngkaGame {
  /// Ronde baru dengan angka rahasia acak.
  /// [random] bisa diisi saat testing biar hasilnya bisa ditebak.
  TebakAngkaGame(this.level, {Random? random})
      : rahasia = level.bawah +
            (random ?? Random()).nextInt(level.atas - level.bawah + 1);

  /// Ronde baru dengan angka rahasia yang sudah ditentukan (untuk testing).
  TebakAngkaGame.denganRahasia(this.level, this.rahasia);

  final Level level;
  final int rahasia;

  int percobaan = 0;
  bool selesai = false;
  bool menang = false;

  int get sisa => level.nyawa - percobaan;

  Hasil tebak(int angka) {
    if (selesai) {
      throw StateError('Ronde sudah selesai, mulai ronde baru.');
    }
    percobaan++;

    if (angka == rahasia) {
      selesai = true;
      menang = true;
      return Hasil.benar;
    }
    if (percobaan >= level.nyawa) {
      selesai = true;
    }
    return angka < rahasia ? Hasil.terlaluKecil : Hasil.terlaluBesar;
  }
}
