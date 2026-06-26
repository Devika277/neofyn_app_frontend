// lib/features/merchant/models/onboarding_data.dart

class OnboardingData {
  final String? id;
  final String? userId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? dob;
  final String? email;
  final String? mobile;
  final String? address;
  final String? place;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final String? aadharNo;
  final String? panNo;
  final String? bankName;
  final String? accountNo;
  final String? ifscCode;
  final String? shopName;
  final String? shopAddress;
  final String? shopCity;
  final String? shopDistrict;
  final String? shopState;
  final String? shopPincode;
  final String? businessType;
  final String? status;

  OnboardingData({
    this.id,
    this.userId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.dob,
    this.email,
    this.mobile,
    this.address,
    this.place,
    this.city,
    this.district,
    this.state,
    this.pincode,
    this.aadharNo,
    this.panNo,
    this.bankName,
    this.accountNo,
    this.ifscCode,
    this.shopName,
    this.shopAddress,
    this.shopCity,
    this.shopDistrict,
    this.shopState,
    this.shopPincode,
    this.businessType,
    this.status,
  });

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      dob: json['dob'],
      email: json['email'],
      mobile: json['mobile'],
      address: json['address'],
      place: json['place'],
      city: json['city'],
      district: json['district'],
      state: json['state'],
      pincode: json['pincode']?.toString(),
      aadharNo: json['aadhar_no'],
      panNo: json['pan_no'],
      bankName: json['bank_name'],
      accountNo: json['account_no'],
      ifscCode: json['ifsc_code'],
      shopName: json['shop_name'],
      shopAddress: json['shop_address'],
      shopCity: json['shop_city'],
      shopDistrict: json['shop_district'],
      shopState: json['shop_state'],
      shopPincode: json['shop_pincode']?.toString(),
      businessType: json['business_type'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'dob': dob,
      'email': email,
      'mobile': mobile,
      'address': address,
      'place': place,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'aadhar_no': aadharNo,
      'pan_no': panNo,
      'bank_name': bankName,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_city': shopCity,
      'shop_district': shopDistrict,
      'shop_state': shopState,
      'shop_pincode': shopPincode,
      'business_type': businessType,
      'status': status,
    };
  }
}