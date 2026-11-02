// Pengaturan app yang berlaku di semua halaman, disimpan permanen.

import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'simpanan.dart';

class Pengaturan extends ChangeNotifier {
  Pengaturan({this.simpanan}) {
    final data = simpanan?.baca(_kunci);
    if (data != null) {
      _animasiLatar = data['animasiLatar'] != false;
      _getar = data['getar'] != false;
      _tema = ThemeMode.values.where((m) => m.name == data['tema']).firstOrNull ??
          ThemeMode.system;
    }
  }

  final Simpanan? simpanan;

  static const _kunci = 'pengaturan.v1';

  /// Kunci statistik yang dihapus oleh "Hapus statistik". Progres
  /// tantangan harian sengaja nggak ikut dihapus, supaya tantangan hari ini
  /// nggak bisa diulang dengan cara menghapus statistik.
  static const kunciStatistik = ['tebak_angka.v1', 'wordle.v1', 'hacker.v1'];

  bool _animasiLatar = true;
  bool _getar = true;
  ThemeMode _tema = ThemeMode.system;

  /// Tema terang, gelap, atau ikut setting sistem (bawaan).
  ThemeMode get tema => _tema;
  set tema(ThemeMode nilai) {
    if (nilai == _tema) return;
    _tema = nilai;
    _simpanDanKabari();
  }

  /// Latar bergerak pelan. Matikan kalau app terasa patah-patah.
  bool get animasiLatar => _animasiLatar;
  set animasiLatar(bool nilai) {
    if (nilai == _animasiLatar) return;
    _animasiLatar = nilai;
    _simpanDanKabari();
  }

  /// Getar halus saat menebak (di HP; perangkat lain mengabaikannya).
  bool get getar => _getar;
  set getar(bool nilai) {
    if (nilai == _getar) return;
    _getar = nilai;
    _simpanDanKabari();
  }

  void _simpanDanKabari() {
    simpanan?.tulis(_kunci, {
      'animasiLatar': _animasiLatar,
      'getar': _getar,
      'tema': _tema.name,
    });
    notifyListeners();
  }

  void hapusStatistik() {
    for (final k in kunciStatistik) {
      simpanan?.hapus(k);
    }
  }

  /// Getar ringan untuk tebakan biasa, getar sedang untuk hasil akhir.
  void getarkan({bool kuat = false}) {
    if (!_getar) return;
    final getaran =
        kuat ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    // Perangkat tanpa getar (atau test) bisa melempar error: abaikan saja.
    unawaited(getaran.catchError((Object _) {}));
  }
}

/// Menyediakan [Pengaturan] untuk semua widget di bawahnya.
class PengaturanScope extends InheritedNotifier<Pengaturan> {
  const PengaturanScope({
    super.key,
    required Pengaturan pengaturan,
    required super.child,
  }) : super(notifier: pengaturan);

  /// Null kalau nggak ada PengaturanScope di atasnya (misalnya di test
  /// yang membangun satu halaman saja).
  static Pengaturan? dari(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PengaturanScope>()?.notifier;

  /// Ambil pengaturan tanpa ikut dibangun ulang saat pengaturan berubah.
  /// Dipakai dari handler tombol, bukan dari build.
  static Pengaturan? baca(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PengaturanScope>()?.notifier;
}
