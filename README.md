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

## Catatan

Versi awal dibuat dengan bantuan AI; perbaikan dan fitur selanjutnya dikerjakan sendiri.

## Rencana Pengembangan

- [x] Tangani input angka non-ASCII tanpa crash
- [x] Keluar dengan rapi saat Ctrl+C
- [ ] Simpan high score ke file
- [ ] Mode kebalikan: komputer yang menebak

## Lisensi

MIT
