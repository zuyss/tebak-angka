import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tebak_angka/game.dart';
import 'package:tebak_angka/main.dart';
import 'package:tebak_angka/wordle.dart';

const mudah = Level('Mudah', 1, 50, 10);
const kecil = Level('Kecil', 1, 10, 3);
const besar = Level('Besar', 1, 101, 10); // rentang 100, enak buat hitung persen

/// Kamus palsu untuk widget test, supaya nggak perlu baca file aset.
Future<KamusWordle> kamusPalsu(Bahasa bahasa, int panjang) async =>
    KamusWordle(jawaban: ['rumah'], valid: {'makan', 'rumah'});

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

  Future<void> aturLayar(WidgetTester tester, Size ukuran) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const TebakAngkaApp(pemuatKamus: kamusPalsu, latarBergerak: false),
    );
  }

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
  }
}
