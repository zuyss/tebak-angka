import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'halaman_angka.dart';
import 'halaman_hacker.dart';
import 'halaman_wordle.dart';
import 'kaca.dart';
import 'pencapaian.dart';
import 'pengaturan.dart';
import 'simpanan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Simpanan? simpanan;
  try {
    simpanan = SimpananPrefs(await SharedPreferences.getInstance());
  } catch (_) {
    // Penyimpanan nggak tersedia (misalnya browser memblokir localStorage):
    // game tetap jalan, cuma statistiknya nggak tersimpan.
    simpanan = null;
  }
  runApp(TebakAngkaApp(simpanan: simpanan));
}

class TebakAngkaApp extends StatefulWidget {
  const TebakAngkaApp({
    super.key,
    this.pemuatKamus = muatKamusDariAset,
    this.latarBergerak = true,
    this.simpanan,
    this.jam = DateTime.now,
  });

  /// Bisa diganti di test supaya nggak perlu baca file aset.
  final PemuatKamus pemuatKamus;

  /// Tempat menyimpan statistik. Null = nggak disimpan.
  final Simpanan? simpanan;

  /// Sumber waktu untuk tantangan harian. Bisa diganti di test.
  final DateTime Function() jam;

  /// Dimatikan di test (animasi tanpa akhir bikin pumpAndSettle macet).
  final bool latarBergerak;

  @override
  State<TebakAngkaApp> createState() => _TebakAngkaAppState();
}

class _TebakAngkaAppState extends State<TebakAngkaApp> {
  /// Tekan F3 untuk menampilkan grafik waktu per frame. Grafik atas = GPU
  /// (raster), bawah = Dart (UI). Batang merah = frame yang telat.
  bool _grafikPerforma = false;

  late final Pengaturan _pengaturan = Pengaturan(simpanan: widget.simpanan);
  late final Pencapaian _pencapaian = Pencapaian(simpanan: widget.simpanan);

  @override
  void dispose() {
    _pengaturan.dispose();
    _pencapaian.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PengaturanScope(
      pengaturan: _pengaturan,
      child: PencapaianScope(
        pencapaian: _pencapaian,
        child: ListenableBuilder(
          listenable: _pengaturan,
          builder: (context, _) => CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.f3): () =>
                  setState(() => _grafikPerforma = !_grafikPerforma),
            },
            child: MaterialApp(
              title: 'Tebak Angka',
              debugShowCheckedModeBanner: false,
              showPerformanceOverlay: _grafikPerforma,
              themeMode: _pengaturan.tema,
              theme: ThemeData(
                colorSchemeSeed: const Color(0xFF0F172A),
                extensions: const [Palet.terang],
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0F172A),
                  brightness: Brightness.dark,
                ),
                extensions: const [Palet.gelap],
              ),
              home: Beranda(
                pemuatKamus: widget.pemuatKamus,
                latarBergerak: widget.latarBergerak,
                simpanan: widget.simpanan,
                jam: widget.jam,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Beranda extends StatefulWidget {
  const Beranda({
    super.key,
    required this.pemuatKamus,
    required this.latarBergerak,
    this.simpanan,
    this.jam = DateTime.now,
  });

  final PemuatKamus pemuatKamus;
  final bool latarBergerak;
  final Simpanan? simpanan;
  final DateTime Function() jam;

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  int _halaman = 0; // 0 = Tebak Angka, 1 = Wordle, 2 = Hacker

  // Halaman dibangun saat pertama dibuka saja, biar app cepat terbuka dan
  // daftar kata Wordle nggak dimuat kalau nggak dimainkan.
  final Set<int> _pernahDibuka = {0};

  /// Naik saat statistik dihapus: semua halaman dibangun ulang dari nol
  /// (key-nya berubah), jadi angka di layar ikut kosong.
  int _generasi = 0;

  Future<void> _bukaPengaturan() async {
    final pengaturan = PengaturanScope.baca(context);
    if (pengaturan == null) return;
    final hapus = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogPengaturan(pengaturan: pengaturan),
    );
    if (hapus != true || !mounted) return;
    pengaturan.hapusStatistik();
    setState(() => _generasi++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Statistik dihapus.')),
    );
  }

  String _sapaan() {
    final jamSekarang = widget.jam().hour;
    if (jamSekarang < 11) return 'Selamat pagi';
    if (jamSekarang < 15) return 'Selamat siang';
    if (jamSekarang < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _pindah(int halaman) {
    setState(() {
      _halaman = halaman;
      _pernahDibuka.add(halaman);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LatarBening(
        bergerak: widget.latarBergerak &&
            (PengaturanScope.dari(context)?.animasiLatar ?? true),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: _header(),
                  ),
                ),
              ),
              Expanded(
                // IndexedStack: pindah halaman nggak menghapus progres.
                child: IndexedStack(
                  index: _halaman,
                  children: [
                    HalamanAngka(
                      key: ValueKey('angka-$_generasi'),
                      simpanan: widget.simpanan,
                      jam: widget.jam,
                    ),
                    if (_pernahDibuka.contains(1))
                      HalamanWordle(
                        key: ValueKey('wordle-$_generasi'),
                        pemuatKamus: widget.pemuatKamus,
                        aktif: _halaman == 1,
                        simpanan: widget.simpanan,
                        jam: widget.jam,
                      )
                    else
                      const SizedBox.shrink(),
                    if (_pernahDibuka.contains(2))
                      HalamanHacker(
                        key: ValueKey('hacker-$_generasi'),
                        simpanan: widget.simpanan,
                        aktif: _halaman == 2,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final judul = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sapaan(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: context.palet.teks,
          ),
        ),
        Text(
          'Mau main apa hari ini?',
          style: TextStyle(color: context.palet.teksRedup),
        ),
      ],
    );
    final menu = _MenuSwitch(
      pilihan: const ['Tebak Angka', 'Wordle', 'Hacker'],
      indeks: _halaman,
      onGanti: _pindah,
    );

    final tombolPengaturan = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Pencapaian',
          icon: Icon(Icons.emoji_events_outlined, color: context.palet.teks),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _DialogPencapaian(),
          ),
        ),
        IconButton(
          tooltip: 'Pengaturan',
          icon: Icon(Icons.settings_outlined, color: context.palet.teks),
          onPressed: _bukaPengaturan,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, batas) {
        if (batas.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(child: judul),
              SizedBox(width: 400, child: menu),
              const SizedBox(width: 8),
              tombolPengaturan,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: judul), tombolPengaturan]),
            const SizedBox(height: 12),
            menu,
          ],
        );
      },
    );
  }
}

/// Menu pill kaca dengan indikator gradasi yang meluncur ke pilihan aktif.
class _MenuSwitch extends StatelessWidget {
  const _MenuSwitch({
    required this.pilihan,
    required this.indeks,
    required this.onGanti,
  });

  final List<String> pilihan;
  final int indeks;
  final ValueChanged<int> onGanti;

  @override
  Widget build(BuildContext context) {
    final posisi = pilihan.length == 1 ? 0.0 : indeks / (pilihan.length - 1);

    return KartuKaca(
      padding: const EdgeInsets.all(5),
      radius: 999,
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment(posisi * 2 - 1, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / pilihan.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palet.permukaan,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    // Garis tipis, bukan bayangan blur (lihat catatan di kaca.dart).
                    border: Border.fromBorderSide(
                      BorderSide(color: context.palet.garisHalus),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < pilihan.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onGanti(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            fontWeight:
                                i == indeks ? FontWeight.w800 : FontWeight.w600,
                            color: i == indeks ? context.palet.teks : context.palet.teksRedup,
                          ),
                          child: Text(pilihan[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog pengaturan. Mengembalikan true kalau pemain memilih (dan
/// mengonfirmasi) hapus statistik.
class _DialogPengaturan extends StatelessWidget {
  const _DialogPengaturan({required this.pengaturan});

  final Pengaturan pengaturan;

  Future<void> _konfirmasiHapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua statistik?'),
        content: const Text(
          'Menang/kalah, rekor, riwayat ronde, statistik Wordle, dan skor '
          'Hacker akan kembali ke nol. Ini nggak bisa dibatalkan. Progres '
          'tantangan harian hari ini tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palet.dialog,
      title: const Text('Pengaturan'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: ListenableBuilder(
        listenable: pengaturan,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Terang'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Gelap'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {pengaturan.tema},
                onSelectionChanged: (pilihan) =>
                    pengaturan.tema = pilihan.first,
              ),
            ),
            SwitchListTile(
              title: const Text('Animasi latar'),
              subtitle: const Text('Matikan kalau app terasa patah-patah.'),
              value: pengaturan.animasiLatar,
              onChanged: (v) => pengaturan.animasiLatar = v,
            ),
            SwitchListTile(
              title: const Text('Getar'),
              subtitle: const Text('Getar halus saat menebak (di HP).'),
              value: pengaturan.getar,
              onChanged: (v) => pengaturan.getar = v,
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text(
                'Hapus semua statistik',
                style: TextStyle(color: Colors.red.shade700),
              ),
              onTap: () => _konfirmasiHapus(context),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// Koleksi lencana: yang sudah terbuka berwarna, yang belum dikunci.
class _DialogPencapaian extends StatelessWidget {
  const _DialogPencapaian();

  @override
  Widget build(BuildContext context) {
    final p = PencapaianScope.dari(context);
    final jumlah = p?.jumlahTerbuka ?? 0;
    return AlertDialog(
      backgroundColor: context.palet.dialog,
      title: Text('Pencapaian ($jumlah/${daftarLencana.length})'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 420,
        // Column, bukan ListView: daftarnya pendek, dan semua lencana
        // langsung dibangun (ListView cuma membangun yang kelihatan).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((p?.harianBeruntun ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Tantangan harian beruntun: ${p!.harianBeruntun} hari',
                    style: TextStyle(color: context.palet.teksRedup),
                  ),
                ),
              for (final l in daftarLencana)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (p?.terbuka(l.id) ?? false)
                        ? context.palet.aksen
                        : context.palet.garisHalus,
                    child: Icon(
                      (p?.terbuka(l.id) ?? false) ? l.ikon : Icons.lock_outline,
                      color: (p?.terbuka(l.id) ?? false)
                          ? context.palet.diAtasAksen
                          : context.palet.teksRedup,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l.judul,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (p?.terbuka(l.id) ?? false)
                          ? context.palet.teks
                          : context.palet.teksRedup,
                    ),
                  ),
                  subtitle: Text(l.syarat),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
