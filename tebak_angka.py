import random

LEVEL = {
    "1": ("Mudah", 1, 50, 10),
    "2": ("Sedang", 1, 100, 7),
    "3": ("Sulit", 1, 500, 9),
}


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
        if not teks.isdigit():
            print("Masukkan angka bulat ya.")
            continue
        angka = int(teks)
        if bawah <= angka <= atas:
            return angka
        print(f"Angka harus di antara {bawah} dan {atas}.")


def main_satu_ronde():
    nama, bawah, atas, nyawa = pilih_level()
    rahasia = random.randint(bawah, atas)
    print(f"\nLevel {nama}. Aku sudah pilih angka antara {bawah} dan {atas}.")

    for percobaan in range(1, nyawa + 1):
        sisa = nyawa - percobaan + 1
        print(f"\nSisa percobaan: {sisa}")
        tebakan = minta_tebakan(bawah, atas)

        if tebakan == rahasia:
            print(f"Benar! Angkanya {rahasia}. Kamu menang dalam {percobaan} percobaan.")
            return True
        elif tebakan < rahasia:
            print("Terlalu kecil.")
        else:
            print("Terlalu besar.")

    print(f"\nPercobaan habis. Angka yang benar: {rahasia}.")
    return False


def main():
    print("=== GAME TEBAK ANGKA ===")
    menang = 0
    kalah = 0

    while True:
        if main_satu_ronde():
            menang += 1
        else:
            kalah += 1

        print(f"Skor: {menang} menang, {kalah} kalah")
        lagi = input("Main lagi? (y/n): ").strip().lower()
        if lagi != "y":
            print("Makasih udah main!")
            break


if __name__ == "__main__":
    main()
