// lib/services/matm_service.dart
import 'package:flutter/services.dart';
import 'dart:convert';

class MatmService {
  static const MethodChannel _channel = MethodChannel('com.example.my_app/matm');

  /// Balance Enquiry
  static Future<MatmResponse> balanceEnquiry(String merchantId) async {
    try {
      if (merchantId.isEmpty) {
        throw MatmException('Merchant ID cannot be empty', 'EMPTY_MERCHANT_ID');
      }

      print('📤 [MATM] Sending Balance Enquiry request for: $merchantId');
      
      final String result = await _channel.invokeMethod(
        'startBalanceEnquiry',
        {'merchantId': merchantId}
      );
      
      print('📥 [MATM] Raw response: $result');
      
      final Map<String, dynamic> jsonData = jsonDecode(result);
      
      if (jsonData.containsKey('error')) {
        throw MatmException(jsonData['error'].toString(), 'SDK_ERROR');
      }
      
      return MatmResponse.fromJson(jsonData);
    } on PlatformException catch (e) {
      print('❌ [MATM] Platform Exception: ${e.code} - ${e.message}');
      throw MatmException(
        e.message ?? 'Platform error occurred', 
        e.code ?? 'PLATFORM_ERROR'
      );
    } catch (e) {
      print('❌ [MATM] Unknown error: $e');
      throw MatmException(e.toString(), 'UNKNOWN');
    }
  }

  /// Cash Withdrawal (FIXED - Only one definition)
  static Future<MatmResponse> cashWithdrawal(String merchantId, String amount) async {
    try {
      if (merchantId.isEmpty) {
        throw MatmException('Merchant ID cannot be empty', 'EMPTY_MERCHANT_ID');
      }

      final amountDouble = double.tryParse(amount);
      if (amountDouble == null || amountDouble <= 0) {
        throw MatmException('Amount must be greater than 0', 'INVALID_AMOUNT');
      }

      print('📤 [MATM] Sending Cash Withdrawal request for: $merchantId, Amount: $amount');
      
      final String result = await _channel.invokeMethod(
        'startCashWithdrawal',
        {
          'merchantId': merchantId,
          'amount': amount
        }
      );
      
      print('📥 [MATM] Raw response: $result');
      
      final Map<String, dynamic> jsonData = jsonDecode(result);
      
      if (jsonData.containsKey('error')) {
        throw MatmException(jsonData['error'].toString(), 'SDK_ERROR');
      }
      
      return MatmResponse.fromJson(jsonData);
    } on PlatformException catch (e) {
      print('❌ [MATM] Platform Exception: ${e.code} - ${e.message}');
      throw MatmException(
        e.message ?? 'Platform error occurred', 
        e.code ?? 'PLATFORM_ERROR'
      );
    } catch (e) {
      print('❌ [MATM] Unknown error: $e');
      throw MatmException(e.toString(), 'UNKNOWN');
    }
  }

  /// Start a custom transaction
  static Future<MatmResponse> startTransaction({
    required String merchantId,
    required String txnCode,
    required String amount,
    String remarks = '',
  }) async {
    try {
      if (txnCode != 'BE' && txnCode != 'CW' && 
          txnCode != 'BALANCE_ENQUIRY' && txnCode != 'CASH_WITHDRAWAL') {
        throw MatmException('Invalid transaction code', 'INVALID_TXN_CODE');
      }

      final String result = await _channel.invokeMethod(
        'startTransaction',
        {
          'merchantId': merchantId,
          'txnCode': txnCode,
          'amount': amount,
          'remarks': remarks,
        }
      );
      return MatmResponse.fromJson(jsonDecode(result));
    } on PlatformException catch (e) {
      throw MatmException('Transaction failed: ${e.message}', e.code);
    } catch (e) {
      throw MatmException('Transaction failed: $e', 'UNKNOWN');
    }
  }

  /// Test SDK Connection
  static Future<bool> testConnection(String merchantId) async {
    try {
      print('🔍 [MATM] Testing SDK connection...');
      final result = await balanceEnquiry(merchantId);
      print('✅ [MATM] SDK connection test successful');
      return true;
    } catch (e) {
      print('❌ [MATM] SDK connection test failed: $e');
      return false;
    }
  }
}

/// Response model for mATM transactions
class MatmResponse {
  final String status;
  final String merchantStatus;
  final String statusDescription;
  final String? availableBalance;
  final String? txnAmount;
  final String? bankRRN;
  final String? transactionType;
  final String? fpTransactionId;
  final String? cardNumber;
  final String? bankName;
  final String? cardType;
  final String? txnTime;
  final String? refId;
  final String? merchantId;
  final String? merchantRefId;
  final String? firstName;
  final String? lastName;
  final String? emailId;
  final String? mobileNo;
  final String? aadhaarNo;
  final String? panNo;
  final String? pipe;

  MatmResponse({
    required this.status,
    required this.merchantStatus,
    required this.statusDescription,
    this.availableBalance,
    this.txnAmount,
    this.bankRRN,
    this.transactionType,
    this.fpTransactionId,
    this.cardNumber,
    this.bankName,
    this.cardType,
    this.txnTime,
    this.refId,
    this.merchantId,
    this.merchantRefId,
    this.firstName,
    this.lastName,
    this.emailId,
    this.mobileNo,
    this.aadhaarNo,
    this.panNo,
    this.pipe,
  });

  factory MatmResponse.fromJson(Map<String, dynamic> json) {
    return MatmResponse(
      status: json['status']?.toString() ?? 'UNKNOWN',
      merchantStatus: json['merchantStatus'] ?? 'Unknown',
      statusDescription: json['statusDescription'] ?? 'No description',
      availableBalance: json['availableBalance']?.toString(),
      txnAmount: json['txnAmount']?.toString(),
      bankRRN: json['bankRRN']?.toString(),
      transactionType: json['transactionType'],
      fpTransactionId: json['fpTransactionId'],
      cardNumber: json['cardNumber'],
      bankName: json['bankName'],
      cardType: json['cardType'],
      txnTime: json['txnTime'],
      refId: json['refId'] ?? json['refld'],
      merchantId: json['merchantId'],
      merchantRefId: json['merchantRefId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      emailId: json['emailId'],
      mobileNo: json['mobileNo'],
      aadhaarNo: json['aadhaarNo'],
      panNo: json['panNo'],
      pipe: json['pipe'],
    );
  }

  bool get isSuccess => status == '000';
  bool get isPending => status == '002';
  bool get isFailed => status == '001';
  bool get isValidationFailed => status == '003';

  @override
  String toString() {
    return 'MatmResponse{status: $status, merchantStatus: $merchantStatus, statusDescription: $statusDescription, availableBalance: $availableBalance, txnAmount: $txnAmount}';
  }
}

/// Custom exception for mATM errors
class MatmException implements Exception {
  final String message;
  final String code;

  MatmException(this.message, this.code);

  @override
  String toString() => 'MatmException($code): $message';
}