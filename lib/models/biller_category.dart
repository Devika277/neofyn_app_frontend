// lib/features/bbps/models/biller_category.dart

class BillerCategory {
  final String code;
  final String description;

  BillerCategory({
    required this.code,
    required this.description,
  });

  factory BillerCategory.fromJson(Map<String, dynamic> json) {
    return BillerCategory(
      code: json['Code'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Code': code,
      'description': description,
    };
  }
}