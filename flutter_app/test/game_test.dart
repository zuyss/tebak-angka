import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tebak_angka/game.dart';
import 'package:tebak_angka/main.dart';

const mudah = Level('Mudah', 1, 50, 10);
const kecil = Level('Kecil', 1, 10, 3);

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
      expect(parseTebakan('9' * 5000, mudah).error,
          'Angkanya terlalu panjang.');
    });

    test('di luar rentang ditolak', () {
      expect(parseTebakan('0', mudah).error, isNotNull);
      expect(parseTebakan('51', mudah).error, isNotNull);
      expect(parseTebakan('1', mudah).angka, 1);
      expect(parseTebakan('50', mudah).angka, 50);
    });
  });

  group('TebakAngkaGame', () {
    test('angka rahasia selalu di dalam rentang', () {
      final random = Random(42);
      for (var i = 0; i < 1000; i++) {
        final r = TebakAngkaGame(kecil, random: random).rahasia;
        expect(r, inInclusiveRange(1, 10));
      }
    });

    test('petunjuk kecil/besar dan menang', () {
      final game = TebakAngkaGame.denganRahasia(kecil, 6);
      expect(game.tebak(3), Hasil.terlaluKecil);
      expect(game.tebak(9), Hasil.terlaluBesar);
      expect(game.tebak(6), Hasil.benar);
      expect(game.selesai, isTrue);
      expect(game.menang, isTrue);
      expect(game.percobaan, 3);
    });

    test('kalah kalau percobaan habis', () {
      final game = TebakAngkaGame.denganRahasia(kecil, 6);
      game.tebak(1);
      game.tebak(2);
      expect(game.selesai, isFalse);
      expect(game.sisa, 1);
      game.tebak(3);
      expect(game.selesai, isTrue);
      expect(game.menang, isFalse);
      expect(game.sisa, 0);
    });

    test('menebak setelah ronde selesai melempar error', () {
      final game = TebakAngkaGame.denganRahasia(kecil, 6)..tebak(6);
      expect(() => game.tebak(1), throwsStateError);
    });
  });

  Future<void> mainSatuTebakan(WidgetTester tester, Size ukuran) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TebakAngkaApp());
    expect(find.text('Pilih level'), findsOneWidget);
    expect(find.text('Belum ada ronde selesai.'), findsOneWidget);

    await tester.ensureVisible(find.text('Mulai'));
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Sisa percobaan: 10 dari 10'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '25');
    await tester.ensureVisible(find.text('Tebak'));
    await tester.tap(find.text('Tebak'));
    await tester.pumpAndSettle();

    // Hasilnya acak (menang atau terlalu besar/kecil), tapi satu tebakan
    // pasti tercatat di ronde ini.
    expect(find.text('Tebakan ronde ini'), findsOneWidget);
  }

  testWidgets('dashboard di layar lebar (laptop)', (tester) async {
    await mainSatuTebakan(tester, const Size(1400, 1000));
  });

  testWidgets('dashboard di layar sempit (HP)', (tester) async {
    await mainSatuTebakan(tester, const Size(400, 900));
  });
}
