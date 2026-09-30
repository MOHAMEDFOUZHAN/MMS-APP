class CategoryLocationModel {
  final int id;
  final String category;
  final String location;
  final DateTime? lastUpdated;

  CategoryLocationModel({
    required this.id,
    required this.category,
    this.location = '',
    this.lastUpdated,
  });

  factory CategoryLocationModel.fromJson(Map<String, dynamic> json) {
    return CategoryLocationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      lastUpdated: json['last_updated'] != null ? DateTime.tryParse(json['last_updated'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'location': location,
    };
  }
}
