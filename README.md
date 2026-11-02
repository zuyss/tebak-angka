# Tebak Angka

> **Proyek vibecoding.** Kode di repo ini ditulis oleh AI (Claude dari Anthropic)
> berdasarkan arahan saya. Lihat [Tentang proyek ini](#tentang-proyek-ini).

Kumpulan game tebak-tebakan dalam dua bentuk:

- **Game terminal (Python)**: kamu menebak angka rahasia komputer dengan petunjuk
  "terlalu besar" atau "terlalu kecil", atau sebaliknya komputer yang menebak angkamu.
- **App web, Android, dan Windows (Flutter)**: tebak angka mode Panas-Dingin dan Detektif,
  komputer yang menebak, tantangan harian, Wordle bahasa Indonesia dan Inggris, dan
  Mode Hacker (bobol PIN). **Main langsung di browser:**
  https://zuyss.github.io/tebak-angka/

## Tentang proyek ini

Ini proyek *vibecoding*: saya menentukan apa yang mau dibuat dan mengarahkan hasilnya,
sedangkan kodenya ditulis oleh AI (Claude). Commit yang dibuat AI ditandai dengan baris
`Co-Authored-By: Claude` di riwayat git.

Bagian yang saya kerjakan:

- Menentukan fitur dan arah tampilan (mode permainan, Wordle dua bahasa, tema kaca putih)
- Mencoba app-nya langsung, lalu melaporkan masalah seperti tampilan yang
  patah-patah dan kolom input yang kehilangan fokus
- Menjalankan git, membaca log GitHub Actions saat build gagal, dan mengirimkannya ke AI
- Memutuskan perubahan mana yang dipakai

Yang saya pelajari dari proyek ini: alur kerja git dan GitHub Actions, cara membaca error
build, dan bagaimana AI bisa salah (beberapa build sempat gagal karena kode dari AI) sehingga
hasilnya tetap harus dites dan dicek.

## Fitur (versi Python)

- Tiga level kesulitan dengan rentang angka dan jumlah percobaan berbeda
- Validasi input (menolak huruf dan angka di luar rentang)
- Petunjuk di setiap tebakan
- Skor menang/kalah selama sesi berjalan
- Opsi main lagi tanpa restart program
- High score per level (percobaan paling sedikit) tersimpan di `skor_tertinggi.json`
- Mode kebalikan: komputer menebak angkamu pakai binary search, dan tahu kalau jawabanmu saling bertentangan

| Level  | Rentang | Percobaan |
|--------|---------|-----------|
| Mudah  | 1-50    | 10        |
| Sedang | 1-100   | 7         |
| Sulit  | 1-500   | 9         |

Jumlah percobaan tiap level pas untuk binary search (2^10 >= 50, 2^7 >= 100, 2^9 >= 500),
jadi di mode kebalikan komputer selalu menang selama kamu menjawab jujur.

## Cara Menjalankan

Butuh Python 3.8 atau lebih baru.

```bash
git clone https://github.com/zuyss/tebak-angka.git
cd tebak-angka
python3 tebak_angka.py
```

## Pengujian

```bash
python -m unittest discover -s tests -t . -v
```

Hanya memakai `unittest` dari stdlib, tanpa dependensi tambahan. Test dijalankan
otomatis lewat GitHub Actions pada Python 3.10 sampai 3.13.

## Versi App (Web, Android, dan Windows)

> The app is available in English too: open **Pengaturan** (gear icon) and choose **English**.

Folder `flutter_app/` berisi versi app dengan tampilan light glassmorphism dan dua game:

- **Tebak Angka**, dengan dua mode:
  - *Panas-Dingin*: petunjuknya suhu (membeku sampai membara) sesuai jarak tebakan
    ke angka rahasia, plus keterangan makin dekat atau makin jauh dari tebakan sebelumnya.
  - *Detektif*: tiap tebakan salah membuka satu petunjuk sifat angka (genap/ganjil,
    kelipatan, prima, jumlah digit, rentang), dari yang samar ke yang spesifik.
- **Komputer yang menebak**: kebalikannya, kamu memikirkan angka dan komputer menebak
  pakai binary search. Rentang yang masih mungkin ditampilkan menyempit tiap jawaban,
  dan jawaban yang saling bertentangan ketahuan.
- **Wordle** bahasa Indonesia dan Inggris, 4 sampai 7 huruf, 6 kesempatan.
  Bisa diketik pakai keyboard di layar atau keyboard fisik. Ada **mode sulit** seperti
  Wordle asli: huruf hijau wajib tetap di posisinya dan huruf kuning wajib dipakai lagi.
- **Duel 2 pemain** di satu perangkat, untuk tebak angka dan Mode Hacker: pemain 1 bikin
  rahasia, pemain 2 menebak, lalu gantian. Yang butuh percobaan paling sedikit menang.
- **Tantangan harian**: satu angka dan satu kata Wordle (per bahasa) yang sama untuk
  semua pemain tiap hari, cuma bisa dimainkan sekali, dan hasilnya bisa disalin untuk
  dibagikan. Tanpa server: angka dan katanya diturunkan dari tanggal lewat fungsi hash
  di `flutter_app/lib/harian.dart`, yang hasilnya sama di web, Android, dan Windows.
- **Mode Hacker**: bobol PIN 3, 4, atau 5 digit dengan petunjuk ala Mastermind (berapa
  digit tepat posisinya, berapa yang salah tempat), di tampilan bergaya terminal.

Statistik (menang/kalah, rekor per mode dan level, riwayat, streak Wordle) tersimpan
di perangkat dan tetap ada setelah app ditutup. Di versi web, statistik tersimpan di
browser yang dipakai.

Ada **16 pencapaian** (ikon piala) yang terbuka saat kamu melakukan sesuatu, misalnya
menang dalam 1 tebakan, menyelesaikan tantangan harian 7 hari berturut-turut, atau
membobol PIN tingkat Elite. Pencapaian nggak ikut terhapus saat statistik dihapus.

Lewat tombol **Pengaturan** (ikon roda gigi) kamu bisa mengganti bahasa tampilan
(Indonesia atau English), memilih tema terang, gelap, atau ikut setting sistem, mematikan animasi latar kalau app terasa patah-patah, mematikan getar,
atau menghapus semua statistik. Semua warna yang berubah antara tema terang dan gelap
dikumpulkan di satu palet (`Palet` di `flutter_app/lib/kaca.dart`).

Logika game ada di `game.dart`, `komputer.dart`, `harian.dart`, `wordle.dart`,
`hacker.dart`, dan `duel.dart` di `flutter_app/lib/` (tanpa Flutter, gampang dites). Tampilan ada di `halaman_angka.dart`, `halaman_wordle.dart`,
dan komponen kaca di `kaca.dart`.

Daftar kata Wordle (`flutter_app/assets/kata/`) dibuat dengan `flutter_app/tool/buat_kata.py`
dari daftar entri KBBI ([damzaky/kumpulan-kata-bahasa-indonesia-KBBI](https://github.com/damzaky/kumpulan-kata-bahasa-indonesia-KBBI)),
[dwyl/english-words](https://github.com/dwyl/english-words), dan data frekuensi
[wordfreq](https://github.com/rspeer/wordfreq) (CC BY-SA 4.0), jadi daftar kata ini ikut
berlisensi CC BY-SA 4.0.

APK Android dan exe Windows di-build otomatis oleh GitHub Actions (workflow `build-app`)
setiap ada perubahan di `flutter_app/`. Hasilnya bisa diunduh dari tab **Actions**, bagian
**Artifacts** di run terakhir.

Build sendiri di komputer (butuh Flutter SDK; Android SDK untuk APK; Visual Studio
dengan "Desktop development with C++" untuk Windows):

```bash
cd flutter_app
flutter create --project-name tebak_angka --org com.zuyss --platforms=android,windows .
# hapus test contoh bawaan flutter create (manggil MyApp, nggak ada di app ini)
del test\widget_test.dart        # di Linux/macOS: rm test/widget_test.dart
flutter test
flutter build apk --release      # hasil: build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release  # hasil: build/windows/x64/runner/Release/
```

## Rencana Pengembangan

- [x] Tangani input angka non-ASCII tanpa crash
- [x] Keluar dengan rapi saat Ctrl+C
- [x] Simpan high score ke file
- [x] Mode kebalikan: komputer yang menebak
- [x] App: statistik, rekor per mode dan level, dan pilihan terakhir tersimpan
- [x] App: tantangan harian (angka dan kata yang sama untuk semua orang, bisa dibagikan)
- [x] App: mode komputer yang menebak, seperti versi Python
- [x] App: Mode Hacker, menebak PIN dengan petunjuk ala Mastermind
- [x] App: pengaturan (animasi latar, getar, hapus statistik)
- [x] App: duel 2 pemain untuk tebak angka dan Mode Hacker
- [x] App: Wordle mode sulit
- [x] App: pencapaian (badge)
- [x] App: mode gelap
- [x] App: tampilan bahasa Inggris

## Lisensi

MIT
