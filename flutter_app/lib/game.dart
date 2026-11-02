// Logika game tebak angka, dipisah dari tampilan (UI).
// File ini tidak meng-import Flutter sama sekali, jadi bisa dites
// dengan cepat dan dipakai ulang di platform mana pun.
//
// Beda dengan versi Python (tebak_angka.py): petunjuk "terlalu besar /
// terlalu kecil" diganti jadi suhu (Panas-Dingin) dan petunjuk sifat
// angka (Detektif). Validasi input tetap sama.

import 'dart:math';

import 'dua.dart';

class Level {
  const Level(this.nama, this.namaEn, this.bawah, this.atas, this.nyawa);

  /// Nama Indonesia. Juga dipakai sebagai kunci penyimpanan, jadi jangan
  /// diubah.
  final String nama;
  final String namaEn;
  final int bawah;
  final int atas;
  final int nyawa;
}

// Tanpa arah besar/kecil, pemain butuh percobaan lebih banyak.
const List<Level> daftarLevel = [
  Level('Mudah', 'Easy', 1, 50, 10),
  Level('Sedang', 'Medium', 1, 100, 10),
  Level('Sulit', 'Hard', 1, 500, 12),
];

enum Mode {
  panasDingin(
    'Panas-Dingin',
    'Makin dekat tebakanmu, makin panas suhunya.',
    'Hot-Cold',
    'The closer your guess, the hotter it gets.',
  ),
  detektif(
    'Detektif',
    'Tiap tebakan salah membuka satu petunjuk tentang angkanya.',
    'Detective',
    'Every wrong guess unlocks one clue about the number.',
  );

  const Mode(this.nama, this.deskripsi, this.namaEn, this.deskripsiEn);

  final String nama;
  final String deskripsi;
  final String namaEn;
  final String deskripsiEn;
}

/// Suhu tebakan, dari yang paling jauh sampai paling dekat.
enum Suhu {
  membeku('Membeku', 'Freezing'),
  dingin('Dingin', 'Cold'),
  sejuk('Sejuk', 'Cool'),
  hangat('Hangat', 'Warm'),
  panas('Panas', 'Hot'),
  membara('Membara', 'Burning');

  const Suhu(this.label, this.labelEn);

  final String label;
  final String labelEn;
}

/// Dibanding tebakan sebelumnya, tebakan ini makin dekat atau makin jauh.
enum Arah { pertama, mendekat, menjauh, sama }

/// Suhu dihitung dari jarak relatif terhadap lebar rentang level, jadi
/// "panas" di level 1-50 dan 1-500 terasa sama sulitnya.
Suhu hitungSuhu(int jarak, Level level) {
  final rentang = level.atas - level.bawah;
  int batas(double persen) => max(1, (rentang * persen).round());

  if (jarak <= batas(0.02)) return Suhu.membara;
  if (jarak <= batas(0.05)) return Suhu.panas;
  if (jarak <= batas(0.12)) return Suhu.hangat;
  if (jarak <= batas(0.25)) return Suhu.sejuk;
  if (jarak <= batas(0.45)) return Suhu.dingin;
  return Suhu.membeku;
}

bool _prima(int n) {
  if (n < 2) return false;
  for (var i = 2; i * i <= n; i++) {
    if (n % i == 0) return false;
  }
  return true;
}

int _jumlahDigit(int n) =>
    n.toString().split('').fold<int>(0, (total, d) => total + int.parse(d));

/// Petunjuk mode Detektif, urut dari yang samar ke yang spesifik.
/// Urutan di dalam tiap tingkat diacak biar tiap ronde terasa beda.
List<Dua> buatPetunjuk(int rahasia, Level level, Random random) {
  final tengah = (level.bawah + level.atas) ~/ 2;

  final umum = <Dua>[
    rahasia.isEven
        ? const Dua('Angkanya genap.', 'The number is even.')
        : const Dua('Angkanya ganjil.', 'The number is odd.'),
    rahasia > tengah
        ? Dua('Angkanya lebih dari $tengah.', 'The number is above $tengah.')
        : Dua('Angkanya tidak lebih dari $tengah.',
            'The number is not above $tengah.'),
  ]..shuffle(random);

  final sedang = <Dua>[
    for (final d in const [3, 5, 7])
      rahasia % d == 0
          ? Dua('Angkanya kelipatan $d.', 'The number is a multiple of $d.')
          : Dua('Angkanya bukan kelipatan $d.',
              'The number is not a multiple of $d.'),
    _prima(rahasia)
        ? const Dua('Angkanya bilangan prima.', 'The number is prime.')
        : const Dua('Angkanya bukan bilangan prima.',
            'The number is not prime.'),
    Dua('Jumlah digitnya ${_jumlahDigit(rahasia)}.',
        'Its digits add up to ${_jumlahDigit(rahasia)}.'),
  ]..shuffle(random);

  // Jendela selebar ~15% rentang yang pasti memuat angka rahasia,
  // dengan posisi angka di dalam jendela diacak.
  final lebar = max(4, ((level.atas - level.bawah + 1) * 0.15).round());
  final geser = random.nextInt(lebar);
  final awal = max(level.bawah, rahasia - geser);
  final akhir = min(level.atas, awal + lebar - 1);

  final khusus = <Dua>[
    Dua('Digit terakhirnya ${rahasia % 10}.',
        'Its last digit is ${rahasia % 10}.'),
    Dua('Angkanya di antara $awal dan $akhir.',
        'The number is between $awal and $akhir.'),
  ]..shuffle(random);

  return [...umum, ...sedang, ...khusus];
}

/// Batas panjang teks tebakan. Sama dengan MAX_TEBAKAN_DIGITS di versi Python.
const int maxTebakanDigits = 10;

/// Hasil validasi input: salah satu dari [angka] atau [error] terisi.
class HasilParse {
  const HasilParse.ok(int this.angka) : error = null;
  const HasilParse.gagal(Dua this.error) : angka = null;

  final int? angka;
  final Dua? error;
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
    return const HasilParse.gagal(
        Dua('Masukkan angka bulat ya.', 'Please enter a whole number.'));
  }
  if (bersih.length > maxTebakanDigits) {
    return const HasilParse.gagal(
        Dua('Angkanya terlalu panjang.', 'That number is too long.'));
  }

  final angka = int.parse(bersih);
  if (angka < level.bawah || angka > level.atas) {
    return HasilParse.gagal(Dua(
        'Angka harus di antara ${level.bawah} dan ${level.atas}.',
        'The number must be between ${level.bawah} and ${level.atas}.'));
  }
  return HasilParse.ok(angka);
}

class HasilTebakan {
  const HasilTebakan({
    required this.angka,
    required this.benar,
    this.suhu,
    this.arah = Arah.pertama,
    this.petunjukBaru,
  });

  final int angka;
  final bool benar;

  /// Hanya diisi di mode Panas-Dingin dan kalau tebakan salah.
  final Suhu? suhu;
  final Arah arah;

  /// Petunjuk yang baru terbuka karena tebakan ini (mode Detektif).
  final Dua? petunjukBaru;
}

/// Satu ronde permainan.
class TebakAngkaGame {
  /// Ronde baru dengan angka rahasia acak.
  /// [random] bisa diisi saat testing biar hasilnya bisa ditebak.
  factory TebakAngkaGame(
    Level level, {
    Mode mode = Mode.panasDingin,
    Random? random,
  }) {
    final r = random ?? Random();
    final rahasia = level.bawah + r.nextInt(level.atas - level.bawah + 1);
    return TebakAngkaGame.denganRahasia(level, rahasia, mode: mode, random: r);
  }

  /// Ronde baru dengan angka rahasia yang sudah ditentukan (untuk testing).
  TebakAngkaGame.denganRahasia(
    this.level,
    this.rahasia, {
    this.mode = Mode.panasDingin,
    Random? random,
  }) : _antreanPetunjuk = mode == Mode.detektif
            ? buatPetunjuk(rahasia, level, random ?? Random())
            : <Dua>[] {
    // Detektif langsung dapat satu petunjuk di awal sebagai pegangan.
    if (mode == Mode.detektif) _bukaPetunjuk();
  }

  final Level level;
  final int rahasia;
  final Mode mode;

  final List<Dua> _antreanPetunjuk;
  final List<Dua> petunjukTerbuka = [];
  int? _jarakSebelumnya;

  int percobaan = 0;
  bool selesai = false;
  bool menang = false;

  int get sisa => level.nyawa - percobaan;

  HasilTebakan tebak(int angka) {
    if (selesai) {
      throw StateError('Ronde sudah selesai, mulai ronde baru.');
    }
    percobaan++;

    if (angka == rahasia) {
      selesai = true;
      menang = true;
      return HasilTebakan(angka: angka, benar: true);
    }

    final jarak = (angka - rahasia).abs();
    final sebelumnya = _jarakSebelumnya;
    final Arah arah;
    if (sebelumnya == null) {
      arah = Arah.pertama;
    } else if (jarak < sebelumnya) {
      arah = Arah.mendekat;
    } else if (jarak > sebelumnya) {
      arah = Arah.menjauh;
    } else {
      arah = Arah.sama;
    }
    _jarakSebelumnya = jarak;

    final petunjukBaru = mode == Mode.detektif ? _bukaPetunjuk() : null;

    if (percobaan >= level.nyawa) {
      selesai = true;
    }

    return HasilTebakan(
      angka: angka,
      benar: false,
      suhu: mode == Mode.panasDingin ? hitungSuhu(jarak, level) : null,
      arah: arah,
      petunjukBaru: petunjukBaru,
    );
  }

  Dua? _bukaPetunjuk() {
    if (_antreanPetunjuk.isEmpty) return null;
    final petunjuk = _antreanPetunjuk.removeAt(0);
    petunjukTerbuka.add(petunjuk);
    return petunjuk;
  }
}
