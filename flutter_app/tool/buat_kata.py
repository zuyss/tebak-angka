"""Bikin daftar kata Wordle (jawaban + tebakan valid) untuk ID dan EN, 4-7 huruf.

Sumber:
- Kamus ID: daftar entri KBBI (damzaky/kumpulan-kata-bahasa-indonesia-KBBI)
- Kamus EN: dwyl/english-words (public domain), hanya entri huruf kecil
- Frekuensi kata: wordfreq (data CC BY-SA 4.0), untuk memilih jawaban yang umum
"""
import re
import sys
from pathlib import Path

import wordfreq

kbbi_path, en_path, out_dir = map(Path, sys.argv[1:4])
out_dir.mkdir(parents=True, exist_ok=True)
huruf = re.compile(r"^[a-z]+$")
vokal = re.compile(r"[aeiou]")
awal_ok = {"pr", "tr", "kr", "gr", "br", "dr", "bl", "kl", "pl", "fl", "gl", "sl", "sp",
           "st", "sk", "sw", "sm", "sn", "ny", "ng", "kh", "sy", "ts", "dz"}


def terlihat_singkatan(w):
    """Kata Indonesia jarang diawali 2 konsonan selain gugus umum, dan kata
    pendek jarang punya 3 konsonan beruntun. Singkatan biasanya melanggar."""
    konsonan = lambda c: c not in "aeiou"
    if konsonan(w[0]) and konsonan(w[1]) and w[:2] not in awal_ok:
        return True
    if len(w) <= 5 and re.search(r"[^aeiou]{3}", w) and not re.search(r"ng[^aeiou]|ny[^aeiou]", w):
        return True
    return False

kamus = {
    "id": {w.strip() for w in kbbi_path.read_text(encoding="utf-8").splitlines()},
    # Entri yang aslinya huruf kecil saja: buang nama orang/tempat (kapital).
    "en": {w.strip() for w in en_path.read_text(encoding="utf-8").splitlines()},
}
kamus = {k: {w for w in v if huruf.match(w)} for k, v in kamus.items()}

blok = {
    "en": {"fuck", "fucks", "fucked", "fucker", "shit", "shits", "shitty", "cunt", "cunts",
           "dick", "dicks", "cock", "cocks", "porn", "porno", "slut", "sluts", "whore",
           "whores", "bitch", "nigga", "nigger", "faggot", "rape", "raped", "rapes",
           "rapist", "penis", "vagina", "boobs", "pussy", "anal", "sexy", "nazi", "nazis",
           "retard", "horny", "twat", "wank", "wanker", "bastard", "damn", "hell",
           "asshole", "assholes", "bitches", "dildo", "orgasm", "semen", "sperm", "nude", "nudes"},
    "id": {"bangsat", "anjing", "babi", "kontol", "memek", "ngentot", "jancuk", "bajingan",
           "tolol", "goblok", "bego", "setan", "iblis", "keparat", "lonte", "perek",
           "pelacur", "sundal", "zina", "seks", "porno", "mampus", "mati", "bunuh",
           "kafir", "cabul", "telanjang", "bugil", "pantat", "tahi", "taik", "kampret",
           "vietnam", "lgbt"},
}

laporan = []
for bahasa in ("id", "en"):
    umum = wordfreq.top_n_list(bahasa, 300000)
    for panjang in range(4, 8):
        valid = sorted(w for w in kamus[bahasa] if len(w) == panjang)
        if bahasa == "en":
            # Kamus EN sangat besar dan banyak kata aneh: tebakan valid
            # harus pernah muncul di data frekuensi.
            valid = [w for w in valid if wordfreq.zipf_frequency(w, "en") >= 1.5]
        valid_set = set(valid)
        jawaban = []
        for w in umum:
            if len(w) == panjang and w in valid_set and w not in blok[bahasa]:
                if wordfreq.zipf_frequency(w, bahasa) < 3.0:
                    break
                if not vokal.search(w):
                    continue  # singkatan seperti "rsup"
                if bahasa == "id" and terlihat_singkatan(w):
                    continue  # "slta", "rsup"
                if bahasa == "id" and wordfreq.zipf_frequency(w, "en") > wordfreq.zipf_frequency(w, "id"):
                    continue  # kata Inggris yang nyasar di teks Indonesia ("lift", "lose")
                jawaban.append(w)
            if len(jawaban) >= 1500:
                break
        jawaban = sorted(set(jawaban))
        (out_dir / f"{bahasa}_{panjang}_jawaban.txt").write_text("\n".join(jawaban) + "\n")
        (out_dir / f"{bahasa}_{panjang}_valid.txt").write_text("\n".join(valid) + "\n")
        laporan.append(f"{bahasa} {panjang}: jawaban={len(jawaban)} valid={len(valid)}")

print("\n".join(laporan))
