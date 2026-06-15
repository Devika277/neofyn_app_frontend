class ApiConfig {
  // Change this to your actual backend IP/URL
  static const String baseUrl = 'https://api.myneofyn.com'; // Your Node.js server IP
  
  // AEPS Endpoints
  static const String aepsBanks = '/api/aeps/banks';
  static const String aepsStates = '/api/aeps/states';
  static const String aepsDistricts = '/api/aeps/districts';
  static const String merchantRegister = '/api/aeps/merchant/register';
  static const String sendOtp = '/api/aeps/merchant/send-otp';
  static const String verifyOtp = '/api/aeps/merchant/verify-otp';
  static const String twoFA = '/api/aeps/2fa';
  static const String aepsTransaction = '/api/aeps/transaction';
  static const String transactionStatus = '/api/aeps/transaction/status';
  
 // ========== PAYOUT ENDPOINTS ==========
  static const String payoutBanks = '/api/payout/banks';
  static const String payoutPurposes = '/api/payout/purposes';
  static const String payoutStates = '/api/payout/states';
  static const String payoutInitiate = '/api/payout/initiate';
  static const String payoutStatus = '/api/payout/status';
  // static const String payoutBalance = '/api/payout/balance';



  // Headers
  static const String contentType = 'application/json';
  static const String userId = 'E5B82667-9A9D-4A5A-A55C-F3B1E10BF370'; // from backend .env

}