// Penyimpanan permanen untuk statistik dan pilihan terakhir pemain.
//
// Data disimpan sebagai teks JSON per kunci. Di Android memakai
// SharedPreferences, di Windows file di folder AppData, dan di web
// localStorage browser (jadi statistik di web tersimpan per browser).

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class Simpanan {
  /// Baca data di [kunci]. Null kalau belum ada atau isinya rusak.
  Map<String, Object?>? baca(String kunci);

  void tulis(String kunci, Map<String, Object?> data);
}

/// Ubah teks JSON jadi map. Teks yang rusak atau bukan objek -> null.
Map<String, Object?>? uraiJson(String? teks) {
  if (teks == null) return null;
  try {
    final data = jsonDecode(teks);
    return data is Map ? Map<String, Object?>.from(data) : null;
  } on FormatException {
    return null;
  }
}

class SimpananPrefs implements Simpanan {
  SimpananPrefs(this._prefs);

  final SharedPreferences _prefs;

  @override
  Map<String, Object?>? baca(String kunci) => uraiJson(_prefs.getString(kunci));

  @override
  void tulis(String kunci, Map<String, Object?> data) {
    // Nilai langsung masuk cache di memori; penulisan ke disk berjalan
    // di belakang, jadi tampilan nggak perlu menunggu.
    unawaited(_prefs.setString(kunci, jsonEncode(data)));
  }
}

/// Penyimpanan di memori saja, untuk test.
class SimpananMemori implements Simpanan {
  final _isi = <String, String>{};

  @override
  Map<String, Object?>? baca(String kunci) => uraiJson(_isi[kunci]);

  @override
  void tulis(String kunci, Map<String, Object?> data) {
    _isi[kunci] = jsonEncode(data);
  }

  /// Untuk test: isi langsung dengan teks mentah (misalnya yang rusak).
  void isiMentah(String kunci, String teks) => _isi[kunci] = teks;
}

/// Ambil bilangan bulat tak negatif dari data tersimpan, atau [bawaan].
int angkaAman(Object? nilai, [int bawaan = 0]) =>
    nilai is int && nilai >= 0 ? nilai : bawaan;
