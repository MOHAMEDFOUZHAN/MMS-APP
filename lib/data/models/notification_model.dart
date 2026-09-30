class NotificationModel {
  final int id;
  final String? userId;
  final String type; // 'reorder', 'out_of_stock', 'low_stock', 'expiring', 'expired', 'system'
  final String title;
  final String message;
  final String severity; // 'INFO', 'WARNING', 'CRITICAL'
  final String? referenceType; // 'material', 'batch', 'invoice', 'transfer', 'dispatch'
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const NotificationModel({
    required this.id,
    this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isWarning => severity.toUpperCase() == 'WARNING';
  bool get isInfo => severity.toUpperCase() == 'INFO';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString(),
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'INFO',
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'severity': severity,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}
