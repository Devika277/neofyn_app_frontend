



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
      mobile: json['mobile'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      monthlyLimit: (json['monthly_limit'] ?? 0).toDouble(),
      monthlyUsed: (json['monthly_used'] ?? 0).toDouble(),
      productType: json['product_type'] ?? 'lite',
      isActive: json['is_active'] ?? false,
      kycStatus: json['kyc_status'] ?? 'basic',
    );
  }

  double get remainingLimit => monthlyLimit - monthlyUsed;
  double get usagePercentage => (monthlyUsed / monthlyLimit) * 100;
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

  Beneficiary({
    required this.id,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.beneficiaryMobile,
    required this.verified,
    required this.useCount,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] ?? 0,
      accountHolderName: json['account_holder_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'] ?? '',
      bankName: json['bank_name'] ?? '',
      beneficiaryMobile: json['beneficiary_mobile'],
      verified: json['verified'] ?? false,
      useCount: json['use_count'] ?? 0,
    );
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
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      utrNumber: json['utr_number'],
      transferMode: json['transfer_mode'] ?? 'IMPS',
      createdAt: json['created_at'] ?? '',
      remitterName: json['remitter_name'] ?? '',
      beneficiaryName: json['beneficiary_name'] ?? '',
      commissionAmount: json['commission_amount']?.toDouble(),
    );
  }
}

class DMTTransferRequest {
  final int remitterId;
  final int beneficiaryId;
  final double amount;
  final String tpin;
  final String transferMode;
  final String? remark;

  DMTTransferRequest({
    required this.remitterId,
    required this.beneficiaryId,
    required this.amount,
    required this.tpin,
    this.transferMode = 'IMPS',
    this.remark,
  });

  Map<String, dynamic> toJson() => {
    'remitterId': remitterId,
    'beneficiaryId': beneficiaryId,
    'amount': amount,
    'tpin': tpin,
    'transferMode': transferMode,
    'remark': remark,
  };
}