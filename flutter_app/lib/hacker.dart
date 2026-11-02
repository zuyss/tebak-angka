// Mode Hacker: bobol PIN dengan petunjuk ala Mastermind. Tiap tebakan
// memberi tahu berapa digit yang tepat posisinya dan berapa digit yang
// ada di PIN tapi salah tempat. Tanpa Flutter supaya gampang dites.

import 'dart:math';

class TingkatHacker {
  const TingkatHacker(this.nama, this.panjang, this.nyawa);

  final String nama;
  final int panjang;
  final int nyawa;
}

const List<TingkatHacker> daftarTingkatHacker = [
  TingkatHacker('Pemula', 3, 8),
  TingkatHacker('Standar', 4, 10),
  TingkatHacker('Elite', 5, 12),
];

class HasilPin {
  const HasilPin(this.tepat, this.salahTempat);

  /// Digit benar di posisi yang benar.
  final int tepat;

  /// Digit yang ada di PIN tapi di posisi lain.
  final int salahTempat;

  @override
  bool operator ==(Object other) =>
      other is HasilPin &&
      other.tepat == tepat &&
      other.salahTempat == salahTempat;

  @override
  int get hashCode => Object.hash(tepat, salahTempat);

  @override
  String toString() => 'HasilPin($tepat, $salahTempat)';
}

/// Nilai tebakan terhadap PIN. Digit kembar dihitung seperti Mastermind:
/// tiap digit PIN cuma bisa "dipakai" sekali. Contoh: PIN 1222, tebakan
/// 1111 -> 1 tepat, 0 salah tempat (bukan 1 tepat 3 salah tempat).
HasilPin nilaiPin(String tebakan, String pin) {
  assert(tebakan.length == pin.length);
  var tepat = 0;
  final sisaPin = List<int>.filled(10, 0);
  final sisaTebakan = List<int>.filled(10, 0);

  for (var i = 0; i < pin.length; i++) {
    if (tebakan[i] == pin[i]) {
      tepat++;
    } else {
      sisaPin[pin.codeUnitAt(i) - 48]++;
      sisaTebakan[tebakan.codeUnitAt(i) - 48]++;
    }
  }

  var salahTempat = 0;
  for (var d = 0; d < 10; d++) {
    salahTempat += min(sisaPin[d], sisaTebakan[d]);
  }
  return HasilPin(tepat, salahTempat);
}

final RegExp _digit = RegExp(r'^[0-9]+$');

class HackerGame {
  /// PIN acak. [random] bisa diisi saat testing.
  factory HackerGame(TingkatHacker tingkat, {Random? random}) {
    final r = random ?? Random();
    final pin = List.generate(tingkat.panjang, (_) => r.nextInt(10)).join();
    return HackerGame.denganPin(tingkat, pin);
  }

  HackerGame.denganPin(this.tingkat, this.pin)
      : assert(pin.length == tingkat.panjang);

  final TingkatHacker tingkat;
  final String pin;

  final List<(String, HasilPin)> riwayat = [];
  bool selesai = false;
  bool menang = false;

  int get sisa => tingkat.nyawa - riwayat.length;

  /// Kembalikan pesan error kalau tebakan ditolak, atau null kalau diterima.
  String? tebak(String teks) {
    if (selesai) {
      throw StateError('Permainan sudah selesai, mulai lagi.');
    }
    final t = teks.trim();
    if (t.length != tingkat.panjang || !_digit.hasMatch(t)) {
      return 'PIN harus ${tingkat.panjang} digit angka.';
    }
    final hasil = nilaiPin(t, pin);
    riwayat.add((t, hasil));
    if (hasil.tepat == tingkat.panjang) {
      selesai = true;
      menang = true;
    } else if (riwayat.length >= tingkat.nyawa) {
      selesai = true;
    }
    return null;
  }
}
