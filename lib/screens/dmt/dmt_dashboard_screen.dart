// lib/screens/dmt/dmt_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';
import 'dmt_add_beneficiary_screen.dart';
import 'dmt_beneficiary_list_screen.dart';
import 'dmt_transfer_screen.dart';
import 'dmt_transactions_screen.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color darkCard = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color verified = Color(0xFF10B981);
  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class DMTDashboardScreen extends StatefulWidget {
  final int remitterId;
  final String productType;
  const DMTDashboardScreen({Key? key, required this.remitterId, required this.productType}) : super(key: key);
  @override
  State<DMTDashboardScreen> createState() => _DMTDashboardScreenState();
}

class _DMTDashboardScreenState extends State<DMTDashboardScreen> {
  final ApiService _apiService = ApiService();
  Remitter? _remitter;
  List<Beneficiary> _beneficiaries = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh) { setState(() => _isRefreshing = true); } else { setState(() { _isLoading = true; _errorMessage = null; }); }
    try {
      final response = await _apiService.getRemitterDetailsRaw(widget.remitterId);
      final remitter = Remitter(
        id: response['id'] ?? 0, mobile: response['mobile']?.toString() ?? '',
        firstName: response['first_name']?.toString() ?? '', lastName: response['last_name']?.toString() ?? '',
        monthlyLimit: double.parse(response['monthly_limit']?.toString() ?? '0'),
        monthlyUsed: double.parse(response['monthly_used']?.toString() ?? '0'),
        productType: response['product_type']?.toString() ?? 'lite',
        isActive: response['is_active'] ?? false, kycStatus: response['kyc_status']?.toString() ?? 'basic',
      );
      final beneficiaries = await _apiService.getBeneficiaries(widget.remitterId);
      if (mounted) { setState(() { _remitter = remitter; _beneficiaries = beneficiaries; _isLoading = false; _isRefreshing = false; }); }
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; _isRefreshing = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('Money Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
        actions: [
          Container(margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: IconButton(icon: Icon(_isRefreshing ? Iconsax.refresh_circle : Iconsax.refresh, color: AppColors.textWhite, size: 20), onPressed: () => _loadData(isRefresh: true), tooltip: 'Refresh'),
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _errorMessage != null ? _buildErrorState() : _remitter == null ? _buildEmptyState() :
      RefreshIndicator(
        onRefresh: () => _loadData(isRefresh: true), color: AppColors.primary, backgroundColor: AppColors.darkSurface,
        child: SingleChildScrollView(padding: const EdgeInsets.all(20), physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildRemitterCard(), const SizedBox(height: 20),
            _buildQuickActions(), const SizedBox(height: 20),
            _buildBeneficiariesSummary(), const SizedBox(height: 20),
            _buildRecentTransactions(), const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: AppColors.primaryLight), const SizedBox(height: 20), Text('Loading dashboard...', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary))]));
  Widget _buildErrorState() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.warning_2, size: 56, color: AppColors.error.withOpacity(0.7))),
    const SizedBox(height: 20), Text('Something went wrong', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
    const SizedBox(height: 8), Text(_errorMessage!, style: GoogleFonts.poppins(color: AppColors.textDarkSecondary, fontSize: 14), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
      child: ElevatedButton.icon(onPressed: () => _loadData(), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)), icon: const Icon(Iconsax.refresh, color: Colors.white, size: 18), label: Text('Try Again', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
    ),
  ])));
  Widget _buildEmptyState() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.user_octagon, size: 64, color: AppColors.primary.withOpacity(0.6))),
    const SizedBox(height: 20), Text('No Remitter Found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
  ])));

  Widget _buildRemitterCard() {
    final usagePercent = _remitter!.usagePercentage;
    final remainingLimit = _remitter!.remainingLimit;
    final isHighUsage = usagePercent > 80;
    final initials = '${_remitter!.firstName.isNotEmpty ? _remitter!.firstName[0] : ''}${_remitter!.lastName.isNotEmpty ? _remitter!.lastName[0] : ''}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(initials, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_remitter!.firstName} ${_remitter!.lastName}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [const Icon(Iconsax.call, size: 12, color: Colors.white70), const SizedBox(width: 4), Text('+91 ${_remitter!.mobile}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withOpacity(0.8)))]),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_remitter!.productType == 'lite' ? Iconsax.wallet_3 : Iconsax.crown, size: 14, color: Colors.white), const SizedBox(width: 4), Text(_remitter!.productType.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5))])),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _buildLimitItem(label: 'Monthly Limit', amount: '₹${_remitter!.monthlyLimit.toStringAsFixed(0)}', icon: Iconsax.chart_square)),
          const SizedBox(width: 12),
          Expanded(child: _buildLimitItem(label: 'Remaining', amount: '₹${remainingLimit.toStringAsFixed(0)}', icon: Iconsax.wallet_money, isRemaining: true)),
          const SizedBox(width: 12),
          Expanded(child: _buildLimitItem(label: 'Used', amount: '₹${_remitter!.monthlyUsed.toStringAsFixed(0)}', icon: Iconsax.activity)),
        ]),
        const SizedBox(height: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Monthly Usage', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)), Text('${usagePercent.toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: isHighUsage ? AppColors.warning : Colors.white))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearPercentIndicator(percent: usagePercent / 100, progressColor: isHighUsage ? AppColors.warning : Colors.white, backgroundColor: Colors.white.withOpacity(0.25), barRadius: const Radius.circular(20), padding: EdgeInsets.zero, lineHeight: 8, animation: true, animationDuration: 1000)),
          const SizedBox(height: 8),
          Text('₹${_remitter!.monthlyUsed.toStringAsFixed(0)} of ₹${_remitter!.monthlyLimit.toStringAsFixed(0)} used', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.6))),
        ]),
        if (_remitter!.kycStatus != 'verified') ...[
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Iconsax.shield_cross, color: AppColors.warning, size: 16)),
                const SizedBox(width: 10),
                Expanded(child: Text('Complete KYC to increase your transfer limits', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500))),
                const Icon(Iconsax.arrow_right_3, color: AppColors.warning, size: 16),
              ])),
        ],
      ]),
    );
  }

  Widget _buildLimitItem({required String label, required String amount, required IconData icon, bool isRemaining = false}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 12, color: Colors.white)), const SizedBox(width: 6), Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 6),
        Text(amount, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: isRemaining ? AppColors.primaryLight : Colors.white), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Text('Quick Actions', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textWhite))]),
        const SizedBox(height: 20),
        Row(children: [
          _buildActionButton(icon: Iconsax.user_add, label: 'Add\nBeneficiary', color: AppColors.primaryLight, onTap: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => DMTAddBeneficiaryScreen(remitterId: widget.remitterId))).then((_) => _loadData()); }),
          const SizedBox(width: 10),
          _buildActionButton(icon: Iconsax.send_2, label: 'Send\nMoney', color: AppColors.primary, onTap: () { HapticFeedback.mediumImpact(); if (_beneficiaries.isEmpty) { _showSnackbar('Please add a beneficiary first', isError: true); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => DMTTransferScreen(remitterId: widget.remitterId, beneficiaries: _beneficiaries, productType: widget.productType))).then((_) => _loadData()); }),
          const SizedBox(width: 10),
          _buildActionButton(icon: Iconsax.people, label: 'Benefi-\nciaries', color: const Color(0xFF6366F1), onTap: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => DMTBeneficiaryListScreen(remitterId: widget.remitterId, beneficiaries: _beneficiaries))).then((_) => _loadData()); }),
          const SizedBox(width: 10),
          _buildActionButton(icon: Iconsax.receipt_text, label: 'Transa-\nctions', color: AppColors.warning, onTap: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => DMTTransactionsScreen(remitterId: widget.remitterId))); }),
        ]),
      ]),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 8), Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textDarkSecondary, height: 1.3), textAlign: TextAlign.center)]))));
  }

  Widget _buildBeneficiariesSummary() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Text('Beneficiaries', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textWhite)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text('${_beneficiaries.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight)))]),
          if (_beneficiaries.isNotEmpty) TextButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DMTBeneficiaryListScreen(remitterId: widget.remitterId, beneficiaries: _beneficiaries))).then((_) => _loadData()); }, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)), child: Row(children: [Text('View All', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight)), const SizedBox(width: 4), Icon(Iconsax.arrow_right_3, size: 14, color: AppColors.primaryLight)])),
        ]),
        const SizedBox(height: 16),
        if (_beneficiaries.isEmpty) _buildEmptyBeneficiaries()
        else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _beneficiaries.length > 3 ? 3 : _beneficiaries.length, separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.05)), itemBuilder: (context, index) => _buildBeneficiaryItem(_beneficiaries[index])),
      ]),
    );
  }

  Widget _buildEmptyBeneficiaries() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.user_add, size: 32, color: AppColors.primary.withOpacity(0.6))),
        const SizedBox(height: 12), Text('No beneficiaries added yet', style: GoogleFonts.poppins(color: AppColors.textDarkSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4), Text('Add a beneficiary to start transferring money', style: GoogleFonts.poppins(color: AppColors.textDarkHint, fontSize: 12)),
        const SizedBox(height: 14),
        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
          child: InkWell(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DMTAddBeneficiaryScreen(remitterId: widget.remitterId))).then((_) => _loadData()); }, borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Iconsax.add, size: 16, color: AppColors.primaryLight), const SizedBox(width: 6), Text('Add Beneficiary', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight))])),
          ),
        ),
      ]),
    );
  }

  Widget _buildBeneficiaryItem(Beneficiary beneficiary) {
    final String maskedAccount = beneficiary.accountNumber.length >= 4 ? '••••${beneficiary.accountNumber.substring(beneficiary.accountNumber.length - 4)}' : beneficiary.accountNumber;
    return InkWell(onTap: () => HapticFeedback.selectionClick(), borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(beneficiary.accountHolderName.isNotEmpty ? beneficiary.accountHolderName[0].toUpperCase() : '?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryLight)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(beneficiary.accountHolderName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textWhite), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${beneficiary.bankName} • $maskedAccount', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkSecondary)),
        ])),
        if (beneficiary.verified)
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.verified.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.verified)), const SizedBox(width: 4), Text('Verified', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.verified))])),
        const SizedBox(width: 8),
        Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.textDarkHint),
      ])),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderDark)),
      child: InkWell(onTap: () { HapticFeedback.selectionClick(); Navigator.push(context, MaterialPageRoute(builder: (context) => DMTTransactionsScreen(remitterId: widget.remitterId))); }, borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Text('Transaction History', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textWhite))]),
          Row(children: [Text('View All', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight)), const SizedBox(width: 4), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Icon(Iconsax.arrow_right_3, size: 14, color: AppColors.primaryLight))]),
        ])),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(isError ? Iconsax.warning_2 : Iconsax.info_circle, color: Colors.white, size: 16)), const SizedBox(width: 12), Expanded(child: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)))]),
      backgroundColor: isError ? AppColors.error : AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
    ));
  }
}