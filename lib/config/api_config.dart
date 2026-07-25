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
  // static const String payoutPurposes = '/api/payout/purposes';
  static const String payoutStates = '/api/payout/states';
  static const String payoutInitiate = '/api/payout/initiate';
  static const String payoutStatus = '/api/payout/status';
  // static const String payoutBalance = '/api/payout/balance';


  // ========== CARDPAY ENDPOINTS ==========
  static const String cardPayBase = '/api/cardpay';
  static const String cardPayInitiate = '$cardPayBase/initiate';
  static const String cardPayStates = '$cardPayBase/states';
  static const String cardPayStatus = '$cardPayBase/status';
  static const String cardPayReceipt = '$cardPayBase/receipt';
  static const String cardPayWalletBalance = '$cardPayBase/wallet/balance';
  static const String cardPayWalletLedger = '$cardPayBase/wallet/ledger';
  static const String cardPayMoveToMain = '$cardPayBase/move-to-main';
  static const String cardPayBalance = '$cardPayBase/balance';
  static const String cardPayHistory = '$cardPayBase/history';
  static const String cardPayCallback = '$cardPayBase/callback';
  
  // CardPay Admin Endpoints
  static const String cardPayAdminDashboard = '$cardPayBase/admin/dashboard';
  static const String cardPayAdminTransactions = '$cardPayBase/admin/transactions';
  static const String cardPayAdminExport = '$cardPayBase/admin/export';
  static const String cardPayAdminUsersBalances = '$cardPayBase/admin/users/balances';
  static const String cardPayAdminLedger = '$cardPayBase/admin/ledger';
  static const String cardPayAdminConfig = '$cardPayBase/admin/config';

  // Headers
  static const String contentType = 'application/json';
  static const String userId = 'E5B82667-9A9D-4A5A-A55C-F3B1E10BF370'; // from backend .env

}