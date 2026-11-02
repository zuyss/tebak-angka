/// Teks dalam dua bahasa, untuk pesan yang dibuat di file logika (yang
/// nggak punya akses ke pengaturan bahasa). Tampilan yang memilih versinya.
class Dua {
  const Dua(this.id, this.en);

  final String id;
  final String en;

  String pilih({required bool inggris}) => inggris ? en : id;

  @override
  bool operator ==(Object other) =>
      other is Dua && other.id == id && other.en == en;

  @override
  int get hashCode => Object.hash(id, en);

  @override
  String toString() => id;
}
