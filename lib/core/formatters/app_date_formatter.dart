import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Centralized Date Formatter enforcing DD/MM/YYYY across Benchmark MMS
class AppDateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final DateFormat _dbIsoFormat = DateFormat('yyyy-MM-dd');

  /// Displays date strictly as DD/MM/YYYY
  /// Example: DateTime(2026, 9, 30) -> "30/09/2026"
  static String format(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date.toLocal();
    } else if (date is String) {
      if (date.trim().isEmpty) return '-';
      try {
        dt = DateTime.parse(date.trim()).toLocal();
      } catch (_) {
        return date;
      }
    } else {
      return '-';
    }
    return _dateFormat.format(dt);
  }

  /// Displays time as 12-hour hh:mm AM/PM (e.g. 09:15 AM, 02:30 PM)
  static String formatTime(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date.toLocal();
    } else if (date is TimeOfDay) {
      final now = DateTime.now();
      dt = DateTime(now.year, now.month, now.day, date.hour, date.minute);
    } else if (date is String) {
      if (date.trim().isEmpty) return '-';
      try {
        dt = DateTime.parse(date.trim()).toLocal();
      } catch (_) {
        // If it was a time string like "09:15:00" or "09:15"
        try {
          final parts = date.trim().split(':');
          if (parts.length >= 2) {
            final now = DateTime.now();
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1].split(' ')[0]);
            dt = DateTime(now.year, now.month, now.day, hour, minute);
          } else {
            return date;
          }
        } catch (_) {
          return date;
        }
      }
    } else {
      return '-';
    }
    return _timeFormat.format(dt);
  }

  /// Displays date and time as DD/MM/YYYY hh:mm a
  static String formatWithTime(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is DateTime) {
      dt = date.toLocal();
    } else if (date is String) {
      if (date.trim().isEmpty) return '-';
      try {
        dt = DateTime.parse(date.trim()).toLocal();
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

  /// Computes Day of Year (1..366) and formats strictly as a 3-digit padded string (e.g. 001, 005, 365, 366).
  /// Strictly based on the calendar date (day of the year), not day of the month.
  /// Example:
  ///   01/01/2026 -> 001
  ///   05/01/2026 -> 005
  ///   31/12/2026 -> 365
  ///   31/12/2028 (leap year) -> 366
  static String formatDayOfYearLot(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final startOfYear = DateTime.utc(date.year, 1, 1);
    final dayOfYear = d.difference(startOfYear).inDays + 1;
    return dayOfYear.toString().padLeft(3, '0');
  }

  /// Computes integer Day of Year (1..366).
  static int getDayOfYear(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final startOfYear = DateTime.utc(date.year, 1, 1);
    return d.difference(startOfYear).inDays + 1;
  }
}
