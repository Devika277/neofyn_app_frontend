// lib/services/aeps_service.dart

import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ==============================
// Helper
// ==============================

String _buildPipeQuery(String? pipe) {
  if (pipe == null || pipe.isEmpty) return '';
  return '?pipe=$pipe';
}

// ==============================
// Models
// ==============================

class MerchantStatus {
  final bool isRegistered;
  final String? registrationStatus; // pending, otp_pending, active, rejected
  final String? merchantId;
  final String? stateCode;
  final String? districtCode;
  final String? shopAddress;
  final String? pipe; // '1', '2', '3'
  final String? merchantRefId;

  MerchantStatus({
    required this.isRegistered,
    this.registrationStatus,
    this.merchantId,
    this.stateCode,
    this.districtCode,
    this.shopAddress,
    this.pipe,
    this.merchantRefId,
  });

  factory MerchantStatus.fromJson(Map<String, dynamic> json) => MerchantStatus(
        isRegistered: json['isRegistered'] as bool,
        registrationStatus: json['registrationStatus'] as String?,
        merchantId: json['merchantId'] as String?,
        stateCode: json['stateCode'] as String?,
        districtCode: json['districtCode'] as String?,
        shopAddress: json['shopAddress'] as String?,
        pipe: json['pipe'] as String?,
        merchantRefId: json['merchantRefId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'isRegistered': isRegistered,
        'registrationStatus': registrationStatus,
        'merchantId': merchantId,
        'stateCode': stateCode,
        'districtCode': districtCode,
        'shopAddress': shopAddress,
        'pipe': pipe,
        'merchantRefId': merchantRefId,
      };
}

class RegisterMerchantRequest {
  final String stateCode;
  final String districtCode;
  final String shopAddress;
  final String shopPincode;
  final String bankAccount;
  final String bankIfsc;
  final String bankNameCode;
  final String? pipe;
  final String? merchantRefId;
  final String? ipAddress;
  final String? lat;
  final String? long;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String dob;
  final String merchantPhoneNumber;
  final String merchantAddress1;
  final String? merchantAddress2;
  final String? merchantPan;
  final String? shopPan;
  final String? aadhaarNo;
  final String? pidData;
  final String? emailId;

  RegisterMerchantRequest({
    required this.stateCode,
    required this.districtCode,
    required this.shopAddress,
    required this.shopPincode,
    required this.bankAccount,
    required this.bankIfsc,
    required this.bankNameCode,
    this.pipe,
    this.merchantRefId,
    this.ipAddress,
    this.lat,
    this.long,
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.dob,
    required this.merchantPhoneNumber,
    required this.merchantAddress1,
    this.merchantAddress2,
    this.merchantPan,
    this.shopPan,
    this.aadhaarNo,
    this.pidData,
    this.emailId,
  });

  Map<String, dynamic> toJson() => {
        'stateCode': stateCode,
        'districtCode': districtCode,
        'shopAddress': shopAddress,
        'shopPincode': shopPincode,
        'bankAccount': bankAccount,
        'bankIfsc': bankIfsc,
        'bankNameCode': bankNameCode,
        'pipe': pipe,
        'merchantRefId': merchantRefId,
        'ipAddress': ipAddress,
        'lat': lat,
        'long': long,
        'firstName': firstName,
        'lastName': lastName,
        'middleName': middleName,
        'dob': dob,
        'merchantPhoneNumber': merchantPhoneNumber,
        'merchantAddress1': merchantAddress1,
        'merchantAddress2': merchantAddress2,
        'merchantPan': merchantPan,
        'shopPan': shopPan,
        'aadhaarNo': aadhaarNo,
        'pidData': pidData,
        'emailId': emailId,
      };
}

class RegisterMerchantResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? merchantId;
  final String? txnRefId;
  final String? merchantRefId;
  final String? pipe;

  RegisterMerchantResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.merchantId,
    this.txnRefId,
    this.merchantRefId,
    this.pipe,
  });

  factory RegisterMerchantResponse.fromJson(Map<String, dynamic> json) =>
      RegisterMerchantResponse(
        status: (json['status'] as String?) ?? '999',
        merchantStatus: json['merchantStatus'] as String?,
        // statusDescription: json['statusDescription'] as String,
        statusDescription: (json['statusDescription'] as String?) ??
            (json['message'] as String?) ??
            'Unknown status',
        merchantId: json['merchantId'] as String?,
        txnRefId: json['txnRefId'] as String?,
        merchantRefId: json['merchantRefId'] as String?,
        pipe: json['pipe'] as String?,
      );
}

class Bank {
  final String code;
  final String name;

  Bank({required this.code, required this.name});

  factory Bank.fromJson(Map<String, dynamic> json) =>
      Bank(code: json['code'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class State {
  final String code;
  final String name;

  State({required this.code, required this.name});

  factory State.fromJson(Map<String, dynamic> json) =>
      State(code: json['code'] as String, name: json['name'] as String);
}

class District {
  final String code;
  final String name;

  District({required this.code, required this.name});

  factory District.fromJson(Map<String, dynamic> json) =>
      District(code: json['code'] as String, name: json['name'] as String);
}

class BankIIN {
  final String iin;
  final String description;

  BankIIN({required this.iin, required this.description});

  factory BankIIN.fromJson(Map<String, dynamic> json) =>
      BankIIN(iin: json['iin'] as String, description: json['description'] as String);
}

class OtpRequest {
  final String merchantId;
  final String merchantRefId;
  final String? pipe;

  OtpRequest({required this.merchantId, required this.merchantRefId, this.pipe});

  Map<String, dynamic> toJson() => {
        'merchantId': merchantId,
        'merchantRefId': merchantRefId,
        'pipe': pipe,
      };
}

class OtpResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? merchantId;
  final String? txnRefId;

  OtpResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.merchantId,
    this.txnRefId,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) => OtpResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        merchantId: json['merchantId'] as String?,
        txnRefId: json['txnRefId'] as String?,
      );
}

class VerifyOtpRequest extends OtpRequest {
  final String otp;

  VerifyOtpRequest({
    required String merchantId,
    required String merchantRefId,
    String? pipe,
    required this.otp,
  }) : super(merchantId: merchantId, merchantRefId: merchantRefId, pipe: pipe);

  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'otp': otp,
      };
}

class MerchantEkycRequest {
  final String merchantId;
  final String merchantRefId;
  final String? pipe;
  final String pidData;
  final String? deviceType;
  final String? aadhaarNumber;

  MerchantEkycRequest({
    required this.merchantId,
    required this.merchantRefId,
    this.pipe,
    required this.pidData,
    this.deviceType,
    this.aadhaarNumber,
  });

  Map<String, dynamic> toJson() => {
        'merchantId': merchantId,
        'merchantRefId': merchantRefId,
        'pipe': pipe,
        'pidData': pidData,
        'deviceType': deviceType,
        'aadhaarNumber': aadhaarNumber,
      };
}

class MerchantEkycResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? merchantId;
  final String? txnRefId;

  MerchantEkycResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.merchantId,
    this.txnRefId,
  });

  factory MerchantEkycResponse.fromJson(Map<String, dynamic> json) => MerchantEkycResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        merchantId: json['merchantId'] as String?,
        txnRefId: json['txnRefId'] as String?,
      );
}

class Perform2FARequest {
  final String merchantId;
  final String merchantRefId;
  final String aadhaarNumber;
  final String? pipe;
  final String? deviceType;
  final String pidData;
  final String? lat;
  final String? long;

  Perform2FARequest({
    required this.merchantId,
    required this.merchantRefId,
    required this.aadhaarNumber,
    this.pipe,
    this.deviceType,
    required this.pidData,
    this.lat,
    this.long,
  });

  Map<String, dynamic> toJson() => {
        'merchantId': merchantId,
        'merchantRefId': merchantRefId,
        'aadhaarNumber': aadhaarNumber,
        'pipe': pipe,
        'deviceType': deviceType,
        'pidData': pidData,
        'lat': lat,
        'long': long,
      };
}

class Perform2FAResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? merchantId;
  final String? txnRefId;

  Perform2FAResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.merchantId,
    this.txnRefId,
  });

  factory Perform2FAResponse.fromJson(Map<String, dynamic> json) => Perform2FAResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        merchantId: json['merchantId'] as String?,
        txnRefId: json['txnRefId'] as String?,
      );
}

class CashWithdrawalRequest {
  final int amount;
  final String bankCode;
  final String pidData;
  final String? accountType;
  final String? lat;
  final String? long;
  final String? device;
  final String? aadhaarNo;
  final String? mobileNo;
  final String? pipe;

  CashWithdrawalRequest({
    required this.amount,
    required this.bankCode,
    required this.pidData,
    this.accountType,
    this.lat,
    this.long,
    this.device,
    this.aadhaarNo,
    this.mobileNo,
    this.pipe,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'bankCode': bankCode,
        'pidData': pidData,
        'accountType': accountType,
        'lat': lat,
        'long': long,
        'device': device,
        'aadhaarNo': aadhaarNo,
        'mobileNo': mobileNo,
        'pipe': pipe,
      };
}

class CashWithdrawalResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? txnRefId;
  final String? merchantRefId;
  final String? transactionAmount;
  final String? aadhaarNo;
  final String? txnDateTime;
  final String? bankIIN;
  final String? rrn;
  final String? npciCode;
  final String? npciMessage;
  final String? availableBalance;
  final String? pipe;
  final String? deviceUsed;
  final dynamic transactionId; // int or String

  CashWithdrawalResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.txnRefId,
    this.merchantRefId,
    this.transactionAmount,
    this.aadhaarNo,
    this.txnDateTime,
    this.bankIIN,
    this.rrn,
    this.npciCode,
    this.npciMessage,
    this.availableBalance,
    this.pipe,
    this.deviceUsed,
    this.transactionId,
  });

  factory CashWithdrawalResponse.fromJson(Map<String, dynamic> json) => CashWithdrawalResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        txnRefId: json['txnRefId'] as String?,
        merchantRefId: json['merchantRefId'] as String?,
        transactionAmount: json['transactionAmount'] as String?,
        aadhaarNo: json['aadhaarNo'] as String?,
        txnDateTime: json['txnDateTime'] as String?,
        bankIIN: json['bankIIN'] as String?,
        rrn: json['rrn'] as String?,
        npciCode: json['npciCode'] as String?,
        npciMessage: json['npciMessage'] as String?,
        availableBalance: json['availableBalance'] as String?,
        pipe: json['pipe'] as String?,
        deviceUsed: json['device_used'] as String?,
        transactionId: json['transactionId'],
      );
}

typedef CashDepositRequest = CashWithdrawalRequest;
typedef CashDepositResponse = CashWithdrawalResponse;

class BalanceEnquiryRequest {
  final String bankCode;
  final String pidData;
  final String? accountType;
  final String? device;
  final String? aadhaarNo;
  final String? mobileNo;
  final String? pipe;
  final String? lat;
  final String? long;

  BalanceEnquiryRequest({
    required this.bankCode,
    required this.pidData,
    this.accountType,
    this.device,
    this.aadhaarNo,
    this.mobileNo,
    this.pipe,
    this.lat,
    this.long,
  });

  Map<String, dynamic> toJson() => {
        'bankCode': bankCode,
        'pidData': pidData,
        'accountType': accountType,
        'device': device,
        'aadhaarNo': aadhaarNo,
        'mobileNo': mobileNo,
        'pipe': pipe,
        'lat': lat,
        'long': long,
      };
}

class BalanceEnquiryResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? txnRefId;
  final String? transactionAmount;
  final String? aadhaarNo;
  final String? txnDateTime;
  final String? bankIIN;
  final String? rrn;
  final String? npciCode;
  final String? npciMessage;
  final String? availableBalance;
  final String? pipe;
  final dynamic transactionId;

  BalanceEnquiryResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.txnRefId,
    this.transactionAmount,
    this.aadhaarNo,
    this.txnDateTime,
    this.bankIIN,
    this.rrn,
    this.npciCode,
    this.npciMessage,
    this.availableBalance,
    this.pipe,
    this.transactionId,
  });

  factory BalanceEnquiryResponse.fromJson(Map<String, dynamic> json) => BalanceEnquiryResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        txnRefId: json['txnRefId'] as String?,
        transactionAmount: json['transactionAmount'] as String?,
        aadhaarNo: json['aadhaarNo'] as String?,
        txnDateTime: json['txnDateTime'] as String?,
        bankIIN: json['bankIIN'] as String?,
        rrn: json['rrn'] as String?,
        npciCode: json['npciCode'] as String?,
        npciMessage: json['npciMessage'] as String?,
        availableBalance: json['availableBalance'] as String?,
        pipe: json['pipe'] as String?,
        transactionId: json['transactionId'],
      );
}

class MiniStatementRequest {
  final String bankCode;
  final String pidData;
  final String? accountType;
  final String? device;
  final String? aadhaarNo;
  final String? mobileNo;
  final String? pipe;
  final String? lat;
  final String? long;

  MiniStatementRequest({
    required this.bankCode,
    required this.pidData,
    this.accountType,
    this.device,
    this.aadhaarNo,
    this.mobileNo,
    this.pipe,
    this.lat,
    this.long,
  });

  Map<String, dynamic> toJson() => {
        'bankCode': bankCode,
        'pidData': pidData,
        'accountType': accountType,
        'device': device,
        'aadhaarNo': aadhaarNo,
        'mobileNo': mobileNo,
        'pipe': pipe,
        'lat': lat,
        'long': long,
      };
}

class MiniStatementResponse {
  final String status;
  final String? merchantStatus;
  final String statusDescription;
  final String? txnRefId;
  final String? transactionAmount;
  final List<dynamic>? transactionList;
  final String? aadhaarNo;
  final String? availableBalance;
  final String? npciCode;
  final String? npciMessage;
  final dynamic transactionId;
  final String? pipe;
  final String? deviceUsed;

  MiniStatementResponse({
    required this.status,
    this.merchantStatus,
    required this.statusDescription,
    this.txnRefId,
    this.transactionAmount,
    this.transactionList,
    this.aadhaarNo,
    this.availableBalance,
    this.npciCode,
    this.npciMessage,
    this.transactionId,
    this.pipe,
    this.deviceUsed,
  });

  factory MiniStatementResponse.fromJson(Map<String, dynamic> json) => MiniStatementResponse(
        status: json['status'] as String,
        merchantStatus: json['merchantStatus'] as String?,
        statusDescription: json['statusDescription'] as String,
        txnRefId: json['txnRefId'] as String?,
        transactionAmount: json['transactionAmount'] as String?,
        transactionList: json['transactionList'] as List<dynamic>?,
        aadhaarNo: json['aadhaarNo'] as String?,
        availableBalance: json['availableBalance'] as String?,
        npciCode: json['npciCode'] as String?,
        npciMessage: json['npciMessage'] as String?,
        transactionId: json['transactionId'],
        pipe: json['pipe'] as String?,
        deviceUsed: json['device_used'] as String?,
      );
}

class AepsTransaction {
  final int id;
  final String txnType;
  final int? amount;
  final String aadhaarLast4;
  final String? bankIin;
  final String? bankName;
  final String? rrn;
  final String? npciCode;
  final String? npciMessage;
  final String status;
  final String provider;
  final String? deviceUsed;
  final DateTime createdAt;
  final String? pipe;

  AepsTransaction({
    required this.id,
    required this.txnType,
    this.amount,
    required this.aadhaarLast4,
    this.bankIin,
    this.bankName,
    this.rrn,
    this.npciCode,
    this.npciMessage,
    required this.status,
    required this.provider,
    this.deviceUsed,
    required this.createdAt,
    this.pipe,
  });

  factory AepsTransaction.fromJson(Map<String, dynamic> json) => AepsTransaction(
        id: json['id'] as int,
        txnType: json['txn_type'] as String,
        amount: json['amount'] as int?,
        aadhaarLast4: json['aadhaar_last4'] as String,
        bankIin: json['bank_iin'] as String?,
        bankName: json['bank_name'] as String?,
        rrn: json['rrn'] as String?,
        npciCode: json['npci_code'] as String?,
        npciMessage: json['npci_message'] as String?,
        status: json['status'] as String,
        provider: json['provider'] as String,
        deviceUsed: json['device_used'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        pipe: json['pipe'] as String?,
      );
}

class AepsWalletBalance {
  final double balance;
  final String status;

  AepsWalletBalance({required this.balance, required this.status});

  factory AepsWalletBalance.fromJson(Map<String, dynamic> json) => AepsWalletBalance(
        balance: (json['balance'] as num).toDouble(),
        status: json['status'] as String,
      );
}

class AepsLedgerEntry {
  final int id;
  final String transactionType;
  final double amount;
  final double balanceAfter;
  final String description;
  final String? referenceId;
  final int? performedBy;
  final DateTime createdAt;

  AepsLedgerEntry({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.referenceId,
    this.performedBy,
    required this.createdAt,
  });

  factory AepsLedgerEntry.fromJson(Map<String, dynamic> json) => AepsLedgerEntry(
        id: json['id'] as int,
        transactionType: json['transaction_type'] as String,
        amount: (json['amount'] as num).toDouble(),
        balanceAfter: (json['balance_after'] as num).toDouble(),
        description: json['description'] as String,
        referenceId: json['reference_id'] as String?,
        performedBy: json['performed_by'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class MoveToMainRequest {
  final double amount;

  MoveToMainRequest({required this.amount});

  Map<String, dynamic> toJson() => {'amount': amount};
}

class MoveToMainResponse {
  final bool success;
  final double aepsBalance;
  final double mainBalance;

  MoveToMainResponse({
    required this.success,
    required this.aepsBalance,
    required this.mainBalance,
  });

  factory MoveToMainResponse.fromJson(Map<String, dynamic> json) => MoveToMainResponse(
        success: json['success'] as bool,
        aepsBalance: (json['aepsBalance'] as num).toDouble(),
        mainBalance: (json['mainBalance'] as num).toDouble(),
      );
}

class AdminMerchant {
  final int id;
  final int userId;
  final String? merchantId;
  final String registrationStatus;
  final String? stateCode;
  final String? districtCode;
  final String? shopAddress;
  final String? registeredAt;
  final String? pipe;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final Map<String, dynamic>? user;

  AdminMerchant({
    required this.id,
    required this.userId,
    this.merchantId,
    required this.registrationStatus,
    this.stateCode,
    this.districtCode,
    this.shopAddress,
    this.registeredAt,
    this.pipe,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.user,
  });

  factory AdminMerchant.fromJson(Map<String, dynamic> json) => AdminMerchant(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        merchantId: json['merchant_id'] as String?,
        registrationStatus: json['registration_status'] as String,
        stateCode: json['state_code'] as String?,
        districtCode: json['district_code'] as String?,
        shopAddress: json['shop_address'] as String?,
        registeredAt: json['registered_at'] as String?,
        pipe: json['pipe'] as String?,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        user: json['user'] as Map<String, dynamic>?,
      );
}

class AdminTransaction {
  final int id;
  final int userId;
  final String txnType;
  final double amount;
  final String? aadhaarLast4;
  final String? bankName;
  final String? rrn;
  final String? npciCode;
  final String status;
  final String? deviceUsed;
  final DateTime createdAt;
  final String? pipe;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final Map<String, dynamic>? user;

  AdminTransaction({
    required this.id,
    required this.userId,
    required this.txnType,
    required this.amount,
    this.aadhaarLast4,
    this.bankName,
    this.rrn,
    this.npciCode,
    required this.status,
    this.deviceUsed,
    required this.createdAt,
    this.pipe,
    this.firstName,
    this.lastName,
    this.phone,
    this.user,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) => AdminTransaction(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        txnType: json['txn_type'] as String,
        amount: (json['amount'] as num).toDouble(),
        aadhaarLast4: json['aadhaar_last4'] as String?,
        bankName: json['bank_name'] as String?,
        rrn: json['rrn'] as String?,
        npciCode: json['npci_code'] as String?,
        status: json['status'] as String,
        deviceUsed: json['device_used'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        pipe: json['pipe'] as String?,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        phone: json['phone'] as String?,
        user: json['user'] as Map<String, dynamic>?,
      );
}

class AdminWallet {
  final int id;
  final int userId;
  final double balance;
  final String status;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final Map<String, dynamic>? user;

  AdminWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.status,
    this.firstName,
    this.lastName,
    this.phone,
    this.user,
  });

  factory AdminWallet.fromJson(Map<String, dynamic> json) => AdminWallet(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        balance: (json['balance'] as num).toDouble(),
        status: json['status'] as String,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        phone: json['phone'] as String?,
        user: json['user'] as Map<String, dynamic>?,
      );
}

class AepsReceiptData {
  final int id;
  final String txnType;
  final double? amount;
  final String status;
  final String? rrn;
  final String? bankIin;
  final String? bankName;
  final String? aadhaarLast4;
  final String? npciCode;
  final String? npciMessage;
  final dynamic availableBalance;
  final List<dynamic>? transactionList;
  final DateTime createdAt;
  final String? txnDateTime;
  final String? statusDescription;
  final String? deviceUsed;
  final String? pipe;
  final String? firstName;
  final String? lastName;
  final String? agentPhone;
  final String? agentEmail;
  final String? shopAddress;
  final String? shopPincode;
  final String? stateCode;
  final String? districtCode;
  final String? merchantId;
  final String? merchantRefId;
  final String? shopName;
  final String? merchantAddress;
  final String? merchantPhone;

  AepsReceiptData({
    required this.id,
    required this.txnType,
    this.amount,
    required this.status,
    this.rrn,
    this.bankIin,
    this.bankName,
    this.aadhaarLast4,
    this.npciCode,
    this.npciMessage,
    this.availableBalance,
    this.transactionList,
    required this.createdAt,
    this.txnDateTime,
    this.statusDescription,
    this.deviceUsed,
    this.pipe,
    this.firstName,
    this.lastName,
    this.agentPhone,
    this.agentEmail,
    this.shopAddress,
    this.shopPincode,
    this.stateCode,
    this.districtCode,
    this.merchantId,
    this.merchantRefId,
    this.shopName,
    this.merchantAddress,
    this.merchantPhone,
  });

  factory AepsReceiptData.fromJson(Map<String, dynamic> json) => AepsReceiptData(
        id: json['id'] as int,
        txnType: json['txn_type'] as String,
        amount: (json['amount'] as num?)?.toDouble(),
        status: json['status'] as String,
        rrn: json['rrn'] as String?,
        bankIin: json['bank_iin'] as String?,
        bankName: json['bank_name'] as String?,
        aadhaarLast4: json['aadhaar_last4'] as String?,
        npciCode: json['npci_code'] as String?,
        npciMessage: json['npci_message'] as String?,
        availableBalance: json['available_balance'],
        transactionList: json['transactionList'] as List<dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
        txnDateTime: json['txnDateTime'] as String?,
        statusDescription: json['statusDescription'] as String?,
        deviceUsed: json['device_used'] as String?,
        pipe: json['pipe'] as String?,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        agentPhone: json['agent_phone'] as String?,
        agentEmail: json['agent_email'] as String?,
        shopAddress: json['shop_address'] as String?,
        shopPincode: json['shop_pincode'] as String?,
        stateCode: json['state_code'] as String?,
        districtCode: json['district_code'] as String?,
        merchantId: json['merchant_id'] as String?,
        merchantRefId: json['merchant_ref_id'] as String?,
        shopName: json['shop_name'] as String?,
        merchantAddress: json['merchant_address'] as String?,
        merchantPhone: json['merchant_phone'] as String?,
      );
}

class AdminWalletsResponse {
  final List<AdminWallet> wallets;
  final int total;

  AdminWalletsResponse({required this.wallets, required this.total});

  factory AdminWalletsResponse.fromJson(Map<String, dynamic> json) => AdminWalletsResponse(
        wallets: (json['wallets'] as List).map((e) => AdminWallet.fromJson(e)).toList(),
        total: json['total'] as int,
      );
}

// ==============================
// Service Class
// ==============================

class AepsService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AepsService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.myneofyn.com/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    // ✅ Add interceptor to inject Authorization header
    _dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        print('🔑 AepsService interceptor: token = ${token != null ? 'present (${token.substring(0, min(10, token.length))}...)' : 'null'}');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('✅ Added Authorization header');
        } else {
          print('❌ No token found in secure storage (key: jwt_token)');
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        print('❌ Dio error: ${error.message}');
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'jwt_token');
        }
        return handler.next(error);
      },
    ),
  );
}


  // Helper to handle errors and extract data
  Future<T> _handleResponse<T>(Future<Response> request, T Function(dynamic) fromJson) async {
    try {
      final response = await request;

      // ✅ ADD THIS: Log the full response
      print('📦 Raw response data type: ${response.data.runtimeType}');
      print('📦 Raw response data: ${response.data}');

      // ✅ Check if response.data is null or empty
      if (response.data == null) {
        throw Exception('Server returned empty response');
      }

      return fromJson(response.data);
    } on DioException catch (e) {
      // ✅ Better error handling
      print('❌ Dio error: ${e.type}');
      print('❌ Response status: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');

      final responseData = e.response?.data;
      String message;

      if (responseData is Map) {
        message = (responseData['message'] as String?) ??
            (responseData['statusDescription'] as String?) ??
            (responseData['error'] as String?) ??
            'Request failed';
      } else {
        message = e.message ?? 'Request failed';
      }

      throw Exception(message);
    } catch (e) {
      print('❌ Unexpected error: $e');
      rethrow;
    }
  }
  /*Future<T> _handleResponse<T>(Future<Response> request, T Function(dynamic) fromJson) async {
    try {
      final response = await request;
      // ✅ ADD THIS: Log the full response
      print('📦 Raw response data type: ${response.data.runtimeType}');
      print('📦 Raw response data: ${response.data}');
      return fromJson(response.data);
    } on DioError catch (e) {
      final serverMessage = e.response?.data['message'] ??
          e.response?.data['statusDescription'] ??
          e.response?.data['error'];
      final message = serverMessage ?? e.message;
      throw Exception(message);
    }
  }*/

  // ==============================
  // Merchant & Setup
  // ==============================

  Future<MerchantStatus> getMerchantStatus({String? pipe}) {
    return _handleResponse(
      _dio.get('/aeps/merchant/status${_buildPipeQuery(pipe)}'),
      (data) => MerchantStatus.fromJson(data),
    );
  }

  Future<RegisterMerchantResponse> registerMerchant(RegisterMerchantRequest data) {
    print('═══════════════════════════════════════════════════════');
    print('📤 AEPS SERVICE: registerMerchant');
    print('───────────────────────────────────────────────────────');
    print('📤 Request pipe: ${data.pipe}');

    final body = data.toJson();
    print('📤 Body before: ${jsonEncode(body)}');
    print('📤 Pipe in body: ${body["pipe"]}');

    // ✅ FORCE the correct pipe
    if (data.pipe != null && data.pipe!.isNotEmpty) {
      body['pipe'] = data.pipe;
      print('✅ Forced pipe to: ${data.pipe}');
    }

    print('📤 Body after: ${jsonEncode(body)}');
    print('═══════════════════════════════════════════════════════');

    return _handleResponse(
      _dio.post('/aeps/merchant/register', data: body),
          (responseData) => RegisterMerchantResponse.fromJson(responseData),
    );
  }

  Future<List<Bank>> getBanks() {
    return _handleResponse(
      _dio.get('/aeps/banks'),
      (data) => (data as List).map((e) => Bank.fromJson(e)).toList(),
    );
  }

  Future<List<State>> getStates() {
    return _handleResponse(
      _dio.get('/aeps/states'),
      (data) => (data as List).map((e) => State.fromJson(e)).toList(),
    );
  }

  Future<List<District>> getDistricts(String stateCode) {
    return _handleResponse(
      _dio.post('/aeps/districts', data: {'stateCode': stateCode}),
      (data) => (data as List).map((e) => District.fromJson(e)).toList(),
    );
  }

  // ==============================
  // Bank IIN
  // ==============================

  Future<List<BankIIN>> getBankIINs({String? pipe}) {
    return _handleResponse(
      _dio.get('/aeps/bank-iins${_buildPipeQuery(pipe)}'),
      (data) => (data as List).map((e) => BankIIN.fromJson(e)).toList(),
    );
  }

  // ==============================
  // OTP
  // ==============================

  Future<OtpResponse> sendOTP(OtpRequest data) {
    return _handleResponse(
      _dio.post('/aeps/merchant/send-otp', data: data.toJson()),
      (data) => OtpResponse.fromJson(data),
    );
  }

  Future<OtpResponse> resendOTP(OtpRequest data) {
    return _handleResponse(
      _dio.post('/aeps/merchant/resend-otp', data: data.toJson()),
      (data) => OtpResponse.fromJson(data),
    );
  }

  Future<OtpResponse> verifyOTP(VerifyOtpRequest data) {
    return _handleResponse(
      _dio.post('/aeps/merchant/verify-otp', data: data.toJson()),
      (data) => OtpResponse.fromJson(data),
    );
  }

  // ==============================
  // E‑KYC
  // ==============================

  Future<MerchantEkycResponse> merchantEkyc(MerchantEkycRequest data) {
    return _handleResponse(
      _dio.post('/aeps/merchant/ekyc', data: data.toJson()),
      (data) => MerchantEkycResponse.fromJson(data),
    );
  }

  // ==============================
  // Daily 2FA
  // ==============================

  Future<Perform2FAResponse> perform2FA(Perform2FARequest data) {
    return _handleResponse(
      _dio.post('/aeps/2fa', data: data.toJson()),
      (data) => Perform2FAResponse.fromJson(data),
    );
  }

  // ==============================
  // Transactions
  // ==============================

  Future<CashWithdrawalResponse> cashWithdrawal(CashWithdrawalRequest data) {
    return _handleResponse(
      _dio.post('/aeps/cash-withdrawal', data: data.toJson()),
      (data) => CashWithdrawalResponse.fromJson(data),
    );
  }

  Future<CashWithdrawalResponse> cashDeposit(CashDepositRequest data) {
    return _handleResponse(
      _dio.post('/aeps/cash-deposit', data: data.toJson()),
      (data) => CashWithdrawalResponse.fromJson(data),
    );
  }

  Future<BalanceEnquiryResponse> balanceEnquiry(BalanceEnquiryRequest data) {
    return _handleResponse(
      _dio.post('/aeps/balance-enquiry', data: data.toJson()),
      (data) => BalanceEnquiryResponse.fromJson(data),
    );
  }

  Future<MiniStatementResponse> miniStatement(MiniStatementRequest data) {
    return _handleResponse(
      _dio.post('/aeps/mini-statement', data: data.toJson()),
      (data) => MiniStatementResponse.fromJson(data),
    );
  }

  Future<List<AepsTransaction>> getTransactions({String? pipe}) {
    return _handleResponse(
      _dio.get('/aeps/transactions${_buildPipeQuery(pipe)}'),
      (data) => (data as List).map((e) => AepsTransaction.fromJson(e)).toList(),
    );
  }

  // ==============================
  // Receipt
  // ==============================

  Future<AepsReceiptData> getAepsReceipt(String id) {
    return _handleResponse(
      _dio.get('/receipt/aeps/$id'),
      (data) => AepsReceiptData.fromJson(data['receipt']),
    );
  }

  // ==============================
  // Wallet
  // ==============================

  Future<double> getAepsBalance({String? pipe}) {
    return _handleResponse(
      _dio.get('/aeps/wallet/balance${_buildPipeQuery(pipe)}'),
      (data) => (data['balance'] as num).toDouble(),
    );
  }

  Future<List<AepsLedgerEntry>> getAepsLedger({int? limit, int? offset}) {
    final params = <String, dynamic>{};
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    return _handleResponse(
      _dio.get('/aeps/wallet/ledger', queryParameters: params),
      (data) => (data as List).map((e) => AepsLedgerEntry.fromJson(e)).toList(),
    );
  }

  Future<MoveToMainResponse> moveToMain(double amount) {
    return _handleResponse(
      _dio.post('/aeps/move-to-main', data: {'amount': amount}),
      (data) => MoveToMainResponse.fromJson(data),
    );
  }

  // ==============================
  // Admin Endpoints (READ ONLY)
  // ==============================

  Future<List<AdminMerchant>> adminGetMerchants() {
    return _handleResponse(
      _dio.get('/aeps/admin/merchants'),
      (data) => (data as List).map((e) => AdminMerchant.fromJson(e)).toList(),
    );
  }

  Future<List<AdminTransaction>> adminGetTransactions({
    String? status,
    String? type,
    String? from,
    String? to,
  }) {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (type != null) params['type'] = type;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _handleResponse(
      _dio.get('/aeps/admin/transactions', queryParameters: params),
      (data) => (data as List).map((e) => AdminTransaction.fromJson(e)).toList(),
    );
  }

  Future<AdminWalletsResponse> adminGetWallets({int? limit, int? offset}) {
    final params = <String, dynamic>{};
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    return _handleResponse(
      _dio.get('/aeps/admin/wallets', queryParameters: params),
      (data) => AdminWalletsResponse.fromJson(data),
    );
  }
}