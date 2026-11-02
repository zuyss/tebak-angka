import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tebak_angka/duel.dart';
import 'package:tebak_angka/game.dart';
import 'package:tebak_angka/halaman_angka.dart';
import 'package:tebak_angka/hacker.dart';
import 'package:tebak_angka/harian.dart';
import 'package:tebak_angka/kaca.dart';
import 'package:tebak_angka/komputer.dart';
import 'package:tebak_angka/main.dart';
import 'package:tebak_angka/pengaturan.dart';
import 'package:tebak_angka/simpanan.dart';
import 'package:tebak_angka/wordle.dart';

const mudah = Level('Mudah', 1, 50, 10);
const kecil = Level('Kecil', 1, 10, 3);
const besar = Level('Besar', 1, 101, 10); // rentang 100, enak buat hitung persen

/// Kamus palsu untuk widget test, supaya nggak perlu baca file aset.
Future<KamusWordle> kamusPalsu(Bahasa bahasa, int panjang) async =>
    KamusWordle(jawaban: ['rumah'], valid: {'makan', 'rumah', 'pohon'});

void main() {
  group('parseTebakan', () {
    test('angka valid diterima', () {
      expect(parseTebakan('25', mudah).angka, 25);
      expect(parseTebakan('  7 ', mudah).angka, 7);
    });

    test('huruf, minus, plus, dan heksadesimal ditolak', () {
      for (final teks in ['', 'abc', '-5', '+5', '0x1A', '1.5', '1 2']) {
        expect(parseTebakan(teks, mudah).error, isNotNull, reason: teks);
      }
    });

    test('angka sangat panjang ditolak tanpa crash', () {
      expect(parseTebakan('9' * 5000, mudah).error, 'Angkanya terlalu panjang.');
    });

    test('di luar rentang ditolak', () {
      expect(parseTebakan('0', mudah).error, isNotNull);
      expect(parseTebakan('51', mudah).error, isNotNull);
      expect(parseTebakan('1', mudah).angka, 1);
      expect(parseTebakan('50', mudah).angka, 50);
    });
  });

  group('hitungSuhu', () {
    test('makin dekat makin panas', () {
      expect(hitungSuhu(1, besar), Suhu.membara);
      expect(hitungSuhu(2, besar), Suhu.membara);
      expect(hitungSuhu(5, besar), Suhu.panas);
      expect(hitungSuhu(12, besar), Suhu.hangat);
      expect(hitungSuhu(25, besar), Suhu.sejuk);
      expect(hitungSuhu(45, besar), Suhu.dingin);
      expect(hitungSuhu(46, besar), Suhu.membeku);
    });

    test('suhu tidak pernah turun saat jarak makin kecil', () {
      for (final level in daftarLevel) {
        var sebelumnya = Suhu.membeku;
        for (var jarak = level.atas - level.bawah; jarak >= 1; jarak--) {
          final s = hitungSuhu(jarak, level);
          expect(s.index, greaterThanOrEqualTo(sebelumnya.index));
          sebelumnya = s;
        }
      }
    });
  });

  group('TebakAngkaGame Panas-Dingin', () {
    test('angka rahasia selalu di dalam rentang', () {
      final random = Random(42);
      for (var i = 0; i < 1000; i++) {
        final r = TebakAngkaGame(kecil, random: random).rahasia;
        expect(r, inInclusiveRange(1, 10));
      }
    });

    test('suhu dan arah dihitung, lalu menang', () {
      final game = TebakAngkaGame.denganRahasia(besar, 50);
      final a = game.tebak(1);
      expect(a.benar, isFalse);
      expect(a.suhu, Suhu.membeku);
      expect(a.arah, Arah.pertama);

      final b = game.tebak(48);
      expect(b.suhu, Suhu.membara);
      expect(b.arah, Arah.mendekat);

      final c = game.tebak(80);
      expect(c.arah, Arah.menjauh);

      expect(game.tebak(50).benar, isTrue);
      expect(game.selesai, isTrue);
      expect(game.menang, isTrue);
      expect(game.percobaan, 4);
    });

    test('kalah kalau percobaan habis', () {
      final game = TebakAngkaGame.denganRahasia(kecil, 6);
      game.tebak(1);
      game.tebak(2);
      expect(game.selesai, isFalse);
      game.tebak(3);
      expect(game.selesai, isTrue);
      expect(game.menang, isFalse);
      expect(game.sisa, 0);
    });

    test('menebak setelah ronde selesai melempar error', () {
      final game = TebakAngkaGame.denganRahasia(kecil, 6)..tebak(6);
      expect(() => game.tebak(1), throwsStateError);
    });

    test('mode Panas-Dingin tidak membuka petunjuk', () {
      final game = TebakAngkaGame.denganRahasia(mudah, 20);
      expect(game.petunjukTerbuka, isEmpty);
      expect(game.tebak(10).petunjukBaru, isNull);
    });
  });

  group('TebakAngkaGame Detektif', () {
    test('satu petunjuk di awal, tambah satu tiap tebakan salah', () {
      final game = TebakAngkaGame.denganRahasia(mudah, 21,
          mode: Mode.detektif, random: Random(1));
      expect(game.petunjukTerbuka.length, 1);

      final hasil = game.tebak(10);
      expect(hasil.suhu, isNull);
      expect(hasil.petunjukBaru, isNotNull);
      expect(game.petunjukTerbuka.length, 2);
    });

    test('setelah semua petunjuk terbuka, nggak ada petunjuk baru', () {
      final game = TebakAngkaGame.denganRahasia(mudah, 21,
          mode: Mode.detektif, random: Random(3));
      // 9 petunjuk total: 1 di awal + 8 dari tebakan salah.
      for (var tebakan = 1; tebakan <= 8; tebakan++) {
        expect(game.tebak(tebakan).petunjukBaru, isNotNull);
      }
      expect(game.petunjukTerbuka.length, 9);
      expect(game.tebak(9).petunjukBaru, isNull);
    });

    test('petunjuk selalu benar tentang angka rahasia', () {
      final random = Random(7);
      for (final level in daftarLevel) {
        for (var i = 0; i < 300; i++) {
          final r = level.bawah + random.nextInt(level.atas - level.bawah + 1);
          final semua = buatPetunjuk(r, level, random);
          expect(semua, contains(r.isEven ? 'Angkanya genap.' : 'Angkanya ganjil.'));
          expect(semua, contains('Digit terakhirnya ${r % 10}.'));

          final jendela = semua.firstWhere((p) => p.contains('di antara'));
          final angka = RegExp(r'\d+')
              .allMatches(jendela)
              .map((m) => int.parse(m.group(0)!))
              .toList();
          expect(r, inInclusiveRange(angka[0], angka[1]), reason: jendela);
          expect(angka[0], greaterThanOrEqualTo(level.bawah));
          expect(angka[1], lessThanOrEqualTo(level.atas));
        }
      }
    });
  });

  group('nilaiTebakan (Wordle)', () {
    const B = StatusHuruf.benar;
    const A = StatusHuruf.ada;
    const S = StatusHuruf.salah;

    test('semua benar', () {
      expect(nilaiTebakan('rumah', 'rumah'), [B, B, B, B, B]);
    });

    test('huruf ada di posisi lain', () {
      expect(nilaiTebakan('harum', 'rumah'), [A, A, A, A, A]);
    });

    test('huruf dobel di tebakan cuma dihitung sebanyak di jawaban', () {
      // Jawaban punya satu "m": cuma "m" pertama di tebakan yang kuning.
      expect(nilaiTebakan('makam', 'rumah'), [A, S, S, B, S]);
    });

    test('huruf yang sudah hijau tidak dihitung lagi sebagai kuning', () {
      // Satu "a" di jawaban sudah dipakai jadi hijau, "a" kedua abu-abu.
      expect(nilaiTebakan('aaxyz', 'abcde'), [B, S, S, S, S]);
      // Dua "a" di jawaban: satu hijau di ujung, satu lagi jadi kuning.
      expect(nilaiTebakan('xaaya', 'abcda'), [S, A, S, S, B]);
    });
  });

  group('WordleGame', () {
    final kamus = KamusWordle(
      jawaban: ['rumah'],
      valid: {'makan', 'harum', 'kucing'},
    );

    test('menolak panjang salah dan kata di luar kamus', () {
      final game = WordleGame(jawaban: 'rumah', kamus: kamus);
      expect(game.tebak('kucing'), 'Kata harus 5 huruf.');
      expect(game.tebak('xxxxx'), 'Kata tidak ada di kamus.');
      expect(game.tebakan, isEmpty);
    });

    test('menang saat kata benar', () {
      final game = WordleGame(jawaban: 'rumah', kamus: kamus);
      expect(game.tebak('MAKAN'), isNull); // huruf besar tetap diterima
      expect(game.tebak('rumah'), isNull);
      expect(game.selesai, isTrue);
      expect(game.menang, isTrue);
    });

    test('kalah setelah enam tebakan salah', () {
      final game = WordleGame(jawaban: 'rumah', kamus: kamus);
      for (var i = 0; i < maksTebakan; i++) {
        expect(game.tebak('makan'), isNull);
      }
      expect(game.selesai, isTrue);
      expect(game.menang, isFalse);
      expect(() => game.tebak('rumah'), throwsStateError);
    });

    test('status keyboard memakai status terkuat', () {
      final game = WordleGame(jawaban: 'rumah', kamus: kamus);
      game.tebak('harum'); // semua kuning
      game.tebak('rumah'); // semua hijau
      expect(game.statusKeyboard['r'], StatusHuruf.benar);
      expect(game.statusKeyboard['h'], StatusHuruf.benar);
    });
  });

  group('file daftar kata', () {
    for (final bahasa in Bahasa.values) {
      for (final panjang in panjangTersedia) {
        test('${bahasa.kode} $panjang huruf', () {
          List<String> baca(String jenis) => KamusWordle.parse(
              File('assets/kata/${bahasa.kode}_${panjang}_$jenis.txt')
                  .readAsStringSync());

          final jawaban = baca('jawaban');
          final valid = baca('valid').toSet();
          final pola = RegExp('^[a-z]{$panjang}\$');

          expect(jawaban.length, greaterThan(500));
          for (final k in jawaban) {
            expect(pola.hasMatch(k), isTrue, reason: k);
            expect(valid.contains(k), isTrue, reason: k);
          }
        });
      }
    }
  });

  group('Wordle mode sulit', () {
    final kamus = KamusWordle(
      jawaban: ['rumah'],
      valid: {'makan', 'pohon', 'rumah', 'harum'},
    );

    test('huruf hijau wajib di posisinya, huruf kuning wajib dipakai', () {
      // makan vs rumah: M kuning, A ke-4 hijau.
      final sebelum = [('makan', nilaiTebakan('makan', 'rumah'))];
      expect(cekModeSulit('pohon', sebelum), 'Mode sulit: huruf ke-4 harus A.');
      expect(cekModeSulit('harum', sebelum), 'Mode sulit: huruf ke-4 harus A.');
      expect(cekModeSulit('rumah', sebelum), isNull);
      expect(cekModeSulit('pohan', sebelum),
          'Mode sulit: tebakan harus memuat M.');
    });

    test('WordleGame menolak tebakan yang melanggar', () {
      final game = WordleGame(jawaban: 'rumah', kamus: kamus, modeSulit: true);
      expect(game.tebak('makan'), isNull);
      expect(game.tebak('pohon'), 'Mode sulit: huruf ke-4 harus A.');
      expect(game.tebakan.length, 1);
      expect(game.tebak('rumah'), isNull);
      expect(game.menang, isTrue);

      final biasa = WordleGame(jawaban: 'rumah', kamus: kamus);
      biasa.tebak('makan');
      expect(biasa.tebak('pohon'), isNull);
    });
  });

  group('duel', () {
    test('giliran berurutan dan pemenang = percobaan paling sedikit', () {
      final duel = Duel(nyawa: 10);
      expect(duel.tahap, TahapDuel.rahasia1);
      expect(duel.pemainAktif, 1);
      duel.rahasiaSiap();
      expect(duel.tahap, TahapDuel.tebak2);
      expect(duel.pemainAktif, 2);
      duel.selesaiMenebak(menang: true, percobaan: 5);
      expect(duel.hasil, isNull);
      duel.rahasiaSiap();
      expect(duel.pemainAktif, 1);
      duel.selesaiMenebak(menang: true, percobaan: 3);
      expect(duel.tahap, TahapDuel.selesai);
      expect(duel.hasil, HasilDuel.pemain1);
      expect(duel.teksSkor(duel.skor2), '5 percobaan');
    });

    test('gagal menebak dihitung nyawa + 1, dan bisa seri', () {
      final duel = Duel(nyawa: 7)
        ..rahasiaSiap()
        ..selesaiMenebak(menang: false, percobaan: 7)
        ..rahasiaSiap()
        ..selesaiMenebak(menang: false, percobaan: 7);
      expect(duel.skor1, 8);
      expect(duel.skor2, 8);
      expect(duel.hasil, HasilDuel.seri);
      expect(duel.teksSkor(duel.skor1), 'gagal');
    });

    test('urutan yang salah ditolak', () {
      final duel = Duel(nyawa: 10);
      expect(() => duel.selesaiMenebak(menang: true, percobaan: 1),
          throwsStateError);
      duel.rahasiaSiap();
      expect(duel.rahasiaSiap, throwsStateError);
    });
  });

  group('pengaturan', () {
    test('tersimpan dan terbaca lagi', () {
      final simpanan = SimpananMemori();
      final p = Pengaturan(simpanan: simpanan)
        ..animasiLatar = false
        ..getar = false;
      expect(p.animasiLatar, isFalse);
      final lagi = Pengaturan(simpanan: simpanan);
      expect(lagi.animasiLatar, isFalse);
      expect(lagi.getar, isFalse);
      expect(Pengaturan(simpanan: SimpananMemori()).animasiLatar, isTrue);
    });

    test('hapus statistik nggak menghapus progres harian', () {
      final simpanan = SimpananMemori()
        ..tulis('tebak_angka.v1', {'menang': 3})
        ..tulis('hacker.v1', {'main': 1})
        ..tulis('harian_angka.v1', {'tanggal': '2026-11-02'});
      Pengaturan(simpanan: simpanan).hapusStatistik();
      expect(simpanan.baca('tebak_angka.v1'), isNull);
      expect(simpanan.baca('hacker.v1'), isNull);
      expect(simpanan.baca('harian_angka.v1'), isNotNull);
    });
  });

  group('komputer yang menebak', () {
    /// Main dengan pemain yang selalu jujur. Kembalikan jumlah percobaan
    /// kalau komputer menang, atau null kalau nggak.
    int? mainJujur(Level level, int rahasia) {
      final k = KomputerMenebak(level);
      while (!k.selesai) {
        k.jawab(k.tebakan == rahasia
            ? Jawaban.benar
            : k.tebakan > rahasia
                ? Jawaban.terlaluBesar
                : Jawaban.terlaluKecil);
      }
      return k.status == StatusKomputer.menang ? k.percobaan : null;
    }

    test('selalu menang dalam jatah kalau pemain jujur, di semua angka', () {
      for (final level in daftarLevel) {
        var terbanyak = 0;
        for (var r = level.bawah; r <= level.atas; r++) {
          final n = mainJujur(level, r);
          expect(n, isNotNull, reason: '${level.nama} angka $r');
          if (n! > terbanyak) terbanyak = n;
        }
        expect(terbanyak, lessThanOrEqualTo(level.nyawa));
      }
    });

    test('jawaban bertentangan ketahuan', () {
      final k = KomputerMenebak(kecil); // 1-10
      expect(k.tebakan, 5);
      k.jawab(Jawaban.terlaluBesar); // berarti < 5
      expect((k.bawah, k.atas), (1, 4));
      k.jawab(Jawaban.terlaluKecil); // tebakan 2 -> berarti > 2
      k.jawab(Jawaban.terlaluKecil); // tebakan 3 -> sisa cuma 4
      expect(k.status, StatusKomputer.kalah); // jatah kecil habis (3)

      final k2 = KomputerMenebak(mudah); // 1-50, tebakan 25
      k2.jawab(Jawaban.terlaluBesar); // < 25
      k2.jawab(Jawaban.terlaluKecil); // tebakan 12 -> > 12
      expect((k2.bawah, k2.atas), (13, 24));
      // Bohong terus "terlalu kecil" sampai rentang habis.
      while (!k2.selesai) {
        k2.jawab(Jawaban.terlaluKecil);
      }
      expect(k2.status, StatusKomputer.bertentangan);
      expect(k2.sisaKemungkinan, 0);
      expect(() => k2.jawab(Jawaban.benar), throwsStateError);
    });
  });

  group('Mode Hacker', () {
    test('nilai PIN termasuk digit kembar', () {
      expect(nilaiPin('1234', '1234'), const HasilPin(4, 0));
      expect(nilaiPin('1243', '1234'), const HasilPin(2, 2));
      expect(nilaiPin('1724', '4721'), const HasilPin(2, 2));
      expect(nilaiPin('5678', '1234'), const HasilPin(0, 0));
      // Tiap digit PIN cuma bisa dipakai sekali.
      expect(nilaiPin('1111', '1222'), const HasilPin(1, 0));
      expect(nilaiPin('1122', '1222'), const HasilPin(3, 0));
      expect(nilaiPin('2211', '1122'), const HasilPin(0, 4));
      expect(nilaiPin('0090', '9000'), const HasilPin(2, 2));
    });

    test('tepat + salah tempat nggak pernah melebihi panjang PIN', () {
      final r = Random(11);
      for (var i = 0; i < 2000; i++) {
        String acak() => List.generate(4, (_) => r.nextInt(10)).join();
        final h = nilaiPin(acak(), acak());
        expect(h.tepat + h.salahTempat, lessThanOrEqualTo(4));
      }
    });

    test('menolak input salah, menang, dan kalah', () {
      final standar = daftarTingkatHacker[1];
      final g = HackerGame.denganPin(standar, '4721');
      expect(g.tebak('12'), 'PIN harus 4 digit angka.');
      expect(g.tebak('12a4'), 'PIN harus 4 digit angka.');
      expect(g.riwayat, isEmpty);
      expect(g.tebak('1724'), isNull);
      expect(g.riwayat.single.$2, const HasilPin(2, 2));
      expect(g.tebak('4721'), isNull);
      expect(g.selesai, isTrue);
      expect(g.menang, isTrue);
      expect(() => g.tebak('0000'), throwsStateError);

      final kalah = HackerGame.denganPin(standar, '4721');
      for (var i = 0; i < standar.nyawa; i++) {
        kalah.tebak('0000');
      }
      expect(kalah.selesai, isTrue);
      expect(kalah.menang, isFalse);
    });

    test('PIN acak panjangnya sesuai tingkat', () {
      for (final t in daftarTingkatHacker) {
        final g = HackerGame(t, random: Random(5));
        expect(RegExp('^[0-9]{${t.panjang}}\$').hasMatch(g.pin), isTrue);
      }
    });
  });

  group('tantangan harian', () {
    // Angka-angka ini dihitung dengan implementasi rujukan di Python.
    // Kalau berubah, berarti angka/kata harian ikut berubah untuk semua
    // pemain, jadi test ini sengaja dibuat ketat.
    test('hash stabil cocok dengan rujukan', () {
      expect(hashStabil('abc'), 515672207);
      expect(hashStabil(''), 3069989445);
    });

    test('angka harian cocok dengan rujukan dan tetap di rentang', () {
      expect(angkaHarian(DateTime(2026, 11, 2)), 45);
      expect(angkaHarian(DateTime(2026, 11, 3)), 60);
      expect(angkaHarian(DateTime(2026, 12, 31)), 14);
      // Jam berapa pun di hari yang sama, angkanya sama.
      expect(angkaHarian(DateTime(2026, 11, 2, 23, 59)), 45);
      for (var i = 0; i < 400; i++) {
        final a = angkaHarian(DateTime(2026, 11, 1).add(Duration(days: i)));
        expect(a, inInclusiveRange(levelHarian.bawah, levelHarian.atas));
      }
    });

    test('kata harian cocok dengan rujukan', () {
      final daftar = [for (var i = 0; i < 1500; i++) 'k$i'];
      expect(kataHarian(DateTime(2026, 11, 2), Bahasa.id, daftar), 'k1302');
      expect(kataHarian(DateTime(2026, 11, 2), Bahasa.en, daftar), 'k516');
    });

    test('nomor dan kunci tanggal', () {
      expect(nomorHarian(DateTime(2026, 11, 1)), 1);
      expect(nomorHarian(DateTime(2026, 11, 2, 23)), 2);
      expect(nomorHarian(DateTime(2027, 1, 1)), 62);
      expect(kunciTanggal(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('teks bagikan nggak membocorkan angka tebakan', () {
      final game = TebakAngkaGame.denganRahasia(levelHarian, 45);
      final hasil = [game.tebak(10), game.tebak(44), game.tebak(45)];
      final teks = teksBagikanAngka(2, hasil, true);
      expect(teks, startsWith('Tebak Angka Harian #2 3/10\n'));
      expect(teks, isNot(contains('44')));
      expect(teks, contains('\u2705'));
    });

    test('teks bagikan wordle', () {
      final teks = teksBagikanWordle(
        2,
        Bahasa.id,
        [nilaiTebakan('makan', 'rumah'), nilaiTebakan('rumah', 'rumah')],
        true,
      );
      expect(teks, startsWith('Wordle Harian #2 (ID) 2/6\n'));
      expect(teks, contains('\u{1F7E9}' * 5));
      expect(teks, isNot(contains('rumah')));
    });
  });

  group('penyimpanan', () {
    test('JSON rusak atau bukan objek dianggap kosong', () {
      expect(uraiJson(null), isNull);
      expect(uraiJson('bukan json'), isNull);
      expect(uraiJson('[1, 2]'), isNull);
      expect(uraiJson('{"a": 1}'), {'a': 1});
    });

    test('angkaAman menolak nilai aneh', () {
      expect(angkaAman(5), 5);
      expect(angkaAman(-3), 0);
      expect(angkaAman('5'), 0);
      expect(angkaAman(null, 7), 7);
    });

    test('Ronde bolak-balik JSON, data rusak dibuang', () {
      final r = Ronde(
        mode: Mode.detektif,
        level: daftarLevel[1],
        rahasia: 42,
        percobaan: 3,
        menang: true,
      );
      final balik = Ronde.dariJson(r.keJson())!;
      expect(balik.mode, Mode.detektif);
      expect(balik.level, daftarLevel[1]);
      expect(balik.rahasia, 42);
      expect(balik.percobaan, 3);
      expect(balik.menang, isTrue);

      expect(Ronde.dariJson('teks'), isNull);
      expect(Ronde.dariJson({...r.keJson(), 'mode': 'hilang'}), isNull);
      expect(Ronde.dariJson({...r.keJson(), 'percobaan': 0}), isNull);
    });

    test('SimpananPrefs membaca dan menulis lewat SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({'rusak': '{oops'});
      final s = SimpananPrefs(await SharedPreferences.getInstance());
      expect(s.baca('rusak'), isNull);
      expect(s.baca('belum-ada'), isNull);
      s.tulis('k', {'a': 1});
      expect(s.baca('k'), {'a': 1});
    });
  });

  Future<void> aturLayar(WidgetTester tester, Size ukuran,
      {Simpanan? simpanan, DateTime Function() jam = DateTime.now}) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TebakAngkaApp(
        pemuatKamus: kamusPalsu,
        latarBergerak: false,
        simpanan: simpanan,
        jam: jam,
      ),
    );
  }

  /// Buang app lalu buka lagi dengan penyimpanan yang sama, seperti
  /// menutup dan membuka ulang app.
  Future<void> bukaUlang(WidgetTester tester, Simpanan simpanan,
      {DateTime Function() jam = DateTime.now}) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      TebakAngkaApp(
        pemuatKamus: kamusPalsu,
        latarBergerak: false,
        simpanan: simpanan,
        jam: jam,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tangkap teks yang disalin ke clipboard.
  String? Function() pantauClipboard(WidgetTester tester) {
    String? disalin;
    final pesan = tester.binding.defaultBinaryMessenger;
    pesan.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        disalin = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
        () => pesan.setMockMethodCallHandler(SystemChannels.platform, null));
    return () => disalin;
  }

  DateTime tanggal2Nov() => DateTime(2026, 11, 2, 20, 0);

  Future<void> ketuk(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final (nama, ukuran) in [
    ('laptop', const Size(1400, 1000)),
    ('HP', const Size(400, 900)),
  ]) {
    testWidgets('tebak angka di layar $nama', (tester) async {
      await aturLayar(tester, ukuran);
      expect(find.text('Pilih level'), findsOneWidget);
      expect(find.text('Belum ada ronde selesai.'), findsOneWidget);

      await ketuk(tester, find.text('Mulai'));
      expect(find.text('Sisa percobaan: 10 dari 10'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '25');
      await ketuk(tester, find.text('Tebak'));
      expect(find.text('Tebakan ronde ini'), findsOneWidget);
    });

    testWidgets('kolom input tetap fokus setelah tebakan kedua di layar $nama',
        (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Mulai'));

      // Tebakan pertama.
      await tester.enterText(find.byType(TextField), '1');
      await ketuk(tester, find.text('Tebak'));
      if (find.textContaining('Sisa percobaan').evaluate().isEmpty) return;
      final sebelum = tester.state(find.byType(EditableText));

      // Tebakan kedua memunculkan baris "makin dekat/jauh" di atas input.
      await tester.enterText(find.byType(TextField), '2');
      await ketuk(tester, find.text('Tebak'));
      if (find.textContaining('Sisa percobaan').evaluate().isEmpty) return;

      // TextField-nya harus tetap objek yang sama dan tetap fokus.
      expect(tester.state(find.byType(EditableText)), same(sebelum));
      final kolom = tester.widget<EditableText>(find.byType(EditableText));
      expect(kolom.focusNode.hasFocus, isTrue);
    });

    testWidgets('input di luar rentang diblok semua di layar $nama',
        (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Mulai'));
      await tester.enterText(find.byType(TextField), '99');
      await ketuk(tester, find.text('Tebak'));

      expect(find.text('Angka harus di antara 1 dan 50.'), findsOneWidget);
      final kolom = tester.widget<TextField>(find.byType(TextField));
      expect(kolom.controller!.text, '99');
      expect(kolom.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 2));
    });

    testWidgets('mode detektif di layar $nama', (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Detektif'));
      await ketuk(tester, find.text('Mulai'));
      expect(find.text('Petunjuk (1 terbuka)'), findsOneWidget);
    });

    testWidgets('statistik tebak angka tersimpan di layar $nama',
        (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Detektif'));
      await ketuk(tester, find.text('Mulai'));

      // Tebak 1, 2, 3, ... sampai ronde selesai (menang atau jatah habis).
      for (var angka = 1; angka <= 10; angka++) {
        if (find.byType(TextField).evaluate().isEmpty) break;
        await tester.enterText(find.byType(TextField), '$angka');
        await ketuk(tester, find.text('Tebak'));
      }
      expect(find.text('Selesaikan satu ronde, hasilnya muncul di sini.'),
          findsNothing);

      await bukaUlang(tester, simpanan);
      // Riwayat masih ada, dan pilihan mode terakhir (Detektif) diingat.
      expect(find.text('Selesaikan satu ronde, hasilnya muncul di sini.'),
          findsNothing);
      expect(find.text(Mode.detektif.deskripsi), findsOneWidget);
    });

    testWidgets('data tersimpan yang rusak nggak bikin crash di layar $nama',
        (tester) async {
      final simpanan = SimpananMemori()
        ..isiMentah('tebak_angka.v1', '{rusak')
        ..isiMentah('wordle.v1', '{"main": "banyak", "menang": -1}');
      await aturLayar(tester, ukuran, simpanan: simpanan);
      expect(find.text('Pilih level'), findsOneWidget);
      await ketuk(tester, find.text('Wordle'));
      expect(find.text('Main 0   Menang 0   Beruntun 0'), findsOneWidget);
    });

    testWidgets('angka harian sekali sehari dan bisa dilanjutkan di layar $nama',
        (tester) async {
      final simpanan = SimpananMemori();
      final ambilClipboard = pantauClipboard(tester);
      await aturLayar(tester, ukuran, simpanan: simpanan, jam: tanggal2Nov);
      await ketuk(tester, find.text('Tantangan harian'));
      await ketuk(tester, find.text('Mulai'));
      await tester.enterText(find.byType(TextField), '40');
      await ketuk(tester, find.text('Tebak'));

      // Tutup app di tengah jalan, buka lagi: progres lanjut, bukan ulang.
      await bukaUlang(tester, simpanan, jam: tanggal2Nov);
      await ketuk(tester, find.text('Tantangan harian'));
      await ketuk(tester, find.text('Lanjutkan'));
      expect(find.text('Sisa percobaan: 9 dari 10'), findsOneWidget);

      // Angka harian 2 Nov 2026 adalah 45 (lihat test unit).
      await tester.enterText(find.byType(TextField), '45');
      await ketuk(tester, find.text('Tebak'));
      expect(find.text('Kamu menang dalam 2 percobaan.'), findsOneWidget);
      expect(find.text('Mulai'), findsNothing);

      await ketuk(tester, find.text('Salin hasil'));
      expect(ambilClipboard(), startsWith('Tebak Angka Harian #2 2/10'));

      // Besoknya ada tantangan baru.
      await bukaUlang(tester, simpanan,
          jam: () => DateTime(2026, 11, 3, 8));
      await ketuk(tester, find.text('Tantangan harian'));
      expect(find.text('Mulai'), findsOneWidget);
    });

    testWidgets('wordle harian sekali sehari di layar $nama', (tester) async {
      final simpanan = SimpananMemori();
      final ambilClipboard = pantauClipboard(tester);
      await aturLayar(tester, ukuran, simpanan: simpanan, jam: tanggal2Nov);
      await ketuk(tester, find.text('Wordle'));
      await ketuk(tester, find.text('Harian #2'));
      expect(find.text('4 huruf'), findsNothing); // panjang dikunci 5

      Future<void> ketik(String kata) async {
        for (final h in kata.split('')) {
          await ketuk(tester, find.byKey(ValueKey('tombol-$h')));
        }
        await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      }

      await ketik('makan');
      await bukaUlang(tester, simpanan, jam: tanggal2Nov);
      await ketuk(tester, find.text('Wordle'));
      await ketuk(tester, find.text('Harian #2'));
      // Tebakan tadi diputar ulang.
      expect(find.byKey(const ValueKey('sel-0-0')), findsOneWidget);

      await ketik('rumah'); // kamus palsu: jawabannya selalu "rumah"
      expect(find.textContaining('Mantap!'), findsOneWidget);
      expect(find.text('Main 1   Menang 1   Beruntun 1'), findsOneWidget);

      // Enter setelah selesai nggak memulai kata baru di mode harian.
      await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      expect(find.byKey(const ValueKey('sel-1-0')), findsOneWidget);

      await ketuk(tester, find.text('Salin hasil'));
      expect(ambilClipboard(), startsWith('Wordle Harian #2 (ID) 2/6'));
    });

    testWidgets('komputer menebak di layar $nama', (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Komputer menebak'));
      await ketuk(tester, find.text('Mulai'));
      expect(find.text('Aku tebak 25'), findsOneWidget); // Mudah: 1-50

      await ketuk(tester, find.text('Terlalu besar'));
      expect(find.text('Aku tebak 12'), findsOneWidget);
      expect(find.text('Sisa kemungkinan: 24 angka (1-24)'), findsOneWidget);

      await ketuk(tester, find.text('Benar!'));
      expect(find.text('Yes! Aku menebak angkamu dalam 2 percobaan.'),
          findsOneWidget);
      expect(find.text('Skor komputer: 1 menang, 0 kalah'), findsOneWidget);

      await bukaUlang(tester, simpanan);
      await ketuk(tester, find.text('Komputer menebak'));
      expect(find.text('Skor komputer: 1 menang, 0 kalah'), findsOneWidget);
    });

    testWidgets('mode hacker di layar $nama', (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Hacker'));

      final kolom = find.byType(TextField);
      await tester.enterText(kolom, '12');
      await ketuk(tester, find.text('Coba'));
      expect(find.text('PIN harus 4 digit angka.'), findsOneWidget);

      await tester.enterText(kolom, '1234');
      await ketuk(tester, find.text('Coba'));
      expect(find.textContaining('> 1 2 3 4'), findsOneWidget);
      expect(find.text('PIN harus 4 digit angka.'), findsNothing);
      // Kolom input tetap fokus setelah percobaan, siap diketik lagi.
      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.focusNode.hasFocus, isTrue);

      await ketuk(tester, find.text('Pemula (3 digit)'));
      expect(find.textContaining('> 1 2 3 4'), findsNothing);
      await bukaUlang(tester, simpanan);
      await ketuk(tester, find.text('Hacker'));
      // Tingkat terakhir diingat.
      expect(find.textContaining('Rekor Pemula'), findsOneWidget);
    });

    testWidgets('duel tebak angka di layar $nama', (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Duel'));
      await ketuk(tester, find.text('Mulai duel'));
      expect(find.text('Pemain 1, bikin angka rahasia'), findsOneWidget);

      Future<void> isi(String angka, String tombol) async {
        await tester.enterText(find.byType(TextField), angka);
        await ketuk(tester, find.text(tombol));
      }

      await isi('99', 'Kunci'); // di luar 1-50
      expect(find.text('Angka harus di antara 1 dan 50.'), findsOneWidget);
      await isi('7', 'Kunci');
      expect(find.textContaining('Duel - Pemain 2 menebak'), findsOneWidget);
      await isi('7', 'Tebak');
      expect(find.text('Pemain 2, bikin angka rahasia'), findsOneWidget);

      await isi('30', 'Kunci');
      await isi('29', 'Tebak');
      await isi('30', 'Tebak');
      expect(find.text('Pemain 2 menang!'), findsOneWidget);
      expect(find.text('Pemain 1: 2 percobaan   Pemain 2: 1 percobaan'),
          findsOneWidget);
      // Duel nggak masuk statistik solo.
      expect(find.text('Selesaikan satu ronde, hasilnya muncul di sini.'),
          findsOneWidget);
    });

    testWidgets('duel hacker di layar $nama', (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Hacker'));
      await ketuk(tester, find.text('Duel 2 pemain'));

      Future<void> isi(String angka, String tombol) async {
        await tester.enterText(find.byType(TextField), angka);
        await ketuk(tester, find.text(tombol));
      }

      await isi('1234', 'Kunci');
      await isi('1234', 'Coba');
      expect(find.textContaining('Pemain 2 membobol PIN 1234'), findsOneWidget);
      await isi('5678', 'Kunci');
      await isi('5678', 'Coba');
      expect(find.textContaining('Seri!'), findsOneWidget);
      expect(find.textContaining('Dibobol 0 dari 0'), findsOneWidget);
    });

    testWidgets('wordle mode sulit di layar $nama', (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Wordle'));
      await ketuk(tester, find.text('Mode sulit'));

      Future<void> ketik(String kata) async {
        for (final h in kata.split('')) {
          await ketuk(tester, find.byKey(ValueKey('tombol-$h')));
        }
        await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      }

      await ketik('makan');
      await ketik('pohon');
      expect(find.text('Mode sulit: huruf ke-4 harus A.'), findsOneWidget);

      // Nggak bisa dimatikan di tengah permainan.
      await ketuk(tester, find.text('Mode sulit'));
      expect(find.text('Mode sulit cuma bisa diganti sebelum tebakan pertama.'),
          findsOneWidget);

      // Pilihan mode sulit diingat.
      await bukaUlang(tester, simpanan);
      await ketuk(tester, find.text('Wordle'));
      final pilihan =
          tester.widget<PilihanKaca>(find.widgetWithText(PilihanKaca, 'Mode sulit'));
      expect(pilihan.dipilih, isTrue);
    });

    testWidgets('pengaturan dan hapus statistik di layar $nama',
        (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Komputer menebak'));
      await ketuk(tester, find.text('Mulai'));
      await ketuk(tester, find.text('Benar!'));
      expect(find.text('Skor komputer: 1 menang, 0 kalah'), findsOneWidget);

      await ketuk(tester, find.byTooltip('Pengaturan'));
      await ketuk(tester, find.text('Animasi latar'));
      expect(simpanan.baca('pengaturan.v1')?['animasiLatar'], isFalse);

      await ketuk(tester, find.text('Hapus semua statistik'));
      await ketuk(tester, find.text('Hapus'));
      expect(find.text('Statistik dihapus.'), findsOneWidget);
      expect(simpanan.baca('tebak_angka.v1'), isNull);

      await ketuk(tester, find.text('Komputer menebak'));
      expect(find.text('Skor komputer: 0 menang, 0 kalah'), findsOneWidget);
    });

    testWidgets('wordle di layar $nama', (tester) async {
      await aturLayar(tester, ukuran);
      await ketuk(tester, find.text('Wordle'));

      Future<void> ketik(String kata) async {
        for (final h in kata.split('')) {
          await ketuk(tester, find.byKey(ValueKey('tombol-$h')));
        }
        await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      }

      await ketik('qwert');
      expect(find.text('Kata tidak ada di kamus.'), findsOneWidget);
      expect(find.byKey(const ValueKey('getar-1')), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await ketuk(tester, find.byKey(const ValueKey('tombol-hapus')));
      }

      await ketik('makan');
      expect(find.text('Kata tidak ada di kamus.'), findsNothing);
      // Baris berikutnya nggak boleh ikut goyang.
      expect(find.byKey(const ValueKey('getar-1')), findsNothing);

      await ketik('rumah');
      expect(find.textContaining('Mantap!'), findsOneWidget);
      expect(find.text('Main 1   Menang 1   Beruntun 1'), findsOneWidget);

      // Enter setelah selesai langsung mulai kata baru.
      await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      expect(find.textContaining('Mantap!'), findsNothing);
      // Papan kosong lagi: sel yang sudah dinilai hilang.
      expect(find.byKey(const ValueKey('sel-0-0')), findsNothing);
      expect(find.text('Main 1   Menang 1   Beruntun 1'), findsOneWidget);
    });

    testWidgets('statistik wordle tersimpan di layar $nama', (tester) async {
      final simpanan = SimpananMemori();
      await aturLayar(tester, ukuran, simpanan: simpanan);
      await ketuk(tester, find.text('Wordle'));
      await ketuk(tester, find.text('6 huruf'));
      await ketuk(tester, find.text('5 huruf'));
      for (final h in 'rumah'.split('')) {
        await ketuk(tester, find.byKey(ValueKey('tombol-$h')));
      }
      await ketuk(tester, find.byKey(const ValueKey('tombol-enter')));
      expect(find.text('Main 1   Menang 1   Beruntun 1'), findsOneWidget);

      await bukaUlang(tester, simpanan);
      await ketuk(tester, find.text('Wordle'));
      expect(find.text('Main 1   Menang 1   Beruntun 1'), findsOneWidget);
    });
  }
}
