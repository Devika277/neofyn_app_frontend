// lib/models/cardpay_out_models.dart

// ========== REQUEST MODELS ==========

class CardPayOutBeneficiaryRequest {
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String? mobileNumber;
  final String? stateCode;
  final String? vimopayBankCode;

  CardPayOutBeneficiaryRequest({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.mobileNumber,
    this.stateCode,
    this.vimopayBankCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'mobile_number': mobileNumber,
      'state_code': stateCode,
      'vimopay_bank_code': vimopayBankCode,
    };
  }
}

class CardPayOutInitiateRequest {
  final double amount;
  final int beneficiaryId;
  final String mode; // IMPS or NEFT
  final String tpin;
  final String? remarks;
  final String lat;   // ✅ Added
  final String long;

  CardPayOutInitiateRequest({
    required this.amount,
    required this.beneficiaryId,
    required this.mode,
    required this.tpin,
    required this.lat,
    required this.long,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'beneficiaryId': beneficiaryId,
      'mode': mode,
      'tpin': tpin,
      'remarks': remarks ?? '',
      'lat': lat,    // ✅ Added
      'long': long,
    };
  }
}

// ========== RESPONSE MODELS ==========

class CardPayOutBeneficiary {
  final int id;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String? mobileNumber;
  final String? stateCode;
  final String? vimopayBankCode;
  final bool isVerified;
  final bool isActive;
  final String createdAt;

  CardPayOutBeneficiary({
    required this.id,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.mobileNumber,
    this.stateCode,
    this.vimopayBankCode,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
  });

  factory CardPayOutBeneficiary.fromJson(Map<String, dynamic> json) {
    return CardPayOutBeneficiary(
      id: _parseInt(json['id']),
      accountHolderName: json['account_holder_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'] ?? '',
      bankName: json['bank_name'] ?? '',
      mobileNumber: json['mobile_number']?.toString(),
      stateCode: json['state_code']?.toString(),
      vimopayBankCode: json['vimopay_bank_code']?.toString(),
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CardPayOutTransaction {
  final int id;
  final double amount;
  final String mode;
  final String status;
  final String? utr;
  final double charges;
  final String createdAt;
  final String? processedAt;
  final String merchantRefId;
  final String? failureReason;
  final String? accountHolderName;
  final String? accountNumber;

  CardPayOutTransaction({
    required this.id,
    required this.amount,
    required this.mode,
    required this.status,
    this.utr,
    required this.charges,
    required this.createdAt,
    this.processedAt,
    required this.merchantRefId,
    this.failureReason,
    this.accountHolderName,
    this.accountNumber,
  });

  factory CardPayOutTransaction.fromJson(Map<String, dynamic> json) {
    return CardPayOutTransaction(
      id: _parseInt(json['id']),
      amount: _parseDouble(json['amount']),
      mode: json['mode'] ?? 'IMPS',
      status: json['status'] ?? json['txn_status'] ?? 'pending',
      utr: json['utr']?.toString(),
      charges: _parseDouble(json['charges']),
      createdAt: json['created_at'] ?? '',
      processedAt: json['processed_at'],
      merchantRefId: json['merchant_ref_id'] ?? '',
      failureReason: json['failure_reason'],
      accountHolderName: json['account_holder_name'] ?? json['bene_account'],
      accountNumber: json['account_number']?.toString(),
    );
  }
}

class CardPayOutBalance {
  final double balance;

  CardPayOutBalance({required this.balance});

  factory CardPayOutBalance.fromJson(Map<String, dynamic> json) {
    return CardPayOutBalance(
      balance: _parseDouble(json['balance']),
    );
  }
}

class CardPayOutLimits {
  final double dailyUsed;
  final double dailyLimit;
  final double monthlyUsed;
  final double monthlyLimit;

  CardPayOutLimits({
    required this.dailyUsed,
    required this.dailyLimit,
    required this.monthlyUsed,
    required this.monthlyLimit,
  });

  factory CardPayOutLimits.fromJson(Map<String, dynamic> json) {
    return CardPayOutLimits(
      dailyUsed: _parseDouble(json['dailyUsed']),
      dailyLimit: _parseDouble(json['dailyLimit']),
      monthlyUsed: _parseDouble(json['monthlyUsed']),
      monthlyLimit: _parseDouble(json['monthlyLimit']),
    );
  }
}

class CardPayOutInitiateResponse {
  final int transactionId;
  final double amount;
  final String merchantRefId;
  final String? providerRefId;
  final String? bankRefNo;

  CardPayOutInitiateResponse({
    required this.transactionId,
    required this.amount,
    required this.merchantRefId,
    this.providerRefId,
    this.bankRefNo,
  });

  factory CardPayOutInitiateResponse.fromJson(Map<String, dynamic> json) {
    return CardPayOutInitiateResponse(
      transactionId: _parseInt(json['transactionId'] ?? json['transaction_id']),
      amount: _parseDouble(json['amount']),
      merchantRefId: json['merchantRefId'] ?? json['merchant_ref_id'] ?? '',
      providerRefId: json['providerRefId']?.toString(),
      bankRefNo: json['bankRefNo']?.toString(),
    );
  }
}

class CardPayOutStatus {
  final String status;
  final String? utr;
  final String? failureReason;
  final String updatedAt;

  CardPayOutStatus({
    required this.status,
    this.utr,
    this.failureReason,
    required this.updatedAt,
  });

  factory CardPayOutStatus.fromJson(Map<String, dynamic> json) {
    return CardPayOutStatus(
      status: json['txn_status'] ?? 'pending',
      utr: json['utr']?.toString(),
      failureReason: json['failure_reason'],
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

// ========== HELPER METHODS ==========

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
  return 0;
}