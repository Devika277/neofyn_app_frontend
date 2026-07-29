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
  // Base path - matches server mounting
  static const String cardPayBase = '/api/cardpay';
  
  // User Routes (Protected)
  static const String cardPayInitiate = '$cardPayBase/initiate';
  static const String cardPayStates = '$cardPayBase/states';
  static const String cardPayStatus = '$cardPayBase/status';
  static const String cardPayReceipt = '$cardPayBase/receipt';
  static const String cardPayWalletBalance = '$cardPayBase/wallet/balance';
  static const String cardPayWalletLedger = '$cardPayBase/wallet/ledger';
  static const String cardPayMoveToMain = '$cardPayBase/move-to-main';
  static const String cardPayBalance = '$cardPayBase/balance';
  static const String cardPayHistory = '$cardPayBase/history';
  
  // Public Route (No Auth)
  static const String cardPayCallback = '$cardPayBase/callback';
  
  // Admin Routes
  static const String cardPayAdminDashboard = '$cardPayBase/admin/dashboard';
  static const String cardPayAdminTransactions = '$cardPayBase/admin/transactions';
  static const String cardPayAdminExport = '$cardPayBase/admin/reports/export';
  static const String cardPayAdminUsersBalances = '$cardPayBase/admin/wallet/users';
  static const String cardPayAdminLedger = '$cardPayBase/admin/wallet/ledger';
  static const String cardPayAdminConfig = '$cardPayBase/admin/config';
  
    // ========== CARDPAY-OUT ENDPOINTS ==========
  static const String cardPayOutBase = '/api/cardpay-out';
  
  // User Routes
  static const String cardPayOutBeneficiaries = '$cardPayOutBase/beneficiaries';
  static const String cardPayOutBalance = '$cardPayOutBase/balance';
  static const String cardPayOutLimits = '$cardPayOutBase/limits';
  static const String cardPayOutInitiate = '$cardPayOutBase/initiate';
  static const String cardPayOutStatus = '$cardPayOutBase/status';
  static const String cardPayOutReceipt = '$cardPayOutBase/receipt';
  static const String cardPayOutHistory = '$cardPayOutBase/history';
  static const String cardPayOutCallback = '$cardPayOutBase/callback';
  
    // ✅ Master Data Routes (from payout provider)
  static const String cardPayOutBanks = '$cardPayOutBase/banks';
  static const String cardPayOutStates = '$cardPayOutBase/states';
  // Admin Routes
  // static const String cardPayOutAdminDashboard = '$cardPayOutBase/admin/dashboard';
  // static const String cardPayOutAdminTransactions = '$cardPayOutBase/admin/transactions';
  // static const String cardPayOutAdminExport = '$cardPayOutBase/admin/reports/export';
  // static const String cardPayOutAdminConfig = '$cardPayOutBase/admin/config';
  
  
  // Headers
  static const String contentType = 'application/json';
  static const String userId = 'E5B82667-9A9D-4A5A-A55C-F3B1E10BF370'; // from backend .env

}