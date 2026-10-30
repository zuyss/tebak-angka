"""Regression tests untuk validasi input tebak_angka.

Menjalankan: python -m unittest discover -s tests -t . -v
Hanya stdlib, tanpa dependensi.
"""
import io
import unittest
from contextlib import redirect_stdout
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


if __name__ == "__main__":
    unittest.main()
