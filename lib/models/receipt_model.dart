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


  // Add this helper method inside ReceiptModel class
static List<MiniStatementEntry> _parseTransactionList(dynamic transactionListData) {
  if (transactionListData == null) return [];
  
  // If it's a string, parse it
  if (transactionListData is String) {
    if (transactionListData.isEmpty || transactionListData == '[]' || transactionListData == 'null') {
      return [];
    }
    try {
      final parsed = jsonDecode(transactionListData);
      if (parsed is List) {
        return parsed
            .whereType<Map<String, dynamic>>()
            .map((e) => MiniStatementEntry.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error parsing transactionList string: $e');
      return [];
    }
  }
  
  // If it's already a list
  if (transactionListData is List) {
    return transactionListData
        .whereType<Map<String, dynamic>>()
        .map((e) => MiniStatementEntry.fromJson(e))
        .toList();
  }
  
  return [];
}
  factory ReceiptModel.fromApiResponse(
      Map<String, dynamic> apiResponse, {
        required String transactionType,
        required String merchantId,
        required String mobileNumber,
      }) {
    debugPrint('📦 ReceiptModel.fromApiResponse - Transaction Type: $transactionType');
    debugPrint('📦 Raw API Response: ${jsonEncode(apiResponse)}');
    
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
    
    // 🆕 Helper function to recursively search for transactionList in nested objects
    dynamic findTransactionList(Map<String, dynamic> obj, [int depth = 0]) {
      debugPrint('🔍 Searching for transactionList at depth $depth in keys: ${obj.keys}');
      
      // Check current level
      if (obj.containsKey('transactionList')) {
        debugPrint('✅ Found transactionList at current level');
        return obj['transactionList'];
      }
      if (obj.containsKey('transaction_list')) {
        debugPrint('✅ Found transaction_list at current level');
        return obj['transaction_list'];
      }
      if (obj.containsKey('transactions')) {
        debugPrint('✅ Found transactions at current level');
        return obj['transactions'];
      }
      if (obj.containsKey('miniStatement')) {
        debugPrint('✅ Found miniStatement at current level');
        return obj['miniStatement'];
      }
      if (obj.containsKey('mini_statement')) {
        debugPrint('✅ Found mini_statement at current level');
        return obj['mini_statement'];
      }
      
      // Search in nested objects
      for (var key in obj.keys) {
        final value = obj[key];
        if (value is Map<String, dynamic>) {
          final result = findTransactionList(value, depth + 1);
          if (result != null) {
            debugPrint('✅ Found transactionList in nested object at key: $key');
            return result;
          }
        }
      }
      return null;
    }
    
    // Try multiple methods to get transaction list
    dynamic transactionListData;
    
    // Method 1: Direct lookup
    transactionListData = data['transactionList'] ?? data['transaction_list'];
    
    // Method 2: Recursive search in nested structure
    if (transactionListData == null) {
      debugPrint('🔍 Direct lookup failed, trying recursive search...');
      transactionListData = findTransactionList(data);
    }
    
    // Method 3: Check if the response itself is a nested structure
    if (transactionListData == null) {
      debugPrint('🔍 Recursive search failed, checking if response is nested...');
      // Check if apiResponse has the nested structure with 422, 37, etc.
      if (apiResponse.containsKey('422')) {
        final firstLevel = apiResponse['422'] as Map<String, dynamic>?;
        if (firstLevel != null) {
          for (var secondLevel in firstLevel.values) {
            if (secondLevel is Map<String, dynamic>) {
              for (var thirdLevel in secondLevel.values) {
                if (thirdLevel is Map<String, dynamic>) {
                  transactionListData = thirdLevel['transactionList'] ?? 
                                       thirdLevel['transaction_list'] ?? 
                                       thirdLevel['transactions'];
                  if (transactionListData != null) {
                    debugPrint('✅ Found transactionList in nested structure: 422 -> 37 -> bankIIN');
                    break;
                  }
                }
              }
            }
            if (transactionListData != null) break;
          }
        }
      }
    }
    
    // Method 4: Try to parse from narration field as JSON array
    if (transactionListData == null) {
      final narrationStr = data['narration']?.toString() ?? '';
      debugPrint('🔍 Trying to parse narration field: ${narrationStr.substring(0, narrationStr.length > 100 ? 100 : narrationStr.length)}...');
      if (narrationStr.isNotEmpty && 
          narrationStr.trim().startsWith('[') && 
          narrationStr.trim().endsWith(']')) {
        try {
          final List<dynamic> parsed = jsonDecode(narrationStr);
          if (parsed.isNotEmpty && parsed.first is Map) {
            transactionListData = parsed;
            debugPrint('✅ Successfully parsed transaction list from narration field');
          }
        } catch (e) {
          debugPrint('❌ Error parsing narration as JSON: $e');
        }
      }
    }
    
    // Method 5: Check if the data itself is a list
    if (transactionListData == null && data is List) {
      transactionListData = data;
      debugPrint('✅ Data itself is a list, using it as transaction list');
    }
    
    debugPrint('📊 transactionListData found: ${transactionListData != null}');
    if (transactionListData != null) {
      debugPrint('📊 transactionListData type: ${transactionListData.runtimeType}');
      debugPrint('📊 transactionListData length: ${transactionListData is List ? transactionListData.length : 'N/A'}');
    }
    
    // if (transactionListData != null && transactionListData.toString().isNotEmpty) {
    //   try {
    //     if (transactionListData is String) {
    //       if (transactionListData.isNotEmpty && transactionListData != '[]') {
    //         final List<dynamic> parsed = jsonDecode(transactionListData);
    //         entries = parsed
    //             .whereType<Map<String, dynamic>>()
    //             .map((e) => MiniStatementEntry.fromJson(e))
    //             .toList();
    //         debugPrint('✅ Parsed ${entries?.length} entries from string');
    //       }
    //     } else if (transactionListData is List) {
    //       entries = transactionListData
    //           .whereType<Map<String, dynamic>>()
    //           .map((e) => MiniStatementEntry.fromJson(e))
    //           .toList();
    //       debugPrint('✅ Parsed ${entries?.length} entries from list');
    //     }
    //   } catch (e) {
    //     debugPrint('❌ Error parsing transactionList: $e');
    //     debugPrint('❌ transactionListData: $transactionListData');
    //   }
    // }
entries = _parseTransactionList(transactionListData);

    // 🆕 If still empty, check for miniStatement in the raw response
  if (entries.isNotEmpty) {
  debugPrint('✅ Parsed ${entries.length} entries from transactionList');

      final miniStatementData = apiResponse['miniStatement'] ?? 
                               apiResponse['mini_statement'] ?? 
                               apiResponse['transactionList'] ?? 
                               apiResponse['transaction_list'];
      
      if (miniStatementData != null) {
        debugPrint('📊 miniStatementData found in raw response');
        try {
          if (miniStatementData is String && 
              miniStatementData.isNotEmpty && 
              miniStatementData != '[]') {
            final List<dynamic> parsed = jsonDecode(miniStatementData);
            entries = parsed
                .whereType<Map<String, dynamic>>()
                .map((e) => MiniStatementEntry.fromJson(e))
                .toList();
            debugPrint('✅ Parsed ${entries?.length} entries from raw miniStatement');
          } else if (miniStatementData is List) {
            entries = miniStatementData
                .whereType<Map<String, dynamic>>()
                .map((e) => MiniStatementEntry.fromJson(e))
                .toList();
            debugPrint('✅ Parsed ${entries?.length} entries from raw miniStatement list');
          }
        } catch (e) {
          debugPrint('❌ Error parsing raw miniStatement: $e');
        }
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

    debugPrint('📊 Final entries count: ${entries?.length ?? 0}');

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
    debugPrint('📝 Parsing MiniStatementEntry from: $json');
    
    // Try multiple possible field names - with backward compatibility
    String date = json['date']?.toString() ?? 
                 json['txnDate']?.toString() ?? 
                 json['txn_date']?.toString() ?? 
                 json['transactionDate']?.toString() ?? 
                 json['txnDate']?.toString() ??
                 '';

    String txnType = json['txnType']?.toString() ?? 
                    json['txn_type']?.toString() ?? 
                    json['type']?.toString() ?? 
                    json['txnType']?.toString() ??
                    'Dr';

    String amount = json['amount']?.toString() ?? 
                   json['txnAmount']?.toString() ?? 
                   json['txn_amount']?.toString() ?? 
                   json['amt']?.toString() ??
                   '0';

    String narration = json['narration']?.toString() ?? 
                      json['remarks']?.toString() ?? 
                      json['description']?.toString() ?? 
                      json['narration']?.toString() ??
                      '';

    debugPrint('📝 Parsed: date=$date, txnType=$txnType, amount=$amount, narration=$narration');

    return MiniStatementEntry(
      date: date,
      txnType: txnType,
      amount: amount,
      narration: narration,
    );
  }


  // ✅ ADD THE toJson METHOD HERE - after fromJson
    Map<String, dynamic> toJson() {
    return {
      'date': date,
      'txnType': txnType,
      'amount': amount,
      'narration': narration,
    };
  }

  bool get isDebit => txnType == 'Dr' || txnType == 'DEBIT' || txnType == 'D';
  bool get isCredit => txnType == 'Cr' || txnType == 'CREDIT' || txnType == 'C';
}