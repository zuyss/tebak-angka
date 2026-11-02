// Duel 2 pemain di satu perangkat: pemain 1 bikin rahasia, pemain 2
// menebak; lalu gantian. Yang butuh percobaan paling sedikit menang.
// File ini cuma mengatur giliran dan skor; permainannya sendiri memakai
// TebakAngkaGame atau HackerGame yang sudah ada.

enum TahapDuel {
  /// Pemain 1 memasukkan rahasia, pemain 2 nggak boleh lihat.
  rahasia1,

  /// Pemain 2 menebak rahasia pemain 1.
  tebak2,

  /// Pemain 2 memasukkan rahasia.
  rahasia2,

  /// Pemain 1 menebak rahasia pemain 2.
  tebak1,
  selesai,
}

enum HasilDuel { pemain1, pemain2, seri }

class Duel {
  Duel({required this.nyawa});

  /// Jatah percobaan per giliran. Gagal menebak = skor [nyawa] + 1.
  final int nyawa;

  TahapDuel tahap = TahapDuel.rahasia1;

  /// Skor = jumlah percobaan sampai benar. Makin kecil makin bagus.
  int? skor1;
  int? skor2;

  /// Pemain yang sedang memasukkan rahasia atau menebak (1 atau 2).
  int get pemainAktif => switch (tahap) {
        TahapDuel.rahasia1 || TahapDuel.tebak1 => 1,
        TahapDuel.rahasia2 || TahapDuel.tebak2 => 2,
        TahapDuel.selesai => 0,
      };

  void rahasiaSiap() {
    tahap = switch (tahap) {
      TahapDuel.rahasia1 => TahapDuel.tebak2,
      TahapDuel.rahasia2 => TahapDuel.tebak1,
      _ => throw StateError('Bukan giliran memasukkan rahasia.'),
    };
  }

  /// Catat hasil giliran menebak yang baru selesai.
  void selesaiMenebak({required bool menang, required int percobaan}) {
    final skor = menang ? percobaan : nyawa + 1;
    switch (tahap) {
      case TahapDuel.tebak2:
        skor2 = skor;
        tahap = TahapDuel.rahasia2;
      case TahapDuel.tebak1:
        skor1 = skor;
        tahap = TahapDuel.selesai;
      default:
        throw StateError('Bukan giliran menebak.');
    }
  }

  HasilDuel? get hasil {
    final a = skor1, b = skor2;
    if (tahap != TahapDuel.selesai || a == null || b == null) return null;
    if (a < b) return HasilDuel.pemain1;
    if (b < a) return HasilDuel.pemain2;
    return HasilDuel.seri;
  }

  /// Teks skor satu pemain, misalnya "4 percobaan" atau "gagal".
  String teksSkor(int? skor) => skor == null
      ? '-'
      : skor > nyawa
          ? 'gagal'
          : '$skor percobaan';
}
