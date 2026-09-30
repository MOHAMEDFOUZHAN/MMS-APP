class VendorModel {
  final int id;
  final String name;
  final String contact;
  final String place;
  final String pincode;
  final String gstin;
  final String material;
  final String info;
  final DateTime? createdAt;

  VendorModel({
    required this.id,
    required this.name,
    this.contact = '',
    this.place = '',
    this.pincode = '',
    this.gstin = '',
    this.material = '',
    this.info = '',
    this.createdAt,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      info: json['info']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'place': place,
      'pincode': pincode,
      'gstin': gstin,
      'material': material,
      'info': info,
    };
  }
}
