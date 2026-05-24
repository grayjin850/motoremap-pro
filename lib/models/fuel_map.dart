import 'dart:convert';

enum CellStatus { safe, caution, danger, vvaZone }

class FuelMap {
  /// RPM axis — 12 points (1000 rpm steps from 1000 to 12000).
  static const List<int> rpmAxis = [
    1000, 2000, 3000, 4000, 5000, 6000,
    7000, 8000, 9000, 10000, 11000, 12000,
  ];

  /// TPS (throttle position) axis — 12 points in percent.
  static const List<int> tpsAxis = [
    0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100,
  ];

  /// AFR values indexed as [tpsIndex][rpmIndex] — 12x12 grid.
  final List<List<double>> values;

  const FuelMap({required this.values});

  factory FuelMap.fromJson(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    final values = decoded
        .map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
    return FuelMap(values: values);
  }

  String toJson() {
    return jsonEncode(values);
  }

  /// Get AFR value at a specific operating point.
  double getValue(int tpsIndex, int rpmIndex) {
    assert(tpsIndex >= 0 && tpsIndex < tpsAxis.length,
        'tpsIndex $tpsIndex out of range [0, ${tpsAxis.length - 1}]');
    assert(rpmIndex >= 0 && rpmIndex < rpmAxis.length,
        'rpmIndex $rpmIndex out of range [0, ${rpmAxis.length - 1}]');
    return values[tpsIndex][rpmIndex];
  }

  /// Determine cell safety status based on AFR value.
  ///
  /// Safe (green):   12.8 – 13.8
  /// Caution (yellow): approaching safe limits (12.0 – 12.8 or 13.8 – 14.7)
  /// Danger (red):   outside caution range (< 12.0 or > 14.7)
  CellStatus getCellStatus(int tpsIndex, int rpmIndex) {
    final afr = getValue(tpsIndex, rpmIndex);
    if (afr >= 12.8 && afr <= 13.8) return CellStatus.safe;
    if (afr >= 12.0 && afr <= 14.7) return CellStatus.caution;
    return CellStatus.danger;
  }

  /// Returns a default stoichiometric-ish 12x12 fuel map (AFR 13.0 across all cells).
  factory FuelMap.defaultMap() {
    final values = List.generate(
      tpsAxis.length,
      (_) => List.filled(rpmAxis.length, 13.0),
    );
    return FuelMap(values: values);
  }
}
