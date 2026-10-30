// Logika Wordle, tanpa Flutter supaya gampang dites.

import 'dart:math';

enum Bahasa {
  id('Indonesia', 'id'),
  en('English', 'en');

  const Bahasa(this.nama, this.kode);

  final String nama;
  final String kode;
}

const List<int> panjangTersedia = [4, 5, 6, 7];
const int maksTebakan = 6;

/// Urutannya penting: makin ke bawah makin "kuat". Warna tombol keyboard
/// pakai status terkuat yang pernah didapat huruf itu.
enum StatusHuruf { kosong, salah, ada, benar }

/// Nilai tiap huruf tebakan terhadap jawaban.
///
/// Dua putaran, seperti Wordle asli:
/// 1. Tandai dulu huruf yang posisinya tepat (benar), sambil menghitung
///    sisa huruf jawaban yang belum terpakai.
/// 2. Baru huruf lain ditandai "ada" selama sisa huruf itu masih ada.
/// Jadi jawaban "rumah" dengan tebakan "makam" cuma memberi satu "m"
/// kuning, bukan dua.
List<StatusHuruf> nilaiTebakan(String tebakan, String jawaban) {
  assert(tebakan.length == jawaban.length);
  final hasil = List<StatusHuruf>.filled(jawaban.length, StatusHuruf.salah);
  final sisa = <String, int>{};

  for (var i = 0; i < jawaban.length; i++) {
    if (tebakan[i] == jawaban[i]) {
      hasil[i] = StatusHuruf.benar;
    } else {
      sisa[jawaban[i]] = (sisa[jawaban[i]] ?? 0) + 1;
    }
  }

  for (var i = 0; i < jawaban.length; i++) {
    if (hasil[i] == StatusHuruf.benar) continue;
    final jumlah = sisa[tebakan[i]] ?? 0;
    if (jumlah > 0) {
      hasil[i] = StatusHuruf.ada;
      sisa[tebakan[i]] = jumlah - 1;
    }
  }
  return hasil;
}

/// Daftar kata untuk satu bahasa dan satu panjang kata.
class KamusWordle {
  KamusWordle({required List<String> jawaban, required Set<String> valid})
      : jawaban = List.unmodifiable(jawaban),
        // Jawaban selalu dianggap tebakan valid.
        valid = Set.unmodifiable({...valid, ...jawaban});

  /// Kata-kata umum yang bisa jadi jawaban.
  final List<String> jawaban;

  /// Semua kata yang boleh dipakai menebak.
  final Set<String> valid;

  /// Baca isi file daftar kata: satu kata per baris.
  static List<String> parse(String isi) => isi
      .split('\n')
      .map((k) => k.trim().toLowerCase())
      .where((k) => k.isNotEmpty)
      .toList();

  String acakJawaban(Random random) => jawaban[random.nextInt(jawaban.length)];
}

class WordleGame {
  WordleGame({required this.jawaban, required this.kamus});

  final String jawaban;
  final KamusWordle kamus;

  final List<(String, List<StatusHuruf>)> tebakan = [];
  bool selesai = false;
  bool menang = false;

  int get panjang => jawaban.length;

  /// Status terkuat tiap huruf yang sudah pernah ditebak.
  Map<String, StatusHuruf> get statusKeyboard {
    final peta = <String, StatusHuruf>{};
    for (final (kata, nilai) in tebakan) {
      for (var i = 0; i < kata.length; i++) {
        final lama = peta[kata[i]] ?? StatusHuruf.kosong;
        if (nilai[i].index > lama.index) peta[kata[i]] = nilai[i];
      }
    }
    return peta;
  }

  /// Kembalikan pesan error kalau tebakan ditolak, atau null kalau diterima.
  String? tebak(String kata) {
    if (selesai) {
      throw StateError('Permainan sudah selesai, mulai kata baru.');
    }
    final k = kata.trim().toLowerCase();
    if (k.length != panjang) return 'Kata harus $panjang huruf.';
    if (!kamus.valid.contains(k)) return 'Kata tidak ada di kamus.';

    tebakan.add((k, nilaiTebakan(k, jawaban)));
    if (k == jawaban) {
      selesai = true;
      menang = true;
    } else if (tebakan.length >= maksTebakan) {
      selesai = true;
    }
    return null;
  }
}
