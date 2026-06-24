// lib/screens/dmt/dmt_beneficiary_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';
import 'dmt_add_beneficiary_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _beneficiaries = widget.beneficiaries;
  }

  Future<void> _deleteBeneficiary(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: const Text('Are you sure you want to delete this beneficiary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beneficiary deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Beneficiaries',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DMTAddBeneficiaryScreen(
                    remitterId: widget.remitterId,
                  ),
                ),
              ).then((_) {
                // Refresh list when coming back
                // You can reload data here if needed
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _beneficiaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.user_add, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No beneficiaries added',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a beneficiary to start transferring',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DMTAddBeneficiaryScreen(
                                remitterId: widget.remitterId,
                              ),
                            ),
                          );
                        },
                        child: const Text('Add Beneficiary'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _beneficiaries.length,
                  itemBuilder: (context, index) {
                    final beneficiary = _beneficiaries[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Iconsax.bank,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  beneficiary.accountHolderName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${beneficiary.bankName} • ${beneficiary.accountNumber.substring(beneficiary.accountNumber.length - 4)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (beneficiary.beneficiaryMobile != null) ...[
                                  Text(
                                    '📱 +91 ${beneficiary.beneficiaryMobile}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //     horizontal: 8,
                              //     vertical: 4,
                              //   ),
                              //   decoration: BoxDecoration(
                              //     color: beneficiary.verified
                              //         ? Colors.green[100]
                              //         : Colors.orange[100],
                              //     borderRadius: BorderRadius.circular(12),
                              //   ),
                              //   child: Text(
                              //     beneficiary.verified ? 'Verified' : 'Pending',
                              //     style: GoogleFonts.poppins(
                              //       fontSize: 10,
                              //       fontWeight: FontWeight.w500,
                              //       color: beneficiary.verified
                              //           ? Colors.green[700]
                              //           : Colors.orange[700],
                              //     ),
                              //   ),
                              // ),
                              const SizedBox(height: 4),
                              Text(
                                'Used ${beneficiary.useCount} times',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Iconsax.trash,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteBeneficiary(beneficiary.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}