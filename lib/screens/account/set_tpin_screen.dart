// lib/screens/account/set_tpin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/AEPS/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SetTPINScreen extends StatefulWidget {
  const SetTPINScreen({super.key});

  @override
  State<SetTPINScreen> createState() => _SetTPINScreenState();
}

class _SetTPINScreenState extends State<SetTPINScreen> {
  late AuthService _authService;

  // Controllers for TPIN inputs
  final TextEditingController _tpinController = TextEditingController();
  final TextEditingController _confirmTpinController = TextEditingController();
  final FocusNode _tpinFocusNode = FocusNode();
  final FocusNode _confirmTpinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isTpinVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _tpinController.dispose();
    _confirmTpinController.dispose();
    _tpinFocusNode.dispose();
    _confirmTpinFocusNode.dispose();
    super.dispose();
  }

  String? _validateTpin(String tpin) {
    if (tpin.isEmpty) return 'TPIN is required';
    if (tpin.length != 6) return 'TPIN must be exactly 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(tpin)) return 'TPIN must contain only digits';
    if (_hasAllSameDigits(tpin)) return 'TPIN cannot be all same digits';
    if (_isSequential(tpin)) return 'TPIN cannot be sequential digits';
    if (_isCommonPattern(tpin)) return 'TPIN is too common';
    return null;
  }

  bool _hasAllSameDigits(String tpin) => RegExp(r'^(\d)\1{5}$').hasMatch(tpin);

  bool _isSequential(String tpin) {
    bool isAscending = true;
    bool isDescending = true;
    for (int i = 0; i < tpin.length - 1; i++) {
      final current = int.parse(tpin[i]);
      final next = int.parse(tpin[i + 1]);
      if (next != current + 1) isAscending = false;
      if (next != current - 1) isDescending = false;
    }
    return isAscending || isDescending;
  }

  bool _isCommonPattern(String tpin) {
    const commonPatterns = [
      '123456', '654321', '111111', '000000', '222222', '333333',
      '444444', '555555', '666666', '777777', '888888', '999999',
      '121212', '112233', '123123',
    ];
    return commonPatterns.contains(tpin);
  }

  Future<void> _setTpin() async {
    final tpin = _tpinController.text.trim();
    final confirmTpin = _confirmTpinController.text.trim();

    // Basic validation
    if (tpin.isEmpty || confirmTpin.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both fields');
      return;
    }

    final validation = _validateTpin(tpin);
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }

    if (tpin != confirmTpin) {
      setState(() => _errorMessage = 'TPINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newToken = await _authService.setTpin(tpin);

      if (newToken != null) {
        context.read<AuthProvider>().setAccessToken(newToken);
      }

      await context.read<AuthProvider>().updateUser(tpinSet: true);
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TPIN set successfully!'),
            backgroundColor: Color(0xFF008169),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E0A),
              Color(0xFF0F1A0F),
              Color(0xFF0A0E0A),
              Color(0xFF050805),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Shield Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF008169), Color(0xFF1AA88A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF008169).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Set Your TPIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Create a 6-digit PIN for secure transactions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // TPIN Input
                  _buildTpinInput(
                    controller: _tpinController,
                    focusNode: _tpinFocusNode,
                    label: 'Enter TPIN',
                  ),

                  const SizedBox(height: 16),

                  // Confirm TPIN Input
                  _buildTpinInput(
                    controller: _confirmTpinController,
                    focusNode: _confirmTpinFocusNode,
                    label: 'Confirm TPIN',
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Set TPIN Button
                  _buildSetTpinButton(),

                  const SizedBox(height: 20),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: 14,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Your TPIN is securely encrypted',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTpinInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? const Color(0xFF008169).withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: focusNode.hasFocus ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: !_isTpinVisible,
            keyboardType: TextInputType.number,
            maxLength: 6,
            showCursor: true,
            readOnly: false,
            enableInteractiveSelection: false,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 24,
                letterSpacing: 8,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isTpinVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _isTpinVisible = !_isTpinVisible);
                },
              ),
            ),
            onChanged: (value) {
              setState(() => _errorMessage = null);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetTpinButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _setTpin,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF008169), Color(0xFF1AA88A)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF008169).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            'Set TPIN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}