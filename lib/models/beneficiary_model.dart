// models/beneficiary_model.dart

class Beneficiary {
  final int? id;
  final String name;
  final String accountNumber;
  final String ifsc;
  final String mobile;
  final String bankCode;
  final String bankName;
  // final String purposeCode;
  // final String purposeDesc;
  final String stateCode;
  final String stateName;
  final String paymentMode;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime? beneAddedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  Beneficiary({
    this.id,
    required this.name,
    required this.accountNumber,
    required this.ifsc,
    required this.mobile,
    required this.bankCode,
    required this.bankName,
    // required this.purposeCode,
    // required this.purposeDesc,
    required this.stateCode,
    required this.stateName,
    this.paymentMode = 'IMPS',
    this.isVerified = false,
    this.verifiedAt,
    this.beneAddedAt,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'],
      name: json['account_name'] ?? json['name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifsc: json['ifsc_code'] ?? json['ifsc'] ?? '',
      mobile: json['mobile_number'] ?? json['mobile'] ?? '',
      bankCode: json['bank_code'] ?? '',
      bankName: json['bank_name'] ?? '',
      // purposeCode: json['purpose_code'] ?? '',
      // purposeDesc: json['purpose_desc'] ?? '',
      stateCode: json['state_code'] ?? '',
      stateName: json['state_name'] ?? '',
      paymentMode: json['payment_mode'] ?? 'IMPS',
      isVerified: json['is_verified'] ?? false,
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      beneAddedAt: json['bene_added_at'] != null ? DateTime.parse(json['bene_added_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isActive: json['is_active'] ?? true,
    );
  }

  // This matches what the backend addBeneficiary expects
  Map<String, dynamic> toBackendJson() {
    return {
      'account_name': name,
      'account_number': accountNumber,
      'ifsc_code': ifsc,
      'upi_id': null, // Not used for bank
      'bene_type': 'bank',
    };
  }

  Beneficiary copyWith({
    int? id,
    String? name,
    String? accountNumber,
    String? ifsc,
    String? mobile,
    String? bankCode,
    String? bankName,
    // String? purposeCode,
    // String? purposeDesc,
    String? stateCode,
    String? stateName,
    String? paymentMode,
    bool? isVerified,
    DateTime? verifiedAt,
    DateTime? beneAddedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Beneficiary(
      id: id ?? this.id,
      name: name ?? this.name,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      mobile: mobile ?? this.mobile,
      bankCode: bankCode ?? this.bankCode,
      bankName: bankName ?? this.bankName,
      // purposeCode: purposeCode ?? this.purposeCode,
      // purposeDesc: purposeDesc ?? this.purposeDesc,
      stateCode: stateCode ?? this.stateCode,
      stateName: stateName ?? this.stateName,
      paymentMode: paymentMode ?? this.paymentMode,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      beneAddedAt: beneAddedAt ?? this.beneAddedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}