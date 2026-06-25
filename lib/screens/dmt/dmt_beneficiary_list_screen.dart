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
  // Primary palette - New Green Theme
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  // Backgrounds
  static const Color background = Color(0xFFF6FAF9);
  static const Color cardColor = Colors.white;
  static const Color surface = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color verified = Color(0xFF10B981);
  static const Color pending = Color(0xFFF59E0B);

  // Border & Effects
  static const Color borderLight = Color(0xFFE5E7EB);
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
        backgroundColor: AppColors.cardColor,
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
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this beneficiary? This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Delete',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
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
      setState(() {
        _beneficiaries.removeWhere((b) => b.id == id);
      });

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Beneficiary deleted successfully',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                ),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
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
      MaterialPageRoute(
        builder: (context) => DMTAddBeneficiaryScreen(
          remitterId: widget.remitterId,
        ),
      ),
    );

    if (result == true && mounted) {
      // Refresh the list if a beneficiary was added
      // You can reload data from API here
      _showToast('Refresh the page to see new beneficiary');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Beneficiaries',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.add, color: AppColors.textWhite, size: 22),
              onPressed: _navigateToAddBeneficiary,
              tooltip: 'Add Beneficiary',
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stats Row
                Row(
                  children: [
                    _buildStatChip(
                      Iconsax.people,
                      '${_beneficiaries.length} Total',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Iconsax.verify,
                      '${_beneficiaries.where((b) => b.verified).length} Verified',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name, bank, or account',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Iconsax.search_normal,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(
                          Iconsax.close_circle,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddBeneficiary,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Iconsax.add, size: 20),
        label: Text(
          'Add Beneficiary',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Please wait...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )
          : _beneficiaries.isEmpty
          ? _buildEmptyState()
          : filteredList.isEmpty
          ? _buildNoResultsState()
          : _buildBeneficiaryList(filteredList),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.user_add,
                size: 64,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Beneficiaries Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a beneficiary to start transferring money instantly',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToAddBeneficiary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Iconsax.add, color: Colors.white, size: 20),
                label: Text(
                  'Add First Beneficiary',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.search_normal,
                size: 48,
                color: AppColors.warning.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Results Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryList(List<Beneficiary> beneficiaries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: beneficiaries.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final beneficiary = beneficiaries[index];
        return _buildBeneficiaryCard(beneficiary);
      },
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            // Handle beneficiary selection if needed
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar with initials
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.8),
                            AppColors.primaryLight.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Beneficiary Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  beneficiary.accountHolderName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildVerificationBadge(beneficiary.verified),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${beneficiary.bankName} • $maskedAccount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (beneficiary.beneficiaryMobile != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Iconsax.call,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+91 ${beneficiary.beneficiaryMobile}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Delete Button
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Iconsax.trash,
                          size: 18,
                          color: AppColors.error,
                        ),
                        onPressed: () => _deleteBeneficiary(beneficiary.id),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: 'Delete',
                      ),
                    ),
                  ],
                ),

                // Bottom Stats Row
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildInfoChip(
                        Iconsax.clock,
                        'Used ${beneficiary.useCount}x',
                      ),
                      const SizedBox(width: 16),
                      _buildInfoChip(
                        Iconsax.card,
                        'IFSC: ${beneficiary.ifscCode}',
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.arrow_right_3, size: 12, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              'Transfer',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildVerificationBadge(bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.verified.withOpacity(0.1)
            : AppColors.pending.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: verified
              ? AppColors.verified.withOpacity(0.3)
              : AppColors.pending.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: verified ? AppColors.verified : AppColors.pending,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Pending',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: verified ? AppColors.verified : AppColors.pending,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}