import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum SecuritySeverity {
  critical,
  high,
  medium,
  low,
  info,
}

enum SecurityCategory {
  apiKeys,
  rls,
  database,
  functions,
  storage,
  auth,
  inventory,
  dangerousOps,
  realtime,
  roles,
}

enum FixType {
  safeAutoFix,
  reviewSql,
  manualConfiguration,
}

enum SecurityAuditStatus {
  notScanned,
  secure,
  issuesFound,
  criticalIssuesFound,
}

class SecurityFinding {
  final String id;
  final SecuritySeverity severity;
  final SecurityCategory category;
  final String title;
  final String affectedComponent;
  final String whyItMatters;
  final String currentState;
  final String recommendedFix;
  final String risk;
  final FixType fixType;
  final String? fixSql;
  bool isFixed;
  DateTime? fixedAt;
  String? fixVerificationStatus; // 'VERIFIED' | 'FAILED' | null

  SecurityFinding({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.affectedComponent,
    required this.whyItMatters,
    required this.currentState,
    required this.recommendedFix,
    required this.risk,
    required this.fixType,
    this.fixSql,
    this.isFixed = false,
    this.fixedAt,
    this.fixVerificationStatus,
  });

  bool get isSafeAutoFix => fixType == FixType.safeAutoFix;

  Map<String, dynamic> toJson() => {
        'id': id,
        'severity': severity.name,
        'category': category.name,
        'title': title,
        'affectedComponent': affectedComponent,
        'whyItMatters': whyItMatters,
        'currentState': currentState,
        'recommendedFix': recommendedFix,
        'risk': risk,
        'fixType': fixType.name,
        'fixSql': fixSql,
        'isFixed': isFixed,
        'fixedAt': fixedAt?.toIso8601String(),
        'fixVerificationStatus': fixVerificationStatus,
      };

  factory SecurityFinding.fromJson(Map<String, dynamic> json) => SecurityFinding(
        id: json['id'] as String,
        severity: SecuritySeverity.values.firstWhere(
          (e) => e.name == json['severity'],
          orElse: () => SecuritySeverity.info,
        ),
        category: SecurityCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => SecurityCategory.database,
        ),
        title: json['title'] as String,
        affectedComponent: json['affectedComponent'] as String,
        whyItMatters: json['whyItMatters'] as String,
        currentState: json['currentState'] as String,
        recommendedFix: json['recommendedFix'] as String,
        risk: json['risk'] as String,
        fixType: FixType.values.firstWhere(
          (e) => e.name == json['fixType'],
          orElse: () => FixType.reviewSql,
        ),
        fixSql: json['fixSql'] as String?,
        isFixed: json['isFixed'] as bool? ?? false,
        fixedAt: json['fixedAt'] != null ? DateTime.tryParse(json['fixedAt'] as String) : null,
        fixVerificationStatus: json['fixVerificationStatus'] as String?,
      );

  Color get severityColor {
    switch (severity) {
      case SecuritySeverity.critical:
        return const Color(0xFFEF4444); // Neon Red
      case SecuritySeverity.high:
        return const Color(0xFFF97316); // Neon Orange
      case SecuritySeverity.medium:
        return const Color(0xFFFBBF24); // Neon Amber
      case SecuritySeverity.low:
        return const Color(0xFF38BDF8); // Neon Cyan / Sky
      case SecuritySeverity.info:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String get severityLabel {
    switch (severity) {
      case SecuritySeverity.critical:
        return 'CRITICAL';
      case SecuritySeverity.high:
        return 'HIGH';
      case SecuritySeverity.medium:
        return 'MEDIUM';
      case SecuritySeverity.low:
        return 'LOW';
      case SecuritySeverity.info:
        return 'INFO';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case SecurityCategory.apiKeys:
        return Icons.vpn_key_rounded;
      case SecurityCategory.rls:
        return Icons.policy_rounded;
      case SecurityCategory.database:
        return Icons.storage_rounded;
      case SecurityCategory.functions:
        return Icons.functions_rounded;
      case SecurityCategory.storage:
        return Icons.folder_special_rounded;
      case SecurityCategory.auth:
        return Icons.lock_person_rounded;
      case SecurityCategory.inventory:
        return Icons.inventory_2_rounded;
      case SecurityCategory.dangerousOps:
        return Icons.warning_amber_rounded;
      case SecurityCategory.realtime:
        return Icons.sensors_rounded;
      case SecurityCategory.roles:
        return Icons.admin_panel_settings_rounded;
    }
  }

  String get categoryLabel {
    switch (category) {
      case SecurityCategory.apiKeys:
        return 'API Keys & Secrets';
      case SecurityCategory.rls:
        return 'Row Level Security';
      case SecurityCategory.database:
        return 'Database Tables';
      case SecurityCategory.functions:
        return 'PostgreSQL Functions';
      case SecurityCategory.storage:
        return 'Storage Buckets';
      case SecurityCategory.auth:
        return 'Authentication';
      case SecurityCategory.inventory:
        return 'Inventory Rules';
      case SecurityCategory.dangerousOps:
        return 'Dangerous Operations';
      case SecurityCategory.realtime:
        return 'Realtime Subscriptions';
      case SecurityCategory.roles:
        return 'Roles & Authorization';
    }
  }

  /// Masks sensitive strings (e.g. `sb_publishable_mFHcuug...` -> `sb_publishable_••••••••••••••c5Q_HIoCGFVa`)
  /// Never displays raw passwords or service role secrets.
  static String maskSecret(String? secret, {bool isServiceRole = false}) {
    if (secret == null || secret.isEmpty) return 'NOT SET';
    if (isServiceRole || secret.toLowerCase().contains('service_role') || secret.length > 80) {
      return 'SECRET DETECTED — VALUE HIDDEN';
    }
    if (secret.length <= 8) return '••••••••';
    final prefix = secret.startsWith('sb_publishable_')
        ? 'sb_publishable_'
        : secret.substring(0, secret.length >= 15 ? 15 : 3);
    final suffix = secret.substring(secret.length - 4);
    return '$prefix••••••••••••••$suffix';
  }
}

class SecurityAuditReport {
  final String id;
  final DateTime timestamp;
  final int securityScore;
  final SecurityAuditStatus status;
  final int totalChecks;
  final List<SecurityFinding> findings;
  final String summary;

  SecurityAuditReport({
    required this.id,
    required this.timestamp,
    required this.securityScore,
    required this.status,
    required this.totalChecks,
    required this.findings,
    required this.summary,
  });

  int get criticalCount => findings.where((f) => f.severity == SecuritySeverity.critical && !f.isFixed).length;
  int get highCount => findings.where((f) => f.severity == SecuritySeverity.high && !f.isFixed).length;
  int get mediumCount => findings.where((f) => f.severity == SecuritySeverity.medium && !f.isFixed).length;
  int get lowCount => findings.where((f) => f.severity == SecuritySeverity.low && !f.isFixed).length;
  int get infoCount => findings.where((f) => f.severity == SecuritySeverity.info && !f.isFixed).length;
  int get fixedCount => findings.where((f) => f.isFixed).length;

  Color get statusColor {
    switch (status) {
      case SecurityAuditStatus.notScanned:
        return AppColors.textMuted;
      case SecurityAuditStatus.secure:
        return const Color(0xFF10B981);
      case SecurityAuditStatus.issuesFound:
        return const Color(0xFFF59E0B);
      case SecurityAuditStatus.criticalIssuesFound:
        return const Color(0xFFEF4444);
    }
  }

  String get statusLabel {
    switch (status) {
      case SecurityAuditStatus.notScanned:
        return 'Not Scanned';
      case SecurityAuditStatus.secure:
        return 'Audit Clean';
      case SecurityAuditStatus.issuesFound:
        return 'Issues Found';
      case SecurityAuditStatus.criticalIssuesFound:
        return 'Critical Issues Found';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'securityScore': securityScore,
        'status': status.name,
        'totalChecks': totalChecks,
        'findings': findings.map((f) => f.toJson()).toList(),
        'summary': summary,
      };

  factory SecurityAuditReport.fromJson(Map<String, dynamic> json) => SecurityAuditReport(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        securityScore: (json['securityScore'] as num).toInt(),
        status: SecurityAuditStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => SecurityAuditStatus.issuesFound,
        ),
        totalChecks: (json['totalChecks'] as num?)?.toInt() ?? 23,
        findings: (json['findings'] as List<dynamic>?)
                ?.map((item) => SecurityFinding.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [],
        summary: json['summary'] as String? ?? '',
      );
}

class SecurityAuditLog {
  final String id;
  final DateTime timestamp;
  final String affectedObject;
  final String previousConfiguration;
  final String proposedConfiguration;
  final String actionTaken;
  final String administrator;
  final String status;

  SecurityAuditLog({
    required this.id,
    required this.timestamp,
    required this.affectedObject,
    required this.previousConfiguration,
    required this.proposedConfiguration,
    required this.actionTaken,
    required this.administrator,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'affectedObject': affectedObject,
        'previousConfiguration': previousConfiguration,
        'proposedConfiguration': proposedConfiguration,
        'actionTaken': actionTaken,
        'administrator': administrator,
        'status': status,
      };

  factory SecurityAuditLog.fromJson(Map<String, dynamic> json) => SecurityAuditLog(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        affectedObject: json['affectedObject'] as String,
        previousConfiguration: json['previousConfiguration'] as String,
        proposedConfiguration: json['proposedConfiguration'] as String,
        actionTaken: json['actionTaken'] as String,
        administrator: json['administrator'] as String,
        status: json['status'] as String,
      );
}
