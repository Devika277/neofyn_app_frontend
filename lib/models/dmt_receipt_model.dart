// lib/models/dmt_receipt_model.dart
import 'package:intl/intl.dart';

class DmtReceiptModel {
  final String transactionId;
  final String utrNumber;
  final String amount;
  final String commission;
  final String status;
  final String transferMode;
  final String remitterName;
  final String remitterMobile;
  final String beneficiaryName;
  final String accountNumber;
  final String bankName;
  final String ifscCode;
  final String beneficiaryMobile;
  final String remark;
  final String failureReason;
  final DateTime transactionDate;
  final String merchantName;
  final String retailerId;

  DmtReceiptModel({
    required this.transactionId,
    required this.utrNumber,
    required this.amount,
    this.commission = '',
    required this.status,
    this.transferMode = '',
    required this.remitterName,
    this.remitterMobile = '',
    required this.beneficiaryName,
    required this.accountNumber,
    required this.bankName,
    this.ifscCode = '',
    this.beneficiaryMobile = '',
    this.remark = '',
    this.failureReason = '',
    required this.transactionDate,
    this.merchantName = 'NEOFYN Bharath',
    this.retailerId = '',
  });

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate);
  String get formattedDateShort => DateFormat('dd/MM/yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm:ss a').format(transactionDate);
}

// lib/models/dmt_receipt_model.dart
// Placeholder - create the actual model file