// lib/features/bbps/models/biller.dart

class Biller {
  final String code;
  final String description;

  Biller({
    required this.code,
    required this.description,
  });

  factory Biller.fromJson(Map<String, dynamic> json) {
    return Biller(
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