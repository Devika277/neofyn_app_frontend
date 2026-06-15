import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mpin_service.dart';
import 'mpin_verify_screen.dart'; // adjust path to your MPIN verify screen


class SetMpinScreen extends StatefulWidget {
  // Parameters kept only if needed elsewhere – otherwise you can remove them.
  final String userId;
  final String token;

  const SetMpinScreen({super.key, required this.userId, required this.token});

  @override
  State<SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends State<SetMpinScreen> {
  final _mpinController = TextEditingController();
  final _confirmMpinController = TextEditingController();
  final _mpinFocusNode = FocusNode();
  final _confirmMpinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isMpinVisible = false;
  String? _errorMessage;

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
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Set Your MPIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a 6-digit PIN for secure access',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // MPIN Input
                  _buildMpinInput(
                    controller: _mpinController,
                    focusNode: _mpinFocusNode,
                    label: 'Enter MPIN',
                  ),
                  const SizedBox(height: 16),

                  // Confirm MPIN Input
                  _buildMpinInput(
                    controller: _confirmMpinController,
                    focusNode: _confirmMpinFocusNode,
                    label: 'Confirm MPIN',
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

                  // Set MPIN Button
                  _buildSetMpinButton(),

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
                        'Your MPIN is securely encrypted',
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

  Widget _buildMpinInput({
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
            obscureText: !_isMpinVisible,
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
                  _isMpinVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _isMpinVisible = !_isMpinVisible);
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

  Widget _buildSetMpinButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _setMpin,
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
                  'Set MPIN',
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

  Future<void> _setMpin() async {
    final mpin = _mpinController.text.trim();
    final confirmMpin = _confirmMpinController.text.trim();

    // Basic front‑end validation for better UX
    if (mpin.isEmpty || confirmMpin.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both fields');
      return;
    }
    if (mpin.length != 6) {
      setState(() => _errorMessage = 'MPIN must be 6 digits');
      return;
    }
    if (mpin != confirmMpin) {
      setState(() => _errorMessage = 'MPINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call the service – it reads the token from secure storage automatically
      await MpinService.setMpin(mpin);
      HapticFeedback.heavyImpact();

      if (mounted) {
        // After successful set, go directly to home screen.
        // (No need to verify again; the user will verify on next login.)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MpinVerifyScreen(userId: '', token: '',)),
        );
      }
    } catch (e) {
      setState(() {
        // Display the actual error message from the service/backend
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _mpinController.dispose();
    _confirmMpinController.dispose();
    _mpinFocusNode.dispose();
    _confirmMpinFocusNode.dispose();
    super.dispose();
  }
}