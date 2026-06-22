// lib/models/receipt_model.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';

class ReceiptModel {
  final String transactionType;
  final String status;
  final String merchantRefId;
  final String? txnRefId;
  final String merchantId;
  final String? aadhaarNumber;
  final String transactionAmount;
  final String? availableBalance;
  final String transactionDateTime;
  final String bankIIN;
  final String? npciCode;
  final String? npciMessage;
  final String? statusDescription;
  final String mobileNumber;
  final String pipe;
  final String? udf1;
  final String? udf2;
  final String? udf3;
  final String? rrn;

  // ✅ Mini Statement entries
  final List<MiniStatementEntry>? miniStatementEntries;

  ReceiptModel({
    required this.transactionType,
    required this.status,
    required this.merchantRefId,
    this.txnRefId,
    required this.merchantId,
    this.aadhaarNumber,
    required this.transactionAmount,
    this.availableBalance,
    required this.transactionDateTime,
    required this.bankIIN,
    this.npciCode,
    this.npciMessage,
    this.statusDescription,
    required this.mobileNumber,
    required this.pipe,
    this.udf1,
    this.udf2,
    this.udf3,
    this.rrn,
    this.miniStatementEntries,
  });

  factory ReceiptModel.fromApiResponse(
      Map<String, dynamic> apiResponse, {
        required String transactionType,
        required String merchantId,
        required String mobileNumber,
      }) {
    final data = apiResponse['data'] as Map<String, dynamic>? ?? apiResponse;

    // 🔥 FIXED: Parse transaction list for Mini Statement
    List<MiniStatementEntry>? entries;
    if (data['transactionList'] != null && data['transactionList'].toString().isNotEmpty) {
      final txnList = data['transactionList'];
      try {
        if (txnList is String) {
          // Parse JSON string: "[{\"date\":\"...\"},...]"
          final List<dynamic> parsed = jsonDecode(txnList);
          entries = parsed
              .whereType<Map<String, dynamic>>()
              .map((e) => MiniStatementEntry.fromJson(e))
              .toList();
        } else if (txnList is List) {
          // Already a list
          entries = txnList
              .whereType<Map<String, dynamic>>()
              .map((e) => MiniStatementEntry.fromJson(e))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing transactionList: $e');
      }
    }

    return ReceiptModel(
      transactionType: transactionType,
      // 🔥 FIXED: Keep original status code for display, but also check
      status: data['status']?.toString() ?? '000',
      merchantRefId: data['merchantRefId']?.toString() ?? '',
      txnRefId: data['txnRefId']?.toString(),
      merchantId: data['merchantId']?.toString() ?? merchantId,
      aadhaarNumber: data['aadhaarNo']?.toString() ?? data['aadhaarNumber']?.toString(),
      transactionAmount: data['transactionAmount']?.toString() ?? '0',
      availableBalance: data['availableBalance']?.toString(),
      transactionDateTime: data['txnDateTime']?.toString() ?? DateTime.now().toString(),
      bankIIN: data['bankIIN']?.toString() ?? '',
      npciCode: data['npciCode']?.toString(),
      npciMessage: data['npciMessage']?.toString(),
      statusDescription: data['statusDescription']?.toString() ?? data['npciMessage']?.toString(),
      mobileNumber: mobileNumber,
      pipe: data['pipe']?.toString() ?? '1',
      udf1: data['udf1']?.toString(),
      udf2: data['udf2']?.toString(),
      udf3: data['udf3']?.toString(),
      rrn: data['rrn']?.toString(),
      miniStatementEntries: entries,
    );
  }

  String get typeLabel {
    switch (transactionType) {
      case 'CW': return 'Cash Withdrawal';
      case 'BE': return 'Balance Enquiry';
      case 'MS': return 'Mini Statement';
      case 'CD': return 'Cash Deposit';
      case 'AP': return 'Aadhaar Pay';
      default: return 'AEPS Transaction';
    }
  }

  // 🔥 FIXED: Better success check for different status formats
  bool get isSuccess {
    final s = status.toUpperCase();
    return s == 'SUCCESS' || s == '000' || s == '00';
  }

  bool get isAmountRequired => ['CW', 'CD', 'AP'].contains(transactionType);
  bool get isMiniStatement => transactionType == 'MS';
}

// ✅ Mini Statement Entry Model (No changes needed - already correct)
class MiniStatementEntry {
  final String date;
  final String txnType; // 'Dr' or 'Cr'
  final String amount;
  final String narration;

  MiniStatementEntry({
    required this.date,
    required this.txnType,
    required this.amount,
    required this.narration,
  });

  factory MiniStatementEntry.fromJson(Map<String, dynamic> json) {
    return MiniStatementEntry(
      date: json['date']?.toString() ?? '',
      txnType: json['txnType']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      narration: json['narration']?.toString() ?? '',
    );
  }

  bool get isDebit => txnType == 'Dr';
  bool get isCredit => txnType == 'Cr';
}