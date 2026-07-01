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
  final String? bankName;
  final String? npciCode;
  final String? npciMessage;
  final String? statusDescription;
  final String mobileNumber;
  final String pipe;
  final String? udf1;
  final String? udf2;
  final String? udf3;
  final String? rrn;
  final String? deviceUsed;
  final String? createdAt;

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
    this.bankName,
    this.npciCode,
    this.npciMessage,
    this.statusDescription,
    required this.mobileNumber,
    required this.pipe,
    this.udf1,
    this.udf2,
    this.udf3,
    this.rrn,
    this.deviceUsed,
    this.createdAt,
    this.miniStatementEntries,
  });

  factory ReceiptModel.fromApiResponse(
      Map<String, dynamic> apiResponse, {
        required String transactionType,
        required String merchantId,
        required String mobileNumber,
      }) {
    final data = apiResponse['data'] as Map<String, dynamic>? ?? apiResponse;

    // ✅ FIX: Get status and determine success
    final statusCode = data['status']?.toString() ?? '001';
    final successStatus = data['successStatus']?.toString() ?? 'false';
    
    // Check if transaction was successful using multiple indicators
    final bool isSuccess = 
        statusCode == '000' || 
        statusCode == '00' || 
        statusCode == 'SUCCESS' ||
        successStatus.toLowerCase() == 'true';

    // Use proper status display
    final String displayStatus = isSuccess ? 'SUCCESS' : 'FAILED';

    // ✅ FIX: Parse transaction list for Mini Statement - with backward compatibility
    List<MiniStatementEntry>? entries;
    
    // Try to get transaction list - check both camelCase and snake_case
    dynamic transactionListData = data['transactionList'] ?? data['transaction_list'];
    
    if (transactionListData != null && transactionListData.toString().isNotEmpty) {
      try {
        if (transactionListData is String) {
          if (transactionListData.isNotEmpty && transactionListData != '[]') {
            final List<dynamic> parsed = jsonDecode(transactionListData);
            entries = parsed
                .whereType<Map<String, dynamic>>()
                .map((e) => MiniStatementEntry.fromJson(e))
                .toList();
          }
        } else if (transactionListData is List) {
          entries = transactionListData
              .whereType<Map<String, dynamic>>()
              .map((e) => MiniStatementEntry.fromJson(e))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing transactionList: $e');
      }
    }

    // ✅ FIX: Get values - try camelCase first (for live transactions), then snake_case (for history)
    // This maintains backward compatibility
    String getValue(String camelKey, String snakeKey, [String defaultValue = '']) {
      final camelValue = data[camelKey]?.toString();
      if (camelValue != null && camelValue.isNotEmpty) {
        return camelValue;
      }
      final snakeValue = data[snakeKey]?.toString();
      if (snakeValue != null && snakeValue.isNotEmpty) {
        return snakeValue;
      }
      return defaultValue;
    }

    String merchantRefId = getValue('merchantRefId', 'merchant_ref_id', 'N/A');
    String txnRefId = getValue('txnRefId', 'txn_ref_id', '');
    String availableBalance = getValue('availableBalance', 'available_balance', '');
    String aadhaarNo = getValue('aadhaarNo', 'aadhaar_last4', '');
    String bankIIN = getValue('bankIIN', 'bank_iin', '');
    String bankName = getValue('bankName', 'bank_name', '');
    String npciCode = getValue('npciCode', 'npci_code', '');
    String npciMessage = getValue('npciMessage', 'npci_message', '');
    String statusDescription = getValue('statusDescription', 'status_description', '');
    String rrn = getValue('rrn', 'rrn', '');
    String deviceUsed = getValue('deviceUsed', 'device_used', '');
    String createdAt = getValue('createdAt', 'created_at', '');
    
    // For transactionDateTime - try multiple sources
    String transactionDateTime = data['txnDateTime']?.toString() ?? 
                                data['txn_date_time']?.toString() ?? 
                                data['created_at']?.toString() ?? 
                                data['createdAt']?.toString() ?? 
                                DateTime.now().toString();

    // For mobile number
    String mobileNumberFinal = mobileNumber.isNotEmpty ? mobileNumber :
                              data['mobileNumber']?.toString() ?? 
                              data['mobile_no']?.toString() ?? 
                              data['mobile']?.toString() ?? 
                              '';

    return ReceiptModel(
      transactionType: transactionType,
      status: displayStatus,
      merchantRefId: merchantRefId,
      txnRefId: txnRefId.isNotEmpty ? txnRefId : null,
      merchantId: data['merchantId']?.toString() ?? 
                 data['merchant_id']?.toString() ?? 
                 merchantId,
      aadhaarNumber: aadhaarNo.isNotEmpty ? aadhaarNo : null,
      transactionAmount: data['transactionAmount']?.toString() ?? 
                        data['transaction_amount']?.toString() ?? 
                        data['amount']?.toString() ?? 
                        '0',
      availableBalance: availableBalance.isNotEmpty ? availableBalance : null,
      transactionDateTime: transactionDateTime,
      bankIIN: bankIIN,
      bankName: bankName.isNotEmpty ? bankName : null,
      npciCode: npciCode.isNotEmpty ? npciCode : null,
      npciMessage: npciMessage.isNotEmpty ? npciMessage : null,
      statusDescription: statusDescription.isNotEmpty ? statusDescription : null,
      mobileNumber: mobileNumberFinal,
      pipe: data['pipe']?.toString() ?? '1',
      udf1: data['udf1']?.toString(),
      udf2: data['udf2']?.toString(),
      udf3: data['udf3']?.toString(),
      rrn: rrn.isNotEmpty ? rrn : null,
      deviceUsed: deviceUsed.isNotEmpty ? deviceUsed : null,
      createdAt: createdAt.isNotEmpty ? createdAt : null,
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

  // ✅ IMPROVED: More robust success check
  bool get isSuccess {
    // Check status string
    final s = status.toUpperCase();
    if (s == 'SUCCESS' || s == '000' || s == '00' || s == 'APPROVED') {
      return true;
    }
    
    // Check status description for success indicators
    final desc = statusDescription?.toUpperCase() ?? '';
    if (desc.contains('SUCCESS') || desc.contains('APPROVED')) {
      return true;
    }
    
    // Check NPCI message for success indicators
    final npci = npciMessage?.toUpperCase() ?? '';
    if (npci.contains('SUCCESS') || npci.contains('APPROVED') || npci.contains('TRANSACTION SUCCESS')) {
      return true;
    }
    
    return false;
  }

  // ✅ Get display status (always shows SUCCESS or FAILED)
  String get displayStatus {
    return isSuccess ? 'SUCCESS' : 'FAILED';
  }

  bool get isAmountRequired => ['CW', 'CD', 'AP'].contains(transactionType);
  bool get isMiniStatement => transactionType == 'MS';
}

// ✅ Updated Mini Statement Entry Model with backward compatibility
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
    // Try multiple possible field names - with backward compatibility
    String date = json['date']?.toString() ?? 
                 json['txnDate']?.toString() ?? 
                 json['txn_date']?.toString() ?? 
                 json['transactionDate']?.toString() ?? 
                 '';

    String txnType = json['txnType']?.toString() ?? 
                    json['txn_type']?.toString() ?? 
                    json['type']?.toString() ?? 
                    'Dr';

    String amount = json['amount']?.toString() ?? 
                   json['txnAmount']?.toString() ?? 
                   json['txn_amount']?.toString() ?? 
                   '0';

    String narration = json['narration']?.toString() ?? 
                      json['remarks']?.toString() ?? 
                      json['description']?.toString() ?? 
                      '';

    return MiniStatementEntry(
      date: date,
      txnType: txnType,
      amount: amount,
      narration: narration,
    );
  }

  bool get isDebit => txnType == 'Dr' || txnType == 'DEBIT' || txnType == 'D';
  bool get isCredit => txnType == 'Cr' || txnType == 'CREDIT' || txnType == 'C';
}