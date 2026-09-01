enum DevelopmentPoolType { bauxite, ammunition, fuelSteel }

class DevelopmentResources {
  const DevelopmentResources(this.fuel, this.ammo, this.steel, this.bauxite);

  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;

  List<int> get values => <int>[fuel, ammo, steel, bauxite];
  int get total => fuel + ammo + steel + bauxite;

  DevelopmentResources normalized() => DevelopmentResources(
    _clampResource(fuel),
    _clampResource(ammo),
    _clampResource(steel),
    _clampResource(bauxite),
  );

  bool covers(DevelopmentResources other) =>
      fuel >= other.fuel &&
      ammo >= other.ammo &&
      steel >= other.steel &&
      bauxite >= other.bauxite;

  static DevelopmentResources maxima(Iterable<DevelopmentResources> values) {
    var fuel = 10;
    var ammo = 10;
    var steel = 10;
    var bauxite = 10;
    for (final value in values) {
      if (value.fuel > fuel) fuel = value.fuel;
      if (value.ammo > ammo) ammo = value.ammo;
      if (value.steel > steel) steel = value.steel;
      if (value.bauxite > bauxite) bauxite = value.bauxite;
    }
    return DevelopmentResources(fuel, ammo, steel, bauxite);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevelopmentResources &&
          fuel == other.fuel &&
          ammo == other.ammo &&
          steel == other.steel &&
          bauxite == other.bauxite;

  @override
  int get hashCode => Object.hash(fuel, ammo, steel, bauxite);

  @override
  String toString() => 'DevelopmentResources($fuel, $ammo, $steel, $bauxite)';
}

int _clampResource(int value) => value < 10 ? 10 : (value > 300 ? 300 : value);
