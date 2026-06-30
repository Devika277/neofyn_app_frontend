// lib/models/recharge_models.dart

import 'package:flutter/material.dart';

// ============================================================
// RECHARGE REQUEST
// ============================================================
class RechargeRequest {
  final String mobile;
  final String operator;
  final String serviceType;
  final double amount;
  final String? idempotencyKey;
  final bool? testMode;
  final double? lat;
  final double? long;

  RechargeRequest({
    required this.mobile,
    required this.operator,
    this.serviceType = 'MBL',
    required this.amount,
    this.idempotencyKey,
    this.testMode,
    this.lat,
    this.long,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobile,
      'operator': operator,
      'serviceType': serviceType,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
      'testMode': testMode,
      'lat': lat,
      'long': long,
    };
  }
}

// ============================================================
// RECHARGE RESPONSE
// ============================================================
class RechargeResponse {
  final bool success;
  final String status;
  final String message;
  final RechargeData? data;

  RechargeResponse({
    required this.success,
    this.status = 'failed',
    required this.message,
    this.data,
  });

  factory RechargeResponse.fromJson(Map<String, dynamic> json) {
    return RechargeResponse(
      success: json['success'] ?? false,
      status: json['status'] ?? (json['success'] == true ? 'success' : 'failed'),
      message: json['message'] ?? '',
      data: json['data'] != null ? RechargeData.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'status': status,
      'message': message,
      'data': data?.toJson()
    };
  }

  bool get isSuccess => status == 'success';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}

// ============================================================
// RECHARGE DATA
// ============================================================
class RechargeData {
  final String transactionId;
  final String? provider;
  final bool refunded;

  RechargeData({
    required this.transactionId,
    this.provider,
    required this.refunded,
  });

  factory RechargeData.fromJson(Map<String, dynamic> json) {
    return RechargeData(
      transactionId: (json['transactionId'] ?? '').toString(),
      provider: json['provider']?.toString(),
      refunded: json['refunded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'provider': provider,
      'refunded': refunded,
    };
  }
}

// ============================================================
// RECHARGE PLANS
// ============================================================
class RechargePlan {
  final int id;
  final String operator;
  final double amount;
  final int? validityDays;
  final String? dataBenefit;
  final String? category;
  final String? circle;
  final int? displayOrder;
  final bool isActive;

  RechargePlan({
    required this.id,
    required this.operator,
    required this.amount,
    this.validityDays,
    this.dataBenefit,
    this.category,
    this.circle,
    this.displayOrder,
    required this.isActive,
  });

  factory RechargePlan.fromJson(Map<String, dynamic> json) {
    return RechargePlan(
      id: json['id'] ?? 0,
      operator: json['operator'] ?? '',
      amount: _parseAmount(json['amount']),
      validityDays: json['validity_days'] is int
          ? json['validity_days']
          : int.tryParse(json['validity_days']?.toString() ?? ''),
      dataBenefit: json['data_benefit'],
      category: json['category'],
      circle: json['circle'],
      displayOrder: json['display_order'] is int
          ? json['display_order']
          : int.tryParse(json['display_order']?.toString() ?? ''),
      isActive: json['is_active'] ?? true,
    );
  }

  static double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      String cleaned = amount.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operator': operator,
      'amount': amount,
      'validity_days': validityDays,
      'data_benefit': dataBenefit,
      'category': category,
      'circle': circle,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}

// ============================================================
// PLANS RESPONSE
// ============================================================
class PlansResponse {
  final bool success;
  final Map<String, List<RechargePlan>> plans;

  PlansResponse({required this.success, required this.plans});

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final plansMap = <String, List<RechargePlan>>{};

    if (json['plans'] is Map) {
      final plansData = json['plans'] as Map;

      if (plansData.containsKey('data') && plansData['data'] is List) {
        final List<dynamic> dataList = plansData['data'];
        plansMap['all'] = dataList
            .map(
              (e) => RechargePlan.fromJson(e is Map<String, dynamic> ? e : {}),
            )
            .toList();
      } else {
        plansData.forEach((key, value) {
          if (value is List) {
            plansMap[key.toString()] = value
                .map(
                  (e) =>
                      RechargePlan.fromJson(e is Map<String, dynamic> ? e : {}),
                )
                .toList();
          }
        });
      }
    }

    return PlansResponse(success: json['success'] ?? false, plans: plansMap);
  }
}

// ============================================================
// ✅ TRANSACTION ITEM (For History List)
// ============================================================
class TransactionItem {
  final int id;
  final String mobile;
  final String operator;
  final double amount;
  final String status; // 'pending', 'success', 'failed'
  final String? providerTxnId;
  final DateTime createdAt;

  TransactionItem({
    required this.id,
    required this.mobile,
    required this.operator,
    required this.amount,
    required this.status,
    this.providerTxnId,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? 0,
      mobile: json['mobile'] ?? '',
      operator: json['operator'] ?? '',
      amount: _parseAmount(json['amount']), // ✅ Use helper method
      status: json['status'] ?? 'pending',
      providerTxnId: json['provider_txn_id'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  // ✅ Helper method to parse amount
  static double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      final cleaned = amount.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'operator': operator,
      'amount': amount,
      'status': status,
      'provider_txn_id': providerTxnId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ============================================================
// ✅ RECHARGE HISTORY ITEM (For Detailed History)
// ============================================================
class RechargeHistoryItem {
  final int id;
  final String? transactionId;
  final String? mobileNumber;
  final String? operator;
  final String? serviceType;
  final double amount;
  final String? status;
  final String? operatorRefId;
  final String? createdAt;
  final String? paymentMethod;
  final double? commission;
  final String? errorMessage;

  RechargeHistoryItem({
    required this.id,
    this.transactionId,
    this.mobileNumber,
    this.operator,
    this.serviceType,
    required this.amount,
    this.status,
    this.operatorRefId,
    this.createdAt,
    this.paymentMethod,
    this.commission,
    this.errorMessage,
  });

  factory RechargeHistoryItem.fromJson(Map<String, dynamic> json) {
    return RechargeHistoryItem(
      id: json['id'] ?? 0,
      transactionId: json['transaction_id'] ?? json['id']?.toString(),
      mobileNumber: json['mobile_number'] ?? json['mobile'],
      operator: json['operator'],
      serviceType: json['service_type'],
      amount: _parseAmount(json['amount']), // ✅ Use helper method
      status: json['status'] ?? 'pending',
      operatorRefId: json['operator_ref_id'],
      createdAt: json['created_at'],
      paymentMethod: json['payment_method'],
      commission: _parseNullableAmount(json['commission']), // ✅ Use helper method
      errorMessage: json['error_message'] ?? json['failure_reason'],
    );
  }

  // ✅ Helper method to parse amount from String, int, or double
  static double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      // Remove any non-numeric characters except decimal point
      final cleaned = amount.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ Helper method for nullable amount
  static double? _parseNullableAmount(dynamic amount) {
    if (amount == null) return null;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      final cleaned = amount.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'mobile_number': mobileNumber,
      'operator': operator,
      'service_type': serviceType,
      'amount': amount,
      'status': status,
      'operator_ref_id': operatorRefId,
      'created_at': createdAt,
      'payment_method': paymentMethod,
      'commission': commission,
      'error_message': errorMessage,
    };
  }

  // Helper getters for UI
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
  
  Color get statusColor {
    if (isSuccess) return Colors.green;
    if (isFailed) return Colors.red;
    return Colors.orange;
  }
  
  IconData get statusIcon {
    if (isSuccess) return Icons.check_circle_outline;
    if (isFailed) return Icons.error_outline;
    return Icons.pending_outlined;
  }
  
  String get statusText {
    if (isSuccess) return 'Success';
    if (isFailed) return 'Failed';
    return 'Pending';
  }
}
// ============================================================
// HISTORY RESPONSE
// ============================================================
class HistoryResponse {
  final bool success;
  final List<RechargeHistoryItem>? data;
  final String? message;
  final Pagination? pagination;

  HistoryResponse({
    required this.success,
    this.data,
    this.message,
    this.pagination,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    return HistoryResponse(
      success: json['success'] == true,
      data: json['data'] != null
          ? (json['data'] as List)
              .map((e) => RechargeHistoryItem.fromJson(e))
              .toList()
          : null,
      message: json['message'],
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

// ============================================================
// PAGINATION
// ============================================================
class Pagination {
  final int limit;
  final int offset;
  final int count;

  Pagination({
    required this.limit,
    required this.offset,
    required this.count,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'limit': limit,
      'offset': offset,
      'count': count,
    };
  }
}

// ============================================================
// EXTENSIONS
// ============================================================
extension PlanCategoryExtension on String {
  String get displayName {
    switch (this) {
      case 'data':
        return 'Data';
      case 'unlimited':
        return 'Unlimited';
      case 'ott':
        return 'OTT';
      case 'talktime':
        return 'Talktime';
      case 'roaming':
        return 'Roaming';
      case 'feature':
        return 'Feature Phone';
      case 'isd':
        return 'ISD';
      case 'gaming':
        return 'Gaming';
      case 'vowifi':
        return 'Wi-Fi';
      case 'other':
        return 'Other';
      default:
        return this.toUpperCase();
    }
  }

  Color get color {
    switch (this) {
      case 'data':
        return Colors.blue;
      case 'unlimited':
        return Colors.green;
      case 'ott':
        return Colors.purple;
      case 'talktime':
        return Colors.orange;
      case 'roaming':
        return Colors.red;
      case 'feature':
        return Colors.teal;
      case 'isd':
        return Colors.indigo;
      case 'gaming':
        return Colors.pink;
      case 'vowifi':
        return Colors.cyan;
      case 'other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case 'data':
        return Icons.wifi;
      case 'unlimited':
        return Icons.signal_cellular_alt;
      case 'ott':
        return Icons.movie;
      case 'talktime':
        return Icons.phone;
      case 'roaming':
        return Icons.public;
      case 'feature':
        return Icons.star;
      case 'isd':
        return Icons.phone_in_talk;
      case 'gaming':
        return Icons.games;
      case 'vowifi':
        return Icons.wifi_tethering;
      case 'other':
        return Icons.help;
      default:
        return Icons.help;
    }
  }
}