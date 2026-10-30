# Tebak Angka

Game tebak angka berbasis terminal yang ditulis dengan Python. Pemain menebak angka rahasia dengan bantuan petunjuk "terlalu besar" atau "terlalu kecil" sampai benar atau percobaan habis.

## Fitur

- Tiga level kesulitan dengan rentang angka dan jumlah percobaan berbeda
- Validasi input (menolak huruf dan angka di luar rentang)
- Petunjuk di setiap tebakan
- Skor menang/kalah selama sesi berjalan
- Opsi main lagi tanpa restart program

| Level  | Rentang | Percobaan |
|--------|---------|-----------|
| Mudah  | 1-50    | 10        |
| Sedang | 1-100   | 7         |
| Sulit  | 1-500   | 9         |

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

## Versi App (Android dan Windows)

Folder `flutter_app/` berisi versi app dengan aturan yang sama, dibuat dengan Flutter.
Logika game ada di `flutter_app/lib/game.dart`, tampilan di `flutter_app/lib/main.dart`.

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

## Catatan

Versi awal dibuat dengan bantuan AI; perbaikan dan fitur selanjutnya dikerjakan sendiri.

## Rencana Pengembangan

- [x] Tangani input angka non-ASCII tanpa crash
- [x] Keluar dengan rapi saat Ctrl+C
- [ ] Simpan high score ke file
- [ ] Mode kebalikan: komputer yang menebak

## Lisensi

MIT
