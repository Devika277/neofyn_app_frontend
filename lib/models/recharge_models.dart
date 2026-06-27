import 'package:flutter/material.dart';

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

// ─── Response ──────────────────────────────────────────────

class RechargeResponse {
  final bool success;
  final String message;
  final RechargeData? data;

  RechargeResponse({required this.success, required this.message, this.data});

  factory RechargeResponse.fromJson(Map<String, dynamic> json) {
    return RechargeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? RechargeData.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
    };
  }
}

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
      transactionId: json['transactionId'] ?? '',
      provider: json['provider'],
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

// ─── Plans ──────────────────────────────────────────────────

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
      amount: (json['amount'] ?? 0).toDouble(),
      validityDays: json['validity_days'],
      dataBenefit: json['data_benefit'],
      category: json['category'],
      circle: json['circle'],
      displayOrder: json['display_order'],
      isActive: json['is_active'] ?? true,
    );
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

class PlansResponse {
  final bool success;
  final Map<String, List<RechargePlan>> plans;

  PlansResponse({required this.success, required this.plans});

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final plansMap = <String, List<RechargePlan>>{};
    if (json['plans'] is Map) {
      (json['plans'] as Map).forEach((key, value) {
        if (value is List) {
          plansMap[key] = value.map((e) => RechargePlan.fromJson(e)).toList();
        }
      });
    }
    return PlansResponse(
      success: json['success'] ?? false,
      plans: plansMap,
    );
  }
}

// ─── History ────────────────────────────────────────────────

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
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      providerTxnId: json['provider_txn_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
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

class Pagination {
  final int limit;
  final int offset;
  final int count;

  Pagination({required this.limit, required this.offset, required this.count});

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      limit: json['limit'] ?? 0,
      offset: json['offset'] ?? 0,
      count: json['count'] ?? 0,
    );
  }
}

class HistoryResponse {
  final bool success;
  final List<TransactionItem> data;
  final Pagination pagination;

  HistoryResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    return HistoryResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List?)?.map((e) => TransactionItem.fromJson(e)).toList() ?? [],
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : Pagination(limit: 0, offset: 0, count: 0),
    );
  }
}

// ─── EXTENSIONS ─────────────────────────────────────────────
// 👇 ADD THIS AT THE VERY BOTTOM

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