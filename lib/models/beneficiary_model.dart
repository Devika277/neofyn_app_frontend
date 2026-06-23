// models/beneficiary_model.dart

class Beneficiary {
  final int? id;
  final String name;
  final String accountNumber;
  final String ifsc;
  final String mobile;
  final String bankCode;
  final String bankName;
  final String stateCode;
  final String stateName;
  final String paymentMode;
  final bool isVerified;
  final bool isPrimary;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Beneficiary({
    this.id,
    required this.name,
    required this.accountNumber,
    required this.ifsc,
    required this.mobile,
    required this.bankCode,
    required this.bankName,
    required this.stateCode,
    required this.stateName,
    this.paymentMode = 'IMPS',
    this.isVerified = false,
    this.isPrimary = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      name: json['account_name'] ?? json['name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifsc: json['ifsc_code'] ?? json['ifsc'] ?? '',
      mobile: json['mobile_number'] ?? json['mobile'] ?? '',
      bankCode: json['vimopay_bank_code'] ?? json['bank_code'] ?? '',
      bankName: json['bank_name'] ?? '',
      stateCode: json['state_code'] ?? '',
      stateName: json['state_name'] ?? '',
      paymentMode: json['payment_mode'] ?? 'IMPS',
      isVerified: json['is_verified'] ?? false,
      isPrimary: json['is_primary'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_name': name,
      'account_number': accountNumber,
      'ifsc_code': ifsc,
      'mobile_number': mobile,
      'bank_name': bankName,
      'state_code': stateCode,
      'payment_mode': paymentMode,
      'is_primary': isPrimary,
      'is_active': isActive,
    };
  }
}