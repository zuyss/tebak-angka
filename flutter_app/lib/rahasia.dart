// Rahasia di dalam game. Jawaban-jawabannya sengaja NGGAK ditulis di kode
// ini: yang disimpan cuma hash-nya, dan beberapa petunjuk dienkripsi pakai
// jawaban tahap sebelumnya. Repo ini publik, jadi kalau mau tahu jawabannya
// dari kode, kamu harus brute force, kayak CTF beneran.

import 'dart:convert';
import 'dart:math';

import 'dua.dart';
import 'harian.dart' show hashStabil;

const int _hashPin = 2557662453;
const int _hashKata = 3719808177;
const int _hashUlar = 2132167027;
const int _hashBrankas = 1810367320;
const int _hashArsip = 49961499;

// ---------- rantai 1: akses root ----------

/// Petunjuk tahap berikutnya, di-XOR dengan aliran kunci dari PIN.
const List<int> _pesanTerkunci = [
  209, 128, 210, 251, 188, 252, 250, 179, 190, 244, 159, 217, 46, 115, //
  123, 125, 63, 122, 56, 118, 103, 56, 109, 128, 130, 199, 157, 205, 202,
  158, 74, 2, 88, 75, 180, 136, 211, 147, 220, 158,
];

/// Kalau [pin] benar, kembalikan petunjuk berikutnya dalam bentuk base64
/// (pemain harus men-decode sendiri). Kalau salah, null.
String? bukaPetunjuk(String pin) {
  if (hashStabil('pin|$pin') != _hashPin) return null;
  final byte = [
    for (var i = 0; i < _pesanTerkunci.length; i++)
      _pesanTerkunci[i] ^ (hashStabil('kunci|$pin|$i') & 0xFF),
  ];
  return base64.encode(byte);
}

/// Apakah [kata] adalah kata kunci akses root (diketik di Wordle).
bool kataKunci(String kata) =>
    hashStabil('kata|${kata.toLowerCase()}') == _hashKata;

// ---------- rantai 2: ular ----------

/// Apakah lima tebakan pertama sebuah ronde membangunkan ular.
bool cocokUlar(Iterable<int> limaTebakanPertama) =>
    hashStabil('ular|${limaTebakanPertama.join(',')}') == _hashUlar;

/// Pesan terenkripsi (Caesar) yang muncul setelah memecahkan banyak sandi.
const Dua pesanUlar = Dua(
  'hyne fhxn cv. cbgbat qhn qvtvg frgrynu xbzn. yvzn gronxna cregnzn, '
      'yriry frqnat.',
  'gur fanxr ybirf cv. phg gjb qvtvgf nsgre gur cbvag. svefg svir '
      'thrffrf, zrqvhz yriry.',
);

/// Skor Pemecah Sandi yang memunculkan [pesanUlar].
const int skorPesanUlar = 10;

// ---------- rantai 3: brankas waktu ----------

/// Brankas cuma bisa dibuka di satu menit tertentu setiap hari.
bool brankasTerbuka(DateTime waktu) {
  String dua(int n) => n.toString().padLeft(2, '0');
  return hashStabil('brankas|${dua(waktu.hour)}:${dua(waktu.minute)}') ==
      _hashBrankas;
}

/// Pesan terbalik yang muncul saat ular sudah cukup panjang.
const Dua pesanBrankas = Dua(
  '.aynmalas nahat .tinemes akub amuc saknarb .irah inid ,saleb agit tawel '
      'agit lukup',
  '.gniteerg eht dloh .etunim eno rof snepo tluav eht .nwad erofeb '
      ',neetriht eerht',
);

/// Jumlah makanan yang harus dimakan ular sebelum [pesanBrankas] muncul.
const int makananPesanBrankas = 13;

/// Target stopwatch di dalam brankas, dalam milidetik.
const int targetBrankasMs = 3130;

// ---------- rantai 4: arsip (fragmen dari tiga mode) ----------

/// Fragmen kode arsip. Didapat dengan menang di percobaan terakhir:
/// tebak angka, Wordle, dan Hacker. Urutannya sesuai nomor fragmen.
const Map<String, String> fragmenArsip = {
  'angka': '17',
  'wordle': '08',
  'hacker': '45',
};

/// Nomor fragmen (1-3) untuk ditampilkan.
int nomorFragmen(String id) => fragmenArsip.keys.toList().indexOf(id) + 1;

/// Apakah [teks] adalah kode arsip lengkap.
bool kodeArsip(String teks) => hashStabil('arsip|${teks.trim()}') == _hashArsip;

// ---------- rantai 5: kode lama ----------

/// Melacak urutan tombol klasik atas-atas-bawah-bawah-kiri-kanan-kiri-
/// kanan-B-A. Masukan: 'u', 'd', 'l', 'r', 'b', 'a'.
class PelacakKonami {
  static const urutan = ['u', 'u', 'd', 'd', 'l', 'r', 'l', 'r', 'b', 'a'];

  final List<String> _terakhir = [];

  /// Kembalikan true kalau masukan ini melengkapi urutannya.
  bool masukkan(String tombol) {
    _terakhir.add(tombol);
    if (_terakhir.length > urutan.length) _terakhir.removeAt(0);
    if (_terakhir.length < urutan.length) return false;
    for (var i = 0; i < urutan.length; i++) {
      if (_terakhir[i] != urutan[i]) return false;
    }
    _terakhir.clear();
    return true;
  }
}

// ---------- game rahasia 1: Pemecah Sandi (Caesar cipher) ----------

/// Istilah dunia security. Huruf a-z saja.
const List<String> kataSandi = [
  'firewall', 'password', 'malware', 'phishing', 'exploit', 'payload',
  'token', 'cipher', 'kernel', 'proxy', 'router', 'backdoor', 'trojan',
  'botnet', 'sandbox', 'debug', 'buffer', 'overflow', 'session', 'cookie',
  'packet', 'scanner', 'keylogger', 'rootkit', 'spoofing', 'sniffer',
  'honeypot', 'patch', 'privilege', 'injection', 'brute', 'hashing',
];

/// Geser tiap huruf a-z sejauh [geser] (Caesar cipher). Selain a-z tetap.
String geserCaesar(String teks, int geser) {
  final g = ((geser % 26) + 26) % 26;
  return String.fromCharCodes(teks.toLowerCase().codeUnits.map((c) =>
      c >= 97 && c <= 122 ? 97 + (c - 97 + g) % 26 : c));
}

class SandiGame {
  SandiGame({Random? random, this.nyawaAwal = 3})
      : _random = random ?? Random(),
        nyawa = nyawaAwal {
    _soalBaru();
  }

  final Random _random;
  final int nyawaAwal;

  int skor = 0;
  int nyawa;
  int beruntun = 0;
  String asli = '';
  int geser = 1;
  bool petunjukDipakai = false;

  bool get selesai => nyawa <= 0;
  String get sandi => geserCaesar(asli, geser);

  void _soalBaru() {
    var baru = kataSandi[_random.nextInt(kataSandi.length)];
    // Jangan sama dengan soal sebelumnya.
    while (baru == asli) {
      baru = kataSandi[_random.nextInt(kataSandi.length)];
    }
    asli = baru;
    geser = 1 + _random.nextInt(25);
    petunjukDipakai = false;
  }

  /// Tunjukkan besar pergeseran. Jawaban benar setelah ini cuma bernilai 1.
  int lihatGeser() {
    petunjukDipakai = true;
    return geser;
  }

  /// Kembalikan true kalau benar. Benar: +2 poin (+1 kalau pakai petunjuk),
  /// lalu soal baru. Salah: nyawa berkurang, soal tetap.
  bool jawab(String jawaban) {
    if (selesai) throw StateError('Permainan sudah selesai.');
    if (jawaban.trim().toLowerCase() == asli) {
      skor += petunjukDipakai ? 1 : 2;
      beruntun++;
      _soalBaru();
      return true;
    }
    nyawa--;
    beruntun = 0;
    return false;
  }
}

// ---------- game rahasia 2: Ular ----------

enum ArahUlar {
  atas(0, -1),
  bawah(0, 1),
  kiri(-1, 0),
  kanan(1, 0);

  const ArahUlar(this.dx, this.dy);
  final int dx, dy;

  bool berlawananDengan(ArahUlar lain) => dx == -lain.dx && dy == -lain.dy;
}

typedef Titik = ({int x, int y});

class UlarGame {
  UlarGame({this.lebar = 18, this.tinggi = 14, Random? random})
      : _random = random ?? Random() {
    final tengah = tinggi ~/ 2;
    badan.addAll([
      (x: 4, y: tengah),
      (x: 3, y: tengah),
      (x: 2, y: tengah),
    ]);
    _taruhMakanan();
  }

  final int lebar, tinggi;
  final Random _random;

  /// Indeks 0 = kepala.
  final List<Titik> badan = [];
  ArahUlar arah = ArahUlar.kanan;
  ArahUlar? _arahBerikut;
  Titik makanan = (x: 0, y: 0);
  int dimakan = 0;
  bool selesai = false;

  int get panjang => badan.length;

  /// Jeda antar langkah: makin banyak makan, makin cepat.
  Duration get jeda => Duration(milliseconds: max(70, 170 - dimakan * 5));

  /// Belok ke [baru] di langkah berikutnya. Putar balik diabaikan.
  void belok(ArahUlar baru) {
    if (selesai || baru.berlawananDengan(arah)) return;
    _arahBerikut = baru;
  }

  /// Maju satu kotak. Kembalikan true kalau ular makan di langkah ini.
  bool langkah() {
    if (selesai) return false;
    arah = _arahBerikut ?? arah;
    _arahBerikut = null;
    final kepala = badan.first;
    final baru = (x: kepala.x + arah.dx, y: kepala.y + arah.dy);
    if (baru.x < 0 || baru.y < 0 || baru.x >= lebar || baru.y >= tinggi) {
      selesai = true;
      return false;
    }
    final makan = baru == makanan;
    // Ekor pindah dulu, jadi kepala boleh masuk ke kotak bekas ekor.
    if (!makan) badan.removeLast();
    if (badan.contains(baru)) {
      selesai = true;
      return false;
    }
    badan.insert(0, baru);
    if (makan) {
      dimakan++;
      _taruhMakanan();
    }
    return makan;
  }

  void _taruhMakanan() {
    final isi = badan.toSet();
    final kosong = [
      for (var y = 0; y < tinggi; y++)
        for (var x = 0; x < lebar; x++)
          if (!isi.contains((x: x, y: y))) (x: x, y: y),
    ];
    if (kosong.isEmpty) {
      selesai = true; // papan penuh: tamat
      return;
    }
    makanan = kosong[_random.nextInt(kosong.length)];
  }
}
