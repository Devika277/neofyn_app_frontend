// lib/models/dmt_models.dart

class Remitter {
  final int id;
  final String mobile;
  final String firstName;
  final String lastName;
  final double monthlyLimit;
  final double monthlyUsed;
  final String productType;
  final bool isActive;
  final String kycStatus;

  Remitter({
    required this.id,
    required this.mobile,
    required this.firstName,
    required this.lastName,
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.productType,
    required this.isActive,
    required this.kycStatus,
  });

  factory Remitter.fromJson(Map<String, dynamic> json) {
    return Remitter(
      id: json['id'] ?? 0,
      mobile: json['mobile']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      monthlyLimit: _parseDouble(json['monthly_limit']),
      monthlyUsed: _parseDouble(json['monthly_used']),
      productType: json['product_type']?.toString() ?? 'lite',
      isActive: json['is_active'] ?? false,
      kycStatus: json['kyc_status']?.toString() ?? 'basic',
    );
  }

  // Safe double parsing helper
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  double get remainingLimit => monthlyLimit - monthlyUsed;
  double get usagePercentage {
    if (monthlyLimit <= 0) return 0;
    return (monthlyUsed / monthlyLimit) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'first_name': firstName,
      'last_name': lastName,
      'monthly_limit': monthlyLimit,
      'monthly_used': monthlyUsed,
      'product_type': productType,
      'is_active': isActive,
      'kyc_status': kycStatus,
    };
  }
}

class Beneficiary {
  final int id;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String? beneficiaryMobile;
  final bool verified;
  final int useCount;
  final String? stateCode;  // ADDED
  final String? stateName;  // ADDED
  final String? bankCode;   // ADDED
  final String? cityCode;   // ADDED

  Beneficiary({
    required this.id,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.beneficiaryMobile,
    required this.verified,
    required this.useCount,
    this.stateCode,
    this.stateName,
    this.bankCode,
    this.cityCode,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] ?? 0,
      accountHolderName: json['account_holder_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      beneficiaryMobile: json['beneficiary_mobile']?.toString(),
      verified: json['verified'] ?? false,
      useCount: json['use_count'] ?? 0,
      stateCode: json['state_code']?.toString(),    // ADDED
      stateName: json['state_name']?.toString(),    // ADDED
      bankCode: json['bank_code']?.toString() ?? json['vimopay_bank_code']?.toString(),  // ADDED
      cityCode: json['city_code']?.toString(),      // ADDED
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'beneficiary_mobile': beneficiaryMobile,
      'verified': verified,
      'use_count': useCount,
      'state_code': stateCode,      // ✅ ADDED
      'state_name': stateName,      // ✅ ADDED
      'bank_code': bankCode,        // ✅ ADDED
      'city_code': cityCode,        // ✅ ADDED
    };
  }
}

class DMTTransaction {
  final int id;
  final double amount;
  final String status;
  final String? utrNumber;
  final String transferMode;
  final String createdAt;
  final String remitterName;
  final String beneficiaryName;
  final double? commissionAmount;

  DMTTransaction({
    required this.id,
    required this.amount,
    required this.status,
    this.utrNumber,
    required this.transferMode,
    required this.createdAt,
    required this.remitterName,
    required this.beneficiaryName,
    this.commissionAmount,
  });

  factory DMTTransaction.fromJson(Map<String, dynamic> json) {
    return DMTTransaction(
      id: json['id'] ?? 0,
      amount: _parseDouble(json['amount']),
      status: json['status']?.toString() ?? 'pending',
      utrNumber: json['utr_number']?.toString(),
      transferMode: json['transfer_mode']?.toString() ?? 'IMPS',
      createdAt: json['created_at']?.toString() ?? '',
      remitterName: json['remitter_name']?.toString() ?? '',
      beneficiaryName: json['beneficiary_name']?.toString() ?? '',
      commissionAmount: json['commission_amount'] != null
          ? _parseDouble(json['commission_amount'])
          : null,
    );
  }

  // Safe double parsing helper
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'status': status,
      'utr_number': utrNumber,
      'transfer_mode': transferMode,
      'created_at': createdAt,
      'remitter_name': remitterName,
      'beneficiary_name': beneficiaryName,
      'commission_amount': commissionAmount,
    };
  }
}

class DMTTransferRequest {
  final int remitterId;
  final int beneficiaryId;
  final double amount;
  final String tpin;
  final String transferMode;
  final String? remark;
  final String? stateCode; // ADD THIS

  DMTTransferRequest({
    required this.remitterId,
    required this.beneficiaryId,
    required this.amount,
    required this.tpin,
    this.transferMode = 'IMPS',
    this.remark,
    this.stateCode,
  });

  Map<String, dynamic> toJson() => {
    'remitterId': remitterId,
    'beneficiaryId': beneficiaryId,
    'amount': amount,
    'tpin': tpin,
    'transferMode': transferMode,
    'remark': remark,
    'state_code': stateCode, // ADD THIS
  };
}