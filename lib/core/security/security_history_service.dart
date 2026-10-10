import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'security_finding_model.dart';

class SecurityHistoryService {
  static const String _reportsKey = 'mms_security_audit_reports_history_v1';
  static const String _logsKey = 'mms_security_audit_logs_history_v1';

  /// Saves an audit report to historical persistence
  Future<void> saveReport(SecurityAuditReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingReports = await loadReports();

      // Keep latest 25 audits to optimize storage
      final updatedList = [report, ...existingReports.where((r) => r.id != report.id)].take(25).toList();

      final encoded = jsonEncode(updatedList.map((r) => r.toJson()).toList());
      await prefs.setString(_reportsKey, encoded);
    } catch (e) {
      debugPrint('Failed to save security audit report: $e');
    }
  }

  /// Loads all saved audit reports
  Future<List<SecurityAuditReport>> loadReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reportsKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((json) => SecurityAuditReport.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Failed to load security audit reports: $e');
      return [];
    }
  }

  /// Saves a change log entry (backup before fix)
  Future<void> saveAuditLog(SecurityAuditLog log) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = await loadAuditLogs();

      final updatedList = [log, ...existingLogs.where((l) => l.id != log.id)].take(50).toList();

      final encoded = jsonEncode(updatedList.map((l) => l.toJson()).toList());
      await prefs.setString(_logsKey, encoded);
    } catch (e) {
      debugPrint('Failed to save security audit log: $e');
    }
  }

  /// Loads all change log entries
  Future<List<SecurityAuditLog>> loadAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_logsKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((json) => SecurityAuditLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Failed to load security audit logs: $e');
      return [];
    }
  }
}
