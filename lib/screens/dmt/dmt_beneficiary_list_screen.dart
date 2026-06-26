// lib/screens/dmt/dmt_beneficiary_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';
import 'dmt_add_beneficiary_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);

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

class DMTBeneficiaryListScreen extends StatefulWidget {
  final int remitterId;
  final List<Beneficiary> beneficiaries;

  const DMTBeneficiaryListScreen({
    Key? key,
    required this.remitterId,
    required this.beneficiaries,
  }) : super(key: key);

  @override
  State<DMTBeneficiaryListScreen> createState() => _DMTBeneficiaryListScreenState();
}

class _DMTBeneficiaryListScreenState extends State<DMTBeneficiaryListScreen> {
  final ApiService _apiService = ApiService();
  List<Beneficiary> _beneficiaries = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _beneficiaries = widget.beneficiaries;
  }

  List<Beneficiary> get _filteredBeneficiaries {
    if (_searchQuery.isEmpty) return _beneficiaries;
    return _beneficiaries.where((b) {
      return b.accountHolderName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.bankName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.accountNumber.contains(_searchQuery);
    }).toList();
  }

  Future<void> _deleteBeneficiary(int id) async {
    HapticFeedback.mediumImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Iconsax.trash, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Beneficiary',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this beneficiary? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDarkSecondary,
                    side: const BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.deleteBeneficiary(id);
      setState(() => _beneficiaries.removeWhere((b) => b.id == id));

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check_circle, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Text('Beneficiary deleted successfully', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.error_outline, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(e.toString().replaceFirst('Exception: ', ''), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500))),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToAddBeneficiary() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DMTAddBeneficiaryScreen(remitterId: widget.remitterId)),
    );
    if (result == true && mounted) {
      _showToast('Refresh the page to see new beneficiary');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredBeneficiaries;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('Beneficiaries', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: IconButton(icon: const Icon(Iconsax.add, color: AppColors.textWhite, size: 20), onPressed: _navigateToAddBeneficiary, tooltip: 'Add Beneficiary'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddBeneficiary,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Iconsax.add, size: 18),
        label: Text('Add Beneficiary', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      body: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: AppColors.primaryLight), const SizedBox(height: 16), Text('Please wait...', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary))]))
          : _beneficiaries.isEmpty
          ? _buildEmptyState()
          : filteredList.isEmpty
          ? _buildNoResultsState()
          : Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBeneficiaryList(filteredList)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search by name, bank, or account',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
            prefixIcon: const Icon(Iconsax.search_normal, color: Colors.white38, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Iconsax.close_circle, color: Colors.white38, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.user_add, size: 64, color: AppColors.primary.withOpacity(0.6))),
            const SizedBox(height: 24),
            Text('No Beneficiaries Yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
            const SizedBox(height: 8),
            Text('Add a beneficiary to start transferring money instantly', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary, height: 1.5)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: ElevatedButton.icon(
                onPressed: _navigateToAddBeneficiary,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Iconsax.add, color: Colors.white, size: 20),
                label: Text('Add First Beneficiary', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.search_normal, size: 48, color: AppColors.warning.withOpacity(0.6))),
            const SizedBox(height: 20),
            Text('No Results Found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
            const SizedBox(height: 8),
            Text('Try adjusting your search query', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryList(List<Beneficiary> beneficiaries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: beneficiaries.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) => _buildBeneficiaryCard(beneficiaries[index]),
    );
  }

  Widget _buildBeneficiaryCard(Beneficiary beneficiary) {
    final String maskedAccount = beneficiary.accountNumber.length >= 4
        ? '••••${beneficiary.accountNumber.substring(beneficiary.accountNumber.length - 4)}'
        : beneficiary.accountNumber;

    final String initials = beneficiary.accountHolderName
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: InkWell(
        onTap: () => HapticFeedback.selectionClick(),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.8), AppColors.primaryLight.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(initials, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(beneficiary.accountHolderName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textWhite), overflow: TextOverflow.ellipsis)),
                            if (beneficiary.verified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.verified.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.verified.withOpacity(0.3))),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.verified)),
                                    const SizedBox(width: 4),
                                    Text('Verified', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.verified)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text('${beneficiary.bankName} • $maskedAccount', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkSecondary)),
                        if (beneficiary.beneficiaryMobile != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [const Icon(Iconsax.call, size: 10, color: AppColors.textDarkHint), const SizedBox(width: 4), Text('+91 ${beneficiary.beneficiaryMobile}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint))]),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                      onPressed: () => _deleteBeneficiary(beneficiary.id),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _buildInfoChip(Iconsax.clock, 'Used ${beneficiary.useCount}x'),
                    const SizedBox(width: 14),
                    _buildInfoChip(Iconsax.card, 'IFSC: ${beneficiary.ifscCode}'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.arrow_right_3, size: 10, color: AppColors.primaryLight),
                          const SizedBox(width: 2),
                          Text('Transfer', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: AppColors.textDarkHint),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}