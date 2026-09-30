class UserProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String role; // 'ADMIN', 'MANAGER', 'STAFF', 'VIEWER'
  final List<String> permissions;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.role = 'STAFF',
    this.permissions = const [],
    this.deviceId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isManager => role.toUpperCase() == 'MANAGER' || isAdmin;

  bool hasPermission(String perm) {
    if (isAdmin) return true;
    if (permissions.contains('*') || permissions.contains(perm)) return true;
    final prefix = perm.split('.').first;
    if (permissions.contains('$prefix.*')) return true;
    return false;
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    if (json['permissions'] is List) {
      perms = (json['permissions'] as List).map((e) => e.toString()).toList();
    }

    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'user',
      fullName: json['full_name']?.toString() ?? 'User',
      role: json['role']?.toString() ?? 'STAFF',
      permissions: perms,
      deviceId: json['device_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role,
        'permissions': permissions,
        'device_id': deviceId,
      };
}
