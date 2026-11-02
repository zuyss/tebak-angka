import json
import os
import random
from pathlib import Path

LEVEL = {
    "1": ("Mudah", 1, 50, 10),
    "2": ("Sedang", 1, 100, 7),
    "3": ("Sulit", 1, 500, 9),
}

# Batas panjang teks tebakan. Jauh di atas rentang level mana pun (maks 3 digit),
# dan jauh di bawah batas konversi integer Python (4300 digit) sehingga tidak
# pernah menyentuh batas tersebut.
MAX_TEBAKAN_DIGITS = 10

# High score disimpan di sebelah file program. Isinya: nama level -> jumlah
# percobaan paling sedikit untuk menang, misalnya {"Mudah": 4, "Sulit": 8}.
FILE_SKOR = Path(__file__).with_name("skor_tertinggi.json")

JAWABAN_KOMPUTER = {
    "b": "besar", "besar": "besar",
    "k": "kecil", "kecil": "kecil",
    "s": "benar", "benar": "benar",
}


# ---------- High score ----------

def muat_skor(path):
    """Baca high score dari file. File hilang atau rusak dianggap kosong."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    # Buang entri yang isinya aneh (misal file diedit manual).
    return {
        nama: nilai for nama, nilai in data.items()
        if isinstance(nama, str) and type(nilai) is int and nilai >= 1
    }


def simpan_skor(path, skor):
    """Tulis high score. Lewat file sementara dulu supaya file lama tidak
    rusak kalau program mati di tengah penulisan. Kembalikan True kalau berhasil."""
    sementara = f"{path}.tmp"
    try:
        with open(sementara, "w", encoding="utf-8") as f:
            json.dump(skor, f, indent=2, ensure_ascii=False)
        os.replace(sementara, path)
        return True
    except OSError:
        return False


def catat_kemenangan(skor, nama_level, percobaan):
    """Perbarui dict skor. Kembalikan True kalau ini rekor baru."""
    lama = skor.get(nama_level)
    if lama is None or percobaan < lama:
        skor[nama_level] = percobaan
        return True
    return False


# ---------- Mode 1: kamu yang menebak ----------

def pilih_level():
    print("\nPilih level:")
    for kode, (nama, bawah, atas, nyawa) in LEVEL.items():
        print(f"  {kode}. {nama} (angka {bawah}-{atas}, {nyawa} percobaan)")
    while True:
        pilihan = input("Level (1/2/3): ").strip()
        if pilihan in LEVEL:
            return LEVEL[pilihan]
        print("Pilihan tidak valid, coba lagi.")


def minta_tebakan(bawah, atas):
    while True:
        teks = input(f"Tebakan kamu ({bawah}-{atas}): ").strip()

        # isdecimal(), bukan isdigit(): isdigit() juga True untuk '²', '³', '①'
        # yang ditolak int() dan membuat program crash. Karakter desimal
        # non-ASCII seperti '٣' atau '４' tetap diterima, sesuai perilaku int().
        if not teks.isdecimal():
            print("Masukkan angka bulat ya.")
            continue

        if len(teks) > MAX_TEBAKAN_DIGITS:
            print("Angkanya terlalu panjang.")
            continue

        angka = int(teks)
        if bawah <= angka <= atas:
            return angka
        print(f"Angka harus di antara {bawah} dan {atas}.")


def main_satu_ronde(file_skor=None):
    """Satu ronde pemain menebak. Kalau file_skor diisi, high score dibaca
    dan disimpan ke file itu. Kembalikan True kalau pemain menang."""
    nama, bawah, atas, nyawa = pilih_level()
    skor = muat_skor(file_skor) if file_skor else {}
    rahasia = random.randint(bawah, atas)
    print(f"\nLevel {nama}. Aku sudah pilih angka antara {bawah} dan {atas}.")
    if nama in skor:
        print(f"Rekor level ini: menang dalam {skor[nama]} percobaan.")

    for percobaan in range(1, nyawa + 1):
        sisa = nyawa - percobaan + 1
        print(f"\nSisa percobaan: {sisa}")
        tebakan = minta_tebakan(bawah, atas)

        if tebakan == rahasia:
            print(f"Benar! Angkanya {rahasia}. Kamu menang dalam {percobaan} percobaan.")
            if file_skor and catat_kemenangan(skor, nama, percobaan):
                print("Rekor baru!")
                if not simpan_skor(file_skor, skor):
                    print("(Rekor gagal disimpan ke file.)")
            return True
        elif tebakan < rahasia:
            print("Terlalu kecil.")
        else:
            print("Terlalu besar.")

    print(f"\nPercobaan habis. Angka yang benar: {rahasia}.")
    return False


# ---------- Mode 2: komputer yang menebak ----------

def minta_jawaban(tebakan):
    while True:
        teks = input(f"Aku tebak {tebakan}. (b) terlalu besar, (k) terlalu kecil, (s) benar: ")
        jawaban = JAWABAN_KOMPUTER.get(teks.strip().lower())
        if jawaban:
            return jawaban
        print("Jawab dengan b, k, atau s ya.")


def komputer_menebak():
    """Pemain memikirkan angka, komputer menebak pakai binary search: selalu
    menebak tengah-tengah rentang yang tersisa, jadi rentangnya terpotong
    setengah tiap tebakan.

    Kembalikan True kalau komputer menang, False kalau percobaan habis,
    None kalau jawaban pemain saling bertentangan."""
    nama, bawah, atas, nyawa = pilih_level()
    print(f"\nLevel {nama}. Pikirkan satu angka antara {bawah} dan {atas}, "
          f"aku punya {nyawa} percobaan.")

    for percobaan in range(1, nyawa + 1):
        if bawah > atas:
            break
        tebakan = (bawah + atas) // 2
        jawaban = minta_jawaban(tebakan)
        if jawaban == "benar":
            print(f"Yes! Aku menebak angkamu dalam {percobaan} percobaan.")
            return True
        if jawaban == "besar":
            atas = tebakan - 1
        else:
            bawah = tebakan + 1

    if bawah > atas:
        print("Hmm, jawabanmu saling bertentangan. Nggak ada angka yang cocok.")
        return None
    print(f"Aku kalah, percobaan habis. Angkamu ada di antara {bawah} dan {atas}.")
    return False


# ---------- Menu utama ----------

def pilih_mode():
    print("\nPilih mode:")
    print("  1. Kamu yang menebak")
    print("  2. Komputer yang menebak")
    print("  3. Lihat skor tertinggi")
    while True:
        pilihan = input("Mode (1/2/3): ").strip()
        if pilihan in ("1", "2", "3"):
            return pilihan
        print("Pilihan tidak valid, coba lagi.")


def tampilkan_skor(file_skor):
    skor = muat_skor(file_skor)
    print("\nSkor tertinggi (percobaan paling sedikit):")
    for nama, _, _, _ in LEVEL.values():
        nilai = skor.get(nama)
        print(f"  {nama}: {nilai if nilai else '-'}")


def main(file_skor=FILE_SKOR):
    print("=== GAME TEBAK ANGKA ===")
    menang = kalah = 0
    komputer_menang = komputer_kalah = 0

    try:
        while True:
            mode = pilih_mode()
            if mode == "3":
                tampilkan_skor(file_skor)
                continue

            if mode == "1":
                if main_satu_ronde(file_skor):
                    menang += 1
                else:
                    kalah += 1
                print(f"Skor kamu: {menang} menang, {kalah} kalah")
            else:
                hasil = komputer_menebak()
                if hasil is True:
                    komputer_menang += 1
                elif hasil is False:
                    komputer_kalah += 1
                print(f"Skor komputer: {komputer_menang} menang, {komputer_kalah} kalah")

            lagi = input("Main lagi? (y/n): ").strip().lower()
            if lagi != "y":
                print("Makasih udah main!")
                break
    except (EOFError, KeyboardInterrupt):
        # stdin habis (input pipa/otomasi) atau Ctrl+C: keluar rapi,
        # bukan menampilkan traceback.
        print("\nSampai jumpa!")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
