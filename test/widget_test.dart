import 'package:flutter_test/flutter_test.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';

void main() {
  test('niveaux', () {
    expect(levelForXp(0).level, 1);
    expect(levelForXp(1000).level, 5);
    expect(levelForXp(999999).level, 10);
  });

  test('rareté', () {
    expect(rarityFor(brand: {'rarete': 5}), Rarity.legendaire);
    expect(rarityFor(brand: {'rarete': 1}, model: {'production_years': '1965 - 1972'}), Rarity.peuCommune);
  });
}
