// lib/models/bank_account.dart
class BankAccount {
  final String id;
  final String name;
  final String accountNumber;
  final String ifsc;
  final String accountName;
  final String? accountType;
  final bool isActive;

  BankAccount({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.ifsc,
    required this.accountName,
    this.accountType,
    required this.isActive,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id']?.toString() ?? '',
      name: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifsc: json['ifsc_code'] ?? '',
      accountName: json['account_name'] ?? 'Company Name',
      accountType: json['account_type'] ?? 'Current Account',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': name,
      'account_number': accountNumber,
      'ifsc_code': ifsc,
      'account_name': accountName,
      'account_type': accountType,
      'is_active': isActive,
    };
  }
}