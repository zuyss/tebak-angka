"""Regression tests untuk validasi input tebak_angka.

Menjalankan: python -m unittest discover -s tests -t . -v
Hanya stdlib, tanpa dependensi.
"""
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

import tebak_angka


def tebak_dengan(inputs, bawah=1, atas=50):
    """Jalankan minta_tebakan() dengan input palsu, kembalikan hasilnya."""
    with mock.patch("builtins.input", side_effect=inputs):
        with redirect_stdout(io.StringIO()):
            return tebak_angka.minta_tebakan(bawah, atas)


class TestValidasiInput(unittest.TestCase):
    def test_unicode_digit_non_desimal_ditolak_tanpa_crash(self):
        """TA-01: '²' lolos isdigit() tapi ditolak int() -> dulu ValueError."""
        hasil = tebak_dengan(["²", "25"])
        self.assertEqual(hasil, 25)

    def test_karakter_superscript_lain(self):
        for karakter in ("³", "¹", "①"):
            with self.subTest(karakter=karakter):
                self.assertEqual(tebak_dengan([karakter, "7"]), 7)

    def test_desimal_non_ascii_tetap_diterima(self):
        """'٣' (Arab) dan '４' (lebar penuh) adalah digit desimal yang valid."""
        self.assertEqual(tebak_dengan(["٣"]), 3)
        self.assertEqual(tebak_dengan(["４"]), 4)

    def test_angka_sangat_panjang_ditolak_tanpa_crash(self):
        """TA-02: 5000 digit dulu memicu ValueError batas konversi Python."""
        hasil = tebak_dengan(["9" * 5000, "12"])
        self.assertEqual(hasil, 12)

    def test_teks_biasa_ditolak(self):
        for teks in ("abc", "", "1.5", "-5", "+5", "1e3", "  "):
            with self.subTest(teks=teks):
                self.assertEqual(tebak_dengan([teks, "9"]), 9)

    def test_di_luar_rentang_meminta_ulang(self):
        self.assertEqual(tebak_dengan(["999", "51", "0", "50"]), 50)


class TestKeluarRapi(unittest.TestCase):
    def test_eof_keluar_tanpa_traceback(self):
        """TA-03: stdin habis dulu melempar EOFError mentah."""
        with mock.patch("builtins.input", side_effect=EOFError):
            with redirect_stdout(io.StringIO()) as out:
                kode = tebak_angka.main()
        self.assertEqual(kode, 0)
        self.assertIn("Sampai jumpa", out.getvalue())

    def test_keyboard_interrupt_keluar_tanpa_traceback(self):
        with mock.patch("builtins.input", side_effect=KeyboardInterrupt):
            with redirect_stdout(io.StringIO()) as out:
                kode = tebak_angka.main()
        self.assertEqual(kode, 0)
        self.assertIn("Sampai jumpa", out.getvalue())


class TestAlurPermainan(unittest.TestCase):
    def test_menang(self):
        with mock.patch.object(tebak_angka.random, "randint", return_value=42):
            with mock.patch("builtins.input", side_effect=["1", "42"]):
                with redirect_stdout(io.StringIO()):
                    self.assertTrue(tebak_angka.main_satu_ronde())

    def test_kalah_setelah_percobaan_habis(self):
        # Level 1: 10 percobaan, rahasia 50, semua tebakan 1 -> selalu "terlalu kecil".
        with mock.patch.object(tebak_angka.random, "randint", return_value=50):
            with mock.patch("builtins.input", side_effect=["1"] + ["1"] * 10):
                with redirect_stdout(io.StringIO()):
                    self.assertFalse(tebak_angka.main_satu_ronde())


class TestSkorTertinggi(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.file = Path(self.folder.name) / "skor.json"

    def tearDown(self):
        self.folder.cleanup()

    def test_file_belum_ada_dianggap_kosong(self):
        self.assertEqual(tebak_angka.muat_skor(self.file), {})

    def test_file_rusak_tidak_crash(self):
        for isi in ("bukan json", "[1, 2]", '{"Mudah": "tiga", "Sulit": 0, "Sedang": 5}'):
            with self.subTest(isi=isi):
                self.file.write_text(isi, encoding="utf-8")
                hasil = tebak_angka.muat_skor(self.file)
                self.assertEqual(hasil, {"Sedang": 5} if "Sedang" in isi else {})

    def test_simpan_lalu_muat(self):
        self.assertTrue(tebak_angka.simpan_skor(self.file, {"Mudah": 3}))
        self.assertEqual(tebak_angka.muat_skor(self.file), {"Mudah": 3})

    def test_hanya_rekor_lebih_sedikit_yang_dicatat(self):
        skor = {}
        self.assertTrue(tebak_angka.catat_kemenangan(skor, "Mudah", 5))
        self.assertFalse(tebak_angka.catat_kemenangan(skor, "Mudah", 5))
        self.assertFalse(tebak_angka.catat_kemenangan(skor, "Mudah", 8))
        self.assertTrue(tebak_angka.catat_kemenangan(skor, "Mudah", 2))
        self.assertEqual(skor, {"Mudah": 2})

    def test_menang_menyimpan_rekor_ke_file(self):
        with mock.patch.object(tebak_angka.random, "randint", return_value=42):
            with mock.patch("builtins.input", side_effect=["1", "10", "42"]):
                with redirect_stdout(io.StringIO()) as out:
                    self.assertTrue(tebak_angka.main_satu_ronde(self.file))
        self.assertIn("Rekor baru", out.getvalue())
        self.assertEqual(json.loads(self.file.read_text(encoding="utf-8")), {"Mudah": 2})


def jawab_jujur(rahasia):
    """Bikin fungsi input palsu yang menjawab tebakan komputer dengan jujur."""
    def jawab(prompt):
        if prompt.startswith("Level"):
            return jawab.level
        tebakan = int(prompt.split()[2].rstrip("."))
        jawab.jumlah += 1
        if tebakan == rahasia:
            return "s"
        return "b" if tebakan > rahasia else "k"
    jawab.jumlah = 0
    return jawab


class TestKomputerMenebak(unittest.TestCase):
    def test_selalu_menang_kalau_dijawab_jujur(self):
        """Binary search: 2^nyawa harus >= jumlah angka di setiap level."""
        for kode, (nama, bawah, atas, nyawa) in tebak_angka.LEVEL.items():
            for rahasia in range(bawah, atas + 1):
                with self.subTest(level=nama, rahasia=rahasia):
                    jawab = jawab_jujur(rahasia)
                    jawab.level = kode
                    with mock.patch("builtins.input", side_effect=jawab):
                        with redirect_stdout(io.StringIO()):
                            self.assertTrue(tebak_angka.komputer_menebak())
                    self.assertLessEqual(jawab.jumlah, nyawa)

    def test_jawaban_bertentangan_ketahuan(self):
        # 25 -> "terlalu besar", 12 -> "terlalu kecil", 18 -> b, 15 -> k,
        # 16 -> k, 17 -> b: rentang habis, berarti jawabannya bohong.
        jawaban = ["1", "b", "k", "b", "k", "k", "b"]
        with mock.patch("builtins.input", side_effect=jawaban):
            with redirect_stdout(io.StringIO()) as out:
                self.assertIsNone(tebak_angka.komputer_menebak())
        self.assertIn("bertentangan", out.getvalue())

    def test_input_jawaban_tidak_valid_diminta_ulang(self):
        with mock.patch("builtins.input", side_effect=["1", "x", "", " S "]):
            with redirect_stdout(io.StringIO()):
                self.assertTrue(tebak_angka.komputer_menebak())


class TestMenu(unittest.TestCase):
    def test_lihat_skor_lalu_keluar(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "skor.json"
            tebak_angka.simpan_skor(file, {"Sulit": 7})
            with mock.patch("builtins.input", side_effect=["3", EOFError]):
                with redirect_stdout(io.StringIO()) as out:
                    tebak_angka.main(file)
        self.assertIn("Sulit: 7", out.getvalue())
        self.assertIn("Mudah: -", out.getvalue())


if __name__ == "__main__":
    unittest.main()
