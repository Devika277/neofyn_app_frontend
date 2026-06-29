// widgets/commission/transfer_commission_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/commission/commission_service.dart';
import '../../services/bbps/api_service.dart';
import '../../providers/wallet_provider.dart';

class TransferCommissionDialog extends StatefulWidget {
  final double availableBalance;
  final double minTransferAmount;

  const TransferCommissionDialog({
    Key? key,
    required this.availableBalance,
    required this.minTransferAmount,
  }) : super(key: key);

  @override
  State<TransferCommissionDialog> createState() => _TransferCommissionDialogState();
}

class _TransferCommissionDialogState extends State<TransferCommissionDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tpinController = TextEditingController();
  bool _isLoading = false;
  bool _obscureTpin = true;
  String? _error;
  bool _isFullAmount = false;

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    super.dispose();
  }

  Future<void> _transferAmount() async {
    final amountText = _amountController.text.trim();
    
    // Validate amount
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    if (amount < widget.minTransferAmount) {
      setState(() => _error = 'Minimum transfer is ₹${widget.minTransferAmount.toStringAsFixed(0)}');
      return;
    }

    if (amount > widget.availableBalance) {
      setState(() => _error = 'Insufficient commission balance');
      return;
    }

    // Validate TPIN
    final tpin = _tpinController.text.trim();
    if (tpin.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit TPIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Step 1: Verify TPIN
      print('🔑 Verifying TPIN...');
      final tpinResponse = await ApiService.post(
        '/api/auth/verify-tpin',
        {'tpin': tpin},
      );

      if (tpinResponse['success'] != true) {
        setState(() {
          _error = 'Invalid TPIN. Please try again.';
          _isLoading = false;
        });
        return;
      }

      print('✅ TPIN verified successfully');

      // Step 2: Transfer commission to main wallet
      print('🔵 Calling CommissionService.transferToMain($amount)');
      final response = await CommissionService.transferToMain(amount);
      print('📥 Transfer response: $response');
      
      if (response['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Transfer successful!',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Update wallet provider
        final wp = Provider.of<WalletProvider>(context, listen: false);
        await wp.fetchAllWalletData();
        await wp.fetchCommissionBalance();
        
        // Close dialog with success
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = response['message'] ?? 'Transfer failed';
        });
      }
    } catch (e) {
      print('❌ Transfer error: $e');
      setState(() {
        if (e is ApiException && e.statusCode == 401) {
          _error = 'Invalid TPIN. Please try again.';
        } else {
          _error = e.toString();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transfer to Main Wallet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Available: ₹${widget.availableBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Balance Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Commission Balance:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '₹${widget.availableBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Minimum transfer info
            Text(
              'Minimum transfer: ₹${widget.minTransferAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
              ),
              onChanged: (value) {
                if (_error != null && !_error!.contains('TPIN')) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 12),
            
            // Full Amount Button
            if (widget.availableBalance >= widget.minTransferAmount)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _amountController.text = widget.availableBalance.toStringAsFixed(2);
                      _isFullAmount = true;
                      _error = null;
                    });
                  },
                  child: Text(
                    'Transfer Full Amount',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // TPIN Input
            TextField(
              controller: _tpinController,
              obscureText: _obscureTpin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                hintText: 'Enter 6-digit TPIN',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureTpin ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() => _obscureTpin = !_obscureTpin);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
                errorText: _error != null && _error!.contains('TPIN') ? _error : null,
                counterText: '', // Hide character counter
              ),
              onChanged: (value) {
                if (_error != null && _error!.contains('TPIN')) {
                  setState(() => _error = null);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Transfer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _transferAmount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Transfer to Main Wallet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}