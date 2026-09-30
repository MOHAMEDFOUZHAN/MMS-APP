import 'package:intl/intl.dart';

class QuantityFormatter {
  /// Format storage & live inventory quantity into dual unit display
  /// Example: 40.05 kg -> "40 kg 50 g"
  /// Example: 100.5 litre -> "100 Litre 500 ml"
  static String formatDualUnit(num quantity, String unit) {
    final qty = quantity.toDouble();
    final lowerUnit = unit.toLowerCase().trim();

    if (lowerUnit == 'kg') {
      final mainPart = qty.toInt();
      final subPart = ((qty - mainPart) * 1000).round();

      if (mainPart == 0 && subPart > 0) {
        return '$subPart g';
      } else if (subPart > 0) {
        return '$mainPart kg $subPart g';
      } else {
        return '$mainPart kg';
      }
    } else if (lowerUnit == 'litre' || lowerUnit == 'liter' || lowerUnit == 'l') {
      final mainPart = qty.toInt();
      final subPart = ((qty - mainPart) * 1000).round();

      if (mainPart == 0 && subPart > 0) {
        return '$subPart ml';
      } else if (subPart > 0) {
        return '$mainPart Litre $subPart ml';
      } else {
        return '$mainPart Litre';
      }
    } else {
      // Discrete units: pcs, box, roll, meters, bundle
      if (qty % 1 == 0) {
        return '${qty.toInt()} $unit';
      } else {
        return '${qty.toStringAsFixed(3)} $unit';
      }
    }
  }

  /// Formats quantity with strict 3-decimal precision
  static String format3Decimals(num quantity) {
    return quantity.toDouble().toStringAsFixed(3);
  }

  /// Clean display without trailing zeros if whole
  static String formatClean(num quantity) {
    final d = quantity.toDouble();
    if (d % 1 == 0) {
      return d.toInt().toString();
    }
    return d.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Indian currency format (e.g. ₹ 4,120.08)
  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Date formatting
  static String formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      if (date.trim().isEmpty) return '-';
      try {
        final clean = date.contains(' ') ? date.split(' ')[0] : date;
        dt = DateTime.parse(clean);
      } catch (_) {
        return date;
      }
    } else {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String formatDateTime(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return date;
      }
    } else {
      return '-';
    }
    return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
  }

  static String toIsoDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }
}
