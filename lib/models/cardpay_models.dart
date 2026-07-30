// lib/models/cardpay_models.dart

// ========== REQUEST MODELS ==========

class CardPayInitiateRequest {
  final double amount;
  final String mobile;
  final String name;
  final String email;
  final String location;
  final String lat;
  final String long;
  final String? udf1;
  final String? udf2;
  final String? udf3;

  CardPayInitiateRequest({
    required this.amount,
    required this.mobile,
    required this.name,
    required this.email,
    required this.location,
    required this.lat,
    required this.long,
    this.udf1,
    this.udf2,
    this.udf3,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'mobile': mobile,
      'name': name,
      'email': email,
      'location': location,
      'lat': lat,
      'long': long,
      'udf1': udf1 ?? '',
      'udf2': udf2 ?? '',
      'udf3': udf3 ?? '',
    };
  }
}

// ========== RESPONSE MODELS ==========

class CardPayInitiateResponse {
  final String merchantRefId;
  final String paymentLink;
  final int txnId;

  CardPayInitiateResponse({
    required this.merchantRefId,
    required this.paymentLink,
    required this.txnId,
  });

  factory CardPayInitiateResponse.fromJson(Map<String, dynamic> json) {
    return CardPayInitiateResponse(
      merchantRefId: json['merchantRefId'] ?? '',
      paymentLink: json['paymentLink'] ?? '',
      txnId: _parseInt(json['txnId']),
    );
  }
}

class CardPayState {
  final String id;
  final String name;

  CardPayState({required this.id, required this.name});

  factory CardPayState.fromJson(Map<String, dynamic> json) {
    return CardPayState(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['state'] ?? json['stateName'] ?? '',
    );
  }
}

class CardPayTransaction {
  final int id;
  final String merchantRefId;
  final double amount;
  final String txnStatus;
  final String? txnStatusCode;
  final String? paymentLink;
  final String? cardHolderName;
  final String? cardLastFour;
  final String? cardNetwork;
  final String? rrn;
  final double? charges;
  final bool walletCredited;
  final String createdAt;
  final String? updatedAt;
  final String? customerName;
  final String? customerMobile;
  final String? customerEmail;
  final double? balanceBefore;
  final double? balanceAfter;

  CardPayTransaction({
    required this.id,
    required this.merchantRefId,
    required this.amount,
    required this.txnStatus,
    this.txnStatusCode,
    this.paymentLink,
    this.cardHolderName,
    this.cardLastFour,
    this.cardNetwork,
    this.rrn,
    this.charges,
    required this.walletCredited,
    required this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerMobile,
    this.customerEmail,
    this.balanceBefore,
    this.balanceAfter,
  });

  factory CardPayTransaction.fromJson(Map<String, dynamic> json) {
    return CardPayTransaction(
      id: _parseInt(json['id']),
      merchantRefId: json['merchant_ref_id'] ?? '',
      amount: _parseDouble(json['amount']),
      txnStatus: json['txn_status'] ?? 'pending',
      txnStatusCode: json['txn_status_code']?.toString(),
      paymentLink: json['payment_link'],
      cardHolderName: json['card_holder_name'],
      cardLastFour: json['card_last_four']?.toString(),
      cardNetwork: json['card_network']?.toString(),
      rrn: json['rrn']?.toString(),
      charges: json['charges'] != null ? _parseDouble(json['charges']) : null,
      walletCredited: json['wallet_credited'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
      customerName: json['customer_name'] ?? json['name'],
      customerMobile: json['customer_mobile'] ?? json['mobile'],
      customerEmail: json['customer_email'] ?? json['email'],
      balanceBefore: json['balance_before'] != null ? _parseDouble(json['balance_before']) : null,
      balanceAfter: json['balance_after'] != null ? _parseDouble(json['balance_after']) : null,
    );
  }
}

class CardPayWalletLedger {
  final int id;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? remarks;
  final String createdAt;
  final String? merchantRefId;
  final String? txnStatusCode;
  final int? userId;
  final String? userName;
  final String? mobile;

  CardPayWalletLedger({
    required this.id,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.remarks,
    required this.createdAt,
    this.merchantRefId,
    this.txnStatusCode,
    this.userId,
    this.userName,
    this.mobile,
  });

  factory CardPayWalletLedger.fromJson(Map<String, dynamic> json) {
    return CardPayWalletLedger(
      id: _parseInt(json['id']),
      amount: _parseDouble(json['amount']),
      balanceBefore: _parseDouble(json['balance_before']),
      balanceAfter: _parseDouble(json['balance_after']),
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at'] ?? '',
      merchantRefId: json['merchant_ref_id']?.toString(),
      txnStatusCode: json['txn_status_code']?.toString(),
      userId: json['user_id'] != null ? _parseInt(json['user_id']) : null,
      userName: json['user_name']?.toString(),
      mobile: json['mobile']?.toString(),
    );
  }
}

class CardPayUserBalance {
  final double balance;
  final double? mainBalance;

  CardPayUserBalance({
    required this.balance,
    this.mainBalance,
  });

  factory CardPayUserBalance.fromJson(Map<String, dynamic> json) {
    return CardPayUserBalance(
      balance: _parseDouble(json['balance']),
      mainBalance: json['mainBalance'] != null ? _parseDouble(json['mainBalance']) : null,
    );
  }
}

class CardPayDashboard {
  final int totalTransactions;
  final int successCount;
  final int failedCount;
  final int pendingCount;
  final double totalCollected;
  final double todayCollected;

  CardPayDashboard({
    required this.totalTransactions,
    required this.successCount,
    required this.failedCount,
    required this.pendingCount,
    required this.totalCollected,
    required this.todayCollected,
  });

  factory CardPayDashboard.fromJson(Map<String, dynamic> json) {
    return CardPayDashboard(
      totalTransactions: _parseInt(json['totalTransactions']),
      successCount: _parseInt(json['successCount']),
      failedCount: _parseInt(json['failedCount']),
      pendingCount: _parseInt(json['pendingCount']),
      totalCollected: _parseDouble(json['totalCollected']),
      todayCollected: _parseDouble(json['todayCollected']),
    );
  }
}

class CardPayConfig {
  final int id;
  final String keyName;
  final String environment;
  final String? keyValue;
  final String createdAt;

  CardPayConfig({
    required this.id,
    required this.keyName,
    required this.environment,
    this.keyValue,
    required this.createdAt,
  });

  factory CardPayConfig.fromJson(Map<String, dynamic> json) {
    return CardPayConfig(
      id: _parseInt(json['id']),
      keyName: json['key_name'] ?? '',
      environment: json['environment'] ?? '',
      keyValue: json['key_value']?.toString(),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CardPayPagination {
  final int limit;
  final int offset;
  final int total;
  final int count;

  CardPayPagination({
    required this.limit,
    required this.offset,
    required this.total,
    required this.count,
  });

  factory CardPayPagination.fromJson(Map<String, dynamic> json) {
    return CardPayPagination(
      limit: _parseInt(json['limit']),
      offset: _parseInt(json['offset']),
      total: _parseInt(json['total']),
      count: _parseInt(json['count']),
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
  if (value is num) return value.toDouble();
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
  if (value is num) return value.toInt();
  return 0;
}