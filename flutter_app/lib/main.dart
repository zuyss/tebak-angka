import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'halaman_angka.dart';
import 'halaman_hacker.dart';
import 'halaman_rahasia.dart';
import 'halaman_wordle.dart';
import 'kaca.dart';
import 'pencapaian.dart';
import 'pengaturan.dart';
import 'rahasia.dart' show PelacakKonami, brankasTerbuka;
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
          listenable: Listenable.merge([_pengaturan, _pencapaian]),
          builder: (context, _) => CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.f3): () =>
                  setState(() => _grafikPerforma = !_grafikPerforma),
            },
            child: MaterialApp(
              title: context.tr('Tebak Angka', 'Number Guess'),
              debugShowCheckedModeBanner: false,
              showPerformanceOverlay: _grafikPerforma,
              // Tema rahasia fosfor selalu gelap.
              themeMode: _pengaturan.fosfor && _pencapaian.terbuka('arsip')
                  ? ThemeMode.dark
                  : _pengaturan.tema,
              theme: ThemeData(
                colorSchemeSeed: const Color(0xFF0F172A),
                extensions: const [Palet.terang],
              ),
              darkTheme: _pengaturan.fosfor && _pencapaian.terbuka('arsip')
                  ? ThemeData(
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFF4ADE80),
                        brightness: Brightness.dark,
                      ),
                      extensions: const [Palet.fosfor],
                    )
                  : ThemeData(
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
  int _halaman = 0; // 0 = Tebak Angka, 1 = Wordle, 2 = Hacker, 3 = root

  // Halaman dibangun saat pertama dibuka saja, biar app cepat terbuka dan
  // daftar kata Wordle nggak dimuat kalau nggak dimainkan.
  final Set<int> _pernahDibuka = {0};

  /// Naik saat statistik dihapus: semua halaman dibangun ulang dari nol
  /// (key-nya berubah), jadi angka di layar ikut kosong.
  int _generasi = 0;

  // ---------- rahasia: kode lama dan brankas waktu ----------

  final _konami = PelacakKonami();

  /// Mode kacau: seluruh isi halaman dicerminkan.
  bool _cermin = false;

  /// Ketukan di salam setelah usapan bergantian jadi B lalu A.
  String _ketukBerikut = 'b';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_tanganiTombol);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_tanganiTombol);
    super.dispose();
  }

  /// Dengar semua tombol (tanpa menghabiskannya) untuk kode lama.
  bool _tanganiTombol(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    final tombol = switch (k) {
      LogicalKeyboardKey.arrowUp => 'u',
      LogicalKeyboardKey.arrowDown => 'd',
      LogicalKeyboardKey.arrowLeft => 'l',
      LogicalKeyboardKey.arrowRight => 'r',
      LogicalKeyboardKey.keyB => 'b',
      LogicalKeyboardKey.keyA => 'a',
      _ => null,
    };
    if (tombol != null) _masukkanKode(tombol);
    return false;
  }

  void _masukkanKode(String tombol) {
    if (!_konami.masukkan(tombol) || !mounted) return;
    setState(() => _cermin = !_cermin);
    bukaLencana(context, ['kacau']);
  }

  void _usapSalam(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 150) return;
    _ketukBerikut = 'b';
    if (v.dx.abs() > v.dy.abs()) {
      _masukkanKode(v.dx > 0 ? 'r' : 'l');
    } else {
      _masukkanKode(v.dy > 0 ? 'd' : 'u');
    }
  }

  void _ketukSalam() {
    final tombol = _ketukBerikut;
    _ketukBerikut = tombol == 'b' ? 'a' : 'b';
    _masukkanKode(tombol);
  }

  /// Brankas waktu: tahan salam di menit yang tepat, setelah ular terbuka.
  void _tahanSalam() {
    final p = PencapaianScope.baca(context);
    if (p == null || !p.terbuka('ular') || p.terbuka('brankas')) return;
    if (!brankasTerbuka(widget.jam())) return;
    bukaLencana(context, ['brankas']);
    _pindah(3);
  }

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
      SnackBar(content: Text(context.tr('Statistik dihapus.', 'Stats cleared.'))),
    );
  }

  String _sapaan() {
    final jamSekarang = widget.jam().hour;
    if (jamSekarang < 11) return context.tr('Selamat pagi', 'Good morning');
    if (jamSekarang < 15) return context.tr('Selamat siang', 'Good afternoon');
    if (jamSekarang < 18) return context.tr('Selamat sore', 'Good afternoon');
    return context.tr('Selamat malam', 'Good evening');
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
                child: Transform.flip(
                  flipX: _cermin,
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
                    if (_pernahDibuka.contains(3))
                      HalamanRahasia(
                        key: ValueKey('rahasia-$_generasi'),
                        simpanan: widget.simpanan,
                        aktif: _halaman == 3,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final judul = GestureDetector(
      key: const ValueKey('salam'),
      behavior: HitTestBehavior.opaque,
      onPanEnd: _usapSalam,
      onTap: _ketukSalam,
      onLongPress: _tahanSalam,
      child: Column(
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
          context.tr('Mau main apa hari ini?', 'What do you want to play today?'),
          style: TextStyle(color: context.palet.teksRedup),
        ),
      ],
      ),
    );
    final adaRahasia =
        PencapaianScope.dari(context)?.adaGameRahasia ?? false;
    final menu = _MenuSwitch(
      pilihan: [
        context.tr('Tebak Angka', 'Number Guess'),
        'Wordle',
        'Hacker',
        if (adaRahasia) 'root',
      ],
      indeks: adaRahasia ? _halaman : _halaman.clamp(0, 2),
      onGanti: _pindah,
    );

    final tombolPengaturan = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr('Pencapaian', 'Achievements'),
          icon: Icon(Icons.emoji_events_outlined, color: context.palet.teks),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _DialogPencapaian(),
          ),
        ),
        IconButton(
          tooltip: context.tr('Pengaturan', 'Settings'),
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
              SizedBox(width: adaRahasia ? 480 : 400, child: menu),
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
                          // FittedBox: label panjang mengecil, nggak meluber.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(pilihan[i], maxLines: 1),
                          ),
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
        title: Text(context.tr('Hapus semua statistik?', 'Clear all stats?')),
        content: Text(
          context.tr('Menang/kalah, rekor, riwayat ronde, statistik Wordle, dan skor '
          'Hacker akan kembali ke nol. Ini nggak bisa dibatalkan. Progres '
          'tantangan harian hari ini tetap tersimpan.', 'Wins, losses, records, round history, Wordle stats, and Hacker scores will reset to zero. This cannot be undone. Progress on the daily challenge for today is kept.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: Text(context.tr('Hapus', 'Clear')),
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
      title: Text(context.tr('Pengaturan', 'Settings')),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: ListenableBuilder(
        listenable: pengaturan,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(context.tr('Sistem', 'System')),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(context.tr('Terang', 'Light')),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(context.tr('Gelap', 'Dark')),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {pengaturan.tema},
                onSelectionChanged: (pilihan) =>
                    pengaturan.tema = pilihan.first,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Indonesia')),
                  ButtonSegment(value: true, label: Text('English')),
                ],
                selected: {pengaturan.inggris},
                onSelectionChanged: (pilihan) =>
                    pengaturan.inggris = pilihan.first,
              ),
            ),
            if (PencapaianScope.dari(context)?.terbuka('arsip') ?? false)
              SwitchListTile(
                title: Text(context.tr('Tema Fosfor', 'Phosphor theme')),
                subtitle: Text(context.tr('Hadiah arsip tersembunyi.',
                    'Reward from the hidden archive.')),
                value: pengaturan.fosfor,
                onChanged: (v) => pengaturan.fosfor = v,
              ),
            SwitchListTile(
              title: Text(context.tr('Animasi latar', 'Background animation')),
              subtitle: Text(context.tr('Matikan kalau app terasa patah-patah.', 'Turn off if the app feels choppy.')),
              value: pengaturan.animasiLatar,
              onChanged: (v) => pengaturan.animasiLatar = v,
            ),
            SwitchListTile(
              title: Text(context.tr('Getar', 'Vibration')),
              subtitle: Text(context.tr('Getar halus saat menebak (di HP).', 'Subtle vibration when guessing (phones).')),
              value: pengaturan.getar,
              onChanged: (v) => pengaturan.getar = v,
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text(
                context.tr('Hapus semua statistik', 'Clear all stats'),
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
          child: Text(context.tr('Tutup', 'Close')),
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
      title: Text(context.tr('Pencapaian ($jumlah/${daftarLencana.length})', 'Achievements ($jumlah/${daftarLencana.length})')),
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
                    context.tr('Tantangan harian beruntun: ${p!.harianBeruntun} hari', 'Daily challenge streak: ${p.harianBeruntun} days'),
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
                    context.tr(l.judul, l.judulEn),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (p?.terbuka(l.id) ?? false)
                          ? context.palet.teks
                          : context.palet.teksRedup,
                    ),
                  ),
                  subtitle: Text(context.tr(l.syarat, l.syaratEn)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr(
                        'Rahasia (${p?.jumlahRahasiaTerbuka ?? 0}/${daftarLencanaRahasia.length})',
                        'Secrets (${p?.jumlahRahasiaTerbuka ?? 0}/${daftarLencanaRahasia.length})'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.palet.teks,
                    ),
                  ),
                ),
              ),
              for (final l in daftarLencanaRahasia)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (p?.terbuka(l.id) ?? false)
                        ? context.palet.aksen
                        : context.palet.garisHalus,
                    child: Icon(
                      (p?.terbuka(l.id) ?? false)
                          ? l.ikon
                          : Icons.question_mark,
                      color: (p?.terbuka(l.id) ?? false)
                          ? context.palet.diAtasAksen
                          : context.palet.teksRedup,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    (p?.terbuka(l.id) ?? false)
                        ? context.tr(l.judul, l.judulEn)
                        : '???',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (p?.terbuka(l.id) ?? false)
                          ? context.palet.teks
                          : context.palet.teksRedup,
                    ),
                  ),
                  subtitle: Text(context.tr(l.syarat, l.syaratEn)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Tutup', 'Close')),
        ),
      ],
    );
  }
}
