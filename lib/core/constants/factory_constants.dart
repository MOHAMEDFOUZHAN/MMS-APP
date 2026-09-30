class UomItem {
  final String code;
  final String label;
  final String symbol;

  const UomItem({
    required this.code,
    required this.label,
    required this.symbol,
  });

  String get displayName => '$label ($symbol)';
}

class GradeItem {
  final String code;
  final String name;

  const GradeItem({
    required this.code,
    required this.name,
  });

  String get displayName => '$code — $name';
}

class FactoryConstants {
  static const String appName = 'demo';
  static const String appVersion = 'v3.0 (Supabase Edition)';

  // Factory Departments
  static const List<String> departments = [
    'Tea',
    'Chocolate',
    'Kitchen',
    'General',
    'Packaging',
    'Store Bay',
  ];

  // --------------------------------------------------------------------------
  // CENTRALIZED 16 UOM MASTER LIST (From Benchmark MMS UOM Reference)
  // --------------------------------------------------------------------------
  static const List<UomItem> uomList = [
    UomItem(code: 'kg', label: 'Kilogram', symbol: 'kg'),
    UomItem(code: 'grams', label: 'Grams', symbol: 'g'),
    UomItem(code: 'litre', label: 'Litre', symbol: 'L'),
    UomItem(code: 'ml', label: 'Millilitre', symbol: 'ml'),
    UomItem(code: 'pcs', label: 'Pieces', symbol: 'pcs'),
    UomItem(code: 'box', label: 'Box', symbol: 'box'),
    UomItem(code: 'carton', label: 'Carton', symbol: 'carton'),
    UomItem(code: 'bags', label: 'Bags', symbol: 'bags'),
    UomItem(code: 'bottle', label: 'Bottle', symbol: 'bottle'),
    UomItem(code: 'packet', label: 'Packet', symbol: 'packet'),
    UomItem(code: 'tin', label: 'Tin', symbol: 'tin'),
    UomItem(code: 'can', label: 'Can', symbol: 'can'),
    UomItem(code: 'bundle', label: 'Bundle', symbol: 'bundle'),
    UomItem(code: 'roll', label: 'Roll', symbol: 'roll'),
    UomItem(code: 'sheet', label: 'Sheet', symbol: 'sheet'),
    UomItem(code: 'meter', label: 'Meter', symbol: 'm'),
  ];

  // List of UOM codes for quick lookup and backward compatibility
  static List<String> get units => uomList.map((u) => u.code).toList();
  static List<String> get standardUnits => units;

  static String getUomDisplay(String? code) {
    if (code == null || code.trim().isEmpty) return 'kg';
    final normalized = code.trim().toLowerCase();
    for (final item in uomList) {
      if (item.code.toLowerCase() == normalized || item.symbol.toLowerCase() == normalized) {
        return item.displayName;
      }
    }
    return code; // Fallback to raw code if custom
  }

  static String normalizeUomCode(String? input) {
    if (input == null || input.trim().isEmpty) return 'kg';
    final trimmed = input.trim().toLowerCase();
    for (final item in uomList) {
      if (item.code.toLowerCase() == trimmed ||
          item.symbol.toLowerCase() == trimmed ||
          item.label.toLowerCase() == trimmed) {
        return item.code;
      }
    }
    return input.trim();
  }

  // --------------------------------------------------------------------------
  // CENTRALIZED 16 FACTORY TEA GRADES (From Benchmark MMS Reference)
  // --------------------------------------------------------------------------
  static const List<GradeItem> gradeList = [
    GradeItem(code: 'BP', name: 'Broken Pekoe'),
    GradeItem(code: 'BOP', name: 'Broken Orange Pekoe'),
    GradeItem(code: 'RD', name: 'Red Dust'),
    GradeItem(code: 'SRD', name: 'Super Red Dust'),
    GradeItem(code: 'PD', name: 'Pekoe Dust'),
    GradeItem(code: 'BOPL', name: 'Broken Orange Pekoe Large'),
    GradeItem(code: 'BOPS', name: 'Broken Orange Pekoe Small'),
    GradeItem(code: 'BOPSM', name: 'Broken Orange Pekoe Small Mixed'),
    GradeItem(code: 'PF', name: 'Pekoe Fannings'),
    GradeItem(code: 'DUST', name: 'Dust'),
    GradeItem(code: 'SOPL', name: 'Semi Orange Pekoe Large'),
    GradeItem(code: 'BOPF', name: 'Broken Orange Pekoe Fannings'),
    GradeItem(code: 'MONGRAI', name: 'Mongrai'),
    GradeItem(code: 'MASHDANA', name: 'Mashdana'),
    GradeItem(code: 'OPAL', name: 'Opal'),
    GradeItem(code: 'SBOP', name: 'Small Broken Orange Pekoe'),
  ];

  static List<String> get grades => gradeList.map((g) => g.code).toList();

  static String getGradeDisplay(String? code) {
    if (code == null || code.trim().isEmpty) return 'STANDARD';
    final normalized = code.trim().toUpperCase();
    for (final item in gradeList) {
      if (item.code.toUpperCase() == normalized) {
        return item.displayName;
      }
    }
    return code;
  }

  static String normalizeGradeCode(String? input) {
    if (input == null || input.trim().isEmpty) return 'BP';
    final upper = input.trim().toUpperCase();
    for (final item in gradeList) {
      if (item.code.toUpperCase() == upper) {
        return item.code;
      }
    }
    return input.trim();
  }

  // GST Percentages standard in India
  static const List<double> gstRates = [
    0.0,
    5.0,
    12.0,
    18.0,
    28.0,
  ];

  // Security default PINs (Overridable via system_settings)
  static const String defaultStockAdjustmentPin = '1234';
  static const String defaultNewMaterialPin = '1234';
  static const String defaultAdminPin = '9999';
}
