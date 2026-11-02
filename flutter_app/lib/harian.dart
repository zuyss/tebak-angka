// Tantangan harian: angka dan kata yang sama untuk semua pemain di hari
// yang sama, tanpa server. Semuanya diturunkan dari tanggal.
//
// Kenapa nggak pakai Random(seed)? Urutan angka Random bawaan Dart nggak
// dijamin sama antara app (Dart VM) dan web (JavaScript). Hash di bawah
// cuma memakai operasi yang hasilnya pasti sama di dua-duanya: penjumlahan
// dan perkalian kecil (tetap di bawah 2^53) serta geser/XOR 32-bit.

import 'game.dart';
import 'wordle.dart';

/// Level untuk angka harian: Sedang (1-100, 10 percobaan).
final Level levelHarian = daftarLevel[1];

/// Panjang kata Wordle harian.
const int panjangHarian = 5;

/// Hari pertama tantangan harian (#1).
final DateTime _hariPertama = DateTime.utc(2026, 11, 1);

String _dua(int n) => n.toString().padLeft(2, '0');

/// Tanggal lokal pemain sebagai "YYYY-MM-DD".
String kunciTanggal(DateTime waktu) =>
    '${waktu.year}-${_dua(waktu.month)}-${_dua(waktu.day)}';

/// Nomor tantangan, dihitung dari 1 November 2026 sebagai #1.
int nomorHarian(DateTime waktu) =>
    DateTime.utc(waktu.year, waktu.month, waktu.day)
        .difference(_hariPertama)
        .inDays +
    1;

const int _m32 = 0xFFFFFFFF;

int _campur(int x) {
  x &= _m32;
  for (var i = 0; i < 4; i++) {
    x ^= (x << 13) & _m32;
    x ^= x >> 17;
    x ^= (x << 5) & _m32;
  }
  return x;
}

/// Hash teks yang hasilnya sama di semua platform.
int hashStabil(String teks) {
  var h = 7;
  for (final c in teks.codeUnits) {
    h = (h * 31 + c) % 2147483647;
  }
  return _campur(h);
}

int angkaHarian(DateTime waktu) =>
    levelHarian.bawah +
    hashStabil('angka|${kunciTanggal(waktu)}') %
        (levelHarian.atas - levelHarian.bawah + 1);

String kataHarian(DateTime waktu, Bahasa bahasa, List<String> jawaban) =>
    jawaban[hashStabil('kata|${bahasa.kode}|${kunciTanggal(waktu)}') %
        jawaban.length];

String _kotakSuhu(Suhu suhu) => switch (suhu) {
      Suhu.membeku || Suhu.dingin => '\u{1F7E6}', // biru
      Suhu.sejuk => '\u{1F7E9}', // hijau
      Suhu.hangat => '\u{1F7E8}', // kuning
      Suhu.panas => '\u{1F7E7}', // oranye
      Suhu.membara => '\u{1F7E5}', // merah
    };

/// Teks hasil angka harian untuk dibagikan. [hasil] urut dari tebakan
/// pertama. Angka tebakan sengaja nggak ditulis supaya nggak membocorkan
/// jawaban.
String teksBagikanAngka(int nomor, List<HasilTebakan> hasil, bool menang,
    {bool inggris = false}) {
  final skor = menang ? '${hasil.length}/${levelHarian.nyawa}' : 'X/${levelHarian.nyawa}';
  final kotak = [
    for (final h in hasil) h.benar ? '✅' : _kotakSuhu(h.suhu!),
  ].join();
  final judul = inggris ? 'Daily Number Guess' : 'Tebak Angka Harian';
  return '$judul #$nomor $skor\n$kotak\n'
      'https://zuyss.github.io/tebak-angka/';
}

/// Teks hasil Wordle harian, dengan kotak warna ala Wordle asli.
String teksBagikanWordle(
    int nomor, Bahasa bahasa, List<List<StatusHuruf>> nilai, bool menang,
    {bool inggris = false}) {
  final skor = menang ? '${nilai.length}/$maksTebakan' : 'X/$maksTebakan';
  final baris = [
    for (final n in nilai)
      n
          .map((s) => switch (s) {
                StatusHuruf.benar => '\u{1F7E9}',
                StatusHuruf.ada => '\u{1F7E8}',
                _ => '⬜',
              })
          .join(),
  ];
  final judul = inggris ? 'Daily Wordle' : 'Wordle Harian';
  return '$judul #$nomor (${bahasa.kode.toUpperCase()}) $skor\n'
      '${baris.join('\n')}\n'
      'https://zuyss.github.io/tebak-angka/';
}
