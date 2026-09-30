import 'package:intl/intl.dart';

/// Centralized Date Formatter enforcing DD/MM/YYYY across Benchmark MMS
class AppDateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final DateFormat _dbIsoFormat = DateFormat('yyyy-MM-dd');

  /// Displays date strictly as DD/MM/YYYY
  /// Example: DateTime(2026, 9, 30) -> "30/09/2026"
  static String format(dynamic date) {
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
    return _dateFormat.format(dt);
  }

  /// Displays date and time as DD/MM/YYYY hh:mm a
  static String formatWithTime(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      if (date.trim().isEmpty) return '-';
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return date;
      }
    } else {
      return '-';
    }
    return _dateTimeFormat.format(dt);
  }

  /// Converts DateTime to database-safe ISO date string (YYYY-MM-DD) for queries
  static String toDbDate(DateTime dt) {
    return _dbIsoFormat.format(dt);
  }

  /// Converts inclusive start of day for queries
  static DateTime startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, 0, 0, 0, 0, 0);
  }

  /// Converts inclusive end of day for queries
  static DateTime endOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999, 999);
  }

  /// Try parsing from DD/MM/YYYY user input or ISO string
  static DateTime? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();
    try {
      if (trimmed.contains('/')) {
        return _dateFormat.parseStrict(trimmed);
      }
      return DateTime.parse(trimmed);
    } catch (_) {
      return null;
    }
  }
}
