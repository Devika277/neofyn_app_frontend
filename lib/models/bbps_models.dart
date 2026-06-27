class MerchantOnboardingRequest {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String dob;
  final String? address;
  final String? state;
  final String? city;
  final String? resPincode;
  final String shopName;
  final String shopAddress;
  final String shopState;
  final String shopCity;
  final String pincode;
  final String businessType;
  final String? businessTypeOther;
  final String? aadharNo;
  final String? panNo;
  final String? bankName;
  final String? accountNo;
  final String? ifscCode;
  final String mobile;
  final String email;
  final double? latitude;
  final double? longitude;

  MerchantOnboardingRequest({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.dob,
    this.address,
    this.state,
    this.city,
    this.resPincode,
    required this.shopName,
    required this.shopAddress,
    required this.shopState,
    required this.shopCity,
    required this.pincode,
    required this.businessType,
    this.businessTypeOther,
    this.aadharNo,
    this.panNo,
    this.bankName,
    this.accountNo,
    this.ifscCode,
    required this.mobile,
    required this.email,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      'last_name': lastName,
      'dob': dob,
      'address': address,
      'state': state,
      'city': city,
      'pincode_res': resPincode,
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_state': shopState,
      'shop_city': shopCity,
      'pincode': pincode,
      'business_type': businessType,
      'business_type_other': businessTypeOther,
      'aadhar_no': aadharNo,
      'pan_no': panNo,
      'bank_name': bankName,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'mobile': mobile,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class OnboardingResponse {
  final bool success;
  final String? message;
  final OnboardingData? data;

  OnboardingResponse({required this.success, this.message, this.data});

  factory OnboardingResponse.fromJson(Map<String, dynamic> json) {
    return OnboardingResponse(
      success: json['success'],
      message: json['message'],
      data: json['data'] != null ? OnboardingData.fromJson(json['data']) : null,
    );
  }
}

class OnboardingData {
  final String status;
  final String? merchantCode;
  final int? onboardingId;
  final String? merchantName;

  OnboardingData({
    required this.status,
    this.merchantCode,
    this.onboardingId,
    this.merchantName,
  });

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      status: json['status'],
      merchantCode: json['merchantCode'],
      onboardingId: json['onboardingId'],
      merchantName: json['merchantName'],
    );
  }
}

class MerchantStatus {
  final int id;
  final int userId;
  final String status;
  final String? bbpsMerchantCode;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? shopName;
  final String? shopAddress;
  final String? shopState;
  final String? shopCity;
  final String? shopPincode;
  final String? businessType;
  final String? mobile;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? maskedAadhar;
  final String? maskedPan;
  final String? maskedAccount;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;

  MerchantStatus({
    required this.id,
    required this.userId,
    required this.status,
    this.bbpsMerchantCode,
    this.firstName,
    this.middleName,
    this.lastName,
    this.shopName,
    this.shopAddress,
    this.shopState,
    this.shopCity,
    this.shopPincode,
    this.businessType,
    this.mobile,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.maskedAadhar,
    this.maskedPan,
    this.maskedAccount,
    this.latitude,
    this.longitude,
    this.errorMessage,
  });

  factory MerchantStatus.fromJson(Map<String, dynamic> json) {
    return MerchantStatus(
      id: json['id'],
      userId: json['user_id'],
      status: json['status'],
      bbpsMerchantCode: json['bbps_merchant_code'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      shopName: json['shop_name'],
      shopAddress: json['shop_address'],
      shopState: json['shop_state'],
      shopCity: json['shop_city'],
      shopPincode: json['shop_pincode'],
      businessType: json['business_type'],
      mobile: json['mobile'],
      email: json['email'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      maskedAadhar: json['aadhar_no'],
      maskedPan: json['pan_no'],
      maskedAccount: json['account_no'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      errorMessage: json['error_message'],
    );
  }
}

// For BBPS dynamic data
class BBPSState {
  final String stateCode;
  final String stateName;

  BBPSState({required this.stateCode, required this.stateName});

  factory BBPSState.fromJson(Map<String, dynamic> json) {
    return BBPSState(
      // Your API uses 'code' and 'description'
      stateCode: json['code'] ?? '',
      stateName: json['description'] ?? '',
    );
  }

  // Add this to fix the "Instance of" printing issue
  @override
  String toString() {
    return 'BBPSState(code: $stateCode, name: $stateName)';
  }
}

class BBPScity {
  final String cityCode;
  final String cityName;

  BBPScity({required this.cityCode, required this.cityName});

  factory BBPScity.fromJson(Map<String, dynamic> json) {
    return BBPScity(
      cityCode: json['code'] ?? '',           // API uses 'code'
      cityName: json['description'] ?? '',     // API uses 'description'
    );
  }

  @override
  String toString() {
    return 'BBPScity(code: $cityCode, name: $cityName)';
  }
}

class BillerCategory {
  final String code;
  final String name;
  BillerCategory({required this.code, required this.name});
  factory BillerCategory.fromJson(Map<String, dynamic> json) {
  return BillerCategory(
    code: (json['Code'] ?? json['code'] ?? json['categoryCode'] ?? '').toString(),
    name: (json['description'] ?? json['name'] ?? json['categoryName'] ?? '').toString(),
  );
}
}

class BillerProvider {
  final String billerCode;
  final String billerName;
  final String? billerCategoryCode;
  BillerProvider({required this.billerCode, required this.billerName, this.billerCategoryCode});
  factory BillerProvider.fromJson(Map<String, dynamic> json) {
  return BillerProvider(
    billerCode: (json['Code'] ?? json['code'] ?? json['billerCode'] ?? '').toString(),
    billerName: (json['description'] ?? json['name'] ?? json['billerName'] ?? '').toString(),
    billerCategoryCode: json['billerCategoryCode']?.toString(),  // if returned
  );
}
}

// BillerDetails – keep as raw map because structure varies
typedef BillerDetails = Map<String, dynamic>;

// Fetch Bill Result
class FetchBillResult {
  final String fetchRefId;
  final String? billerId;
  final String? billerCode;
  final String? customerName;
  final double? amount;
  final DateTime? dueDate;
  final Map<String, dynamic> raw;

  FetchBillResult({
    required this.fetchRefId,
    this.billerId,
    this.billerCode,
    this.customerName,
    this.amount,
    this.dueDate,
    required this.raw,
  });

  factory FetchBillResult.fromJson(Map<String, dynamic> json) {
    return FetchBillResult(
      fetchRefId: json['fetchRefId'],
      billerId: json['billerId'],
      billerCode: json['billerCode'],
      customerName: json['customerName'],
      amount: json['amount'] != null ? (json['amount'] is String ? double.tryParse(json['amount']) : (json['amount'] as num).toDouble()) : null,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      raw: json,
    );
  }
}

class FetchBillResponse {
  final bool success;
  final String message;
  final int? transactionId;
  final FetchBillResult? fetchBillResult;

  FetchBillResponse({
    required this.success,
    required this.message,
    this.transactionId,
    this.fetchBillResult,
  });

  factory FetchBillResponse.fromJson(Map<String, dynamic> json) {
    return FetchBillResponse(
      success: json['success'],
      message: json['message'],
      transactionId: json['data']?['transactionId'],
      fetchBillResult: json['data']?['fetchBillResult'] != null
          ? FetchBillResult.fromJson(json['data']['fetchBillResult'])
          : null,
    );
  }
}

class PayBillResponse {
  final bool success;
  final String message;
  final int? transactionId;
  final String? providerTxnId;
  final bool refunded;

  PayBillResponse({
    required this.success,
    required this.message,
    this.transactionId,
    this.providerTxnId,
    this.refunded = false,
  });

  factory PayBillResponse.fromJson(Map<String, dynamic> json) {
    return PayBillResponse(
      success: json['success'],
      message: json['message'],
      transactionId: json['data']?['transactionId'],
      providerTxnId: json['data']?['provider'],
      refunded: json['data']?['refunded'] ?? false,
    );
  }
}

// Transaction for history
class Transaction {
  final int id;
  final String serviceType;
  final String consumerNumber;
  final double amount;
  final String status;
  final String? providerTxnId;
  final String? providerName;
  final DateTime? createdAt;

  Transaction({
    required this.id,
    required this.serviceType,
    required this.consumerNumber,
    required this.amount,
    required this.status,
    this.providerTxnId,
    this.providerName,
    this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      serviceType: json['service_type'] ?? json['type'] ?? '',
      consumerNumber: json['consumer_number'] ?? '',
      amount: json['amount'] != null ? (json['amount'] is String ? double.tryParse(json['amount'])! : (json['amount'] as num).toDouble()) : 0.0,
      status: json['status'],
      providerTxnId: json['provider_txn_id'],
      providerName: json['provider_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class PaymentServiceModel {
  final int id;
  final String name;
  final String displayName;
  final String category;
  final String? icon;

  PaymentServiceModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    this.icon,
  });

  factory PaymentServiceModel.fromJson(Map<String, dynamic> json) {
    return PaymentServiceModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'] ?? json['name'],
      category: json['category'] ?? '',
      icon: json['icon'],
    );
  }
}