import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mpin_service.dart';
import '../../layout/UserHomeScreen.dart';

class MpinVerifyScreen extends StatefulWidget {
  // Parameters kept for compatibility with existing navigation calls,
  // but they are not used because MpinService reads token from storage.
  final String? userId;
  final String? token;

  const MpinVerifyScreen({super.key, this.userId, this.token});

  @override
  State<MpinVerifyScreen> createState() => _MpinVerifyScreenState();
}

class _MpinVerifyScreenState extends State<MpinVerifyScreen> {
  final _mpinController = TextEditingController();
  final _mpinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isMpinVisible = false;
  String? _errorMessage;
  int _attemptsLeft = 3;
  bool _isLocked = false;
  int _lockoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _mpinFocusNode.requestFocus();
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
                  const SizedBox(height: 40),
                  // Lock Icon
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
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter MPIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your 6-digit PIN to continue',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // MPIN Input with visual dots
                  _buildMpinInput(),

                  if (_attemptsLeft < 3) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$_attemptsLeft attempts remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: _attemptsLeft == 1 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

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

                  // Verify Button
                  _buildVerifyButton(),

                  const SizedBox(height: 20),

                  // Forgot MPIN
                  TextButton(
                    onPressed: _isLocked ? null : _showForgotMpinDialog,
                    child: Text(
                      'Forgot MPIN?',
                      style: TextStyle(
                        color: _isLocked
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFF1AA88A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMpinInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Visual MPIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final isFilled = _mpinController.text.length > index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? const Color(0xFF008169)
                    : Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: isFilled
                      ? const Color(0xFF008169)
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF008169).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Hidden TextField for actual input
        Container(
          width: 0,
          height: 0,
          child: TextField(
            controller: _mpinController,
            focusNode: _mpinFocusNode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            showCursor: false,
            style: const TextStyle(fontSize: 1, color: Colors.transparent),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
            ),
            onChanged: (value) {
              setState(() => _errorMessage = null);
              if (value.length == 6) {
                _verifyMpin();
              }
            },
          ),
        ),

        // Numeric Keypad
        _buildNumericKeypad(),
      ],
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeypadButton('', isDelete: true),
              _buildKeypadButton('0'),
              _buildKeypadButton('', isEmpty: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(
    String number, {
    bool isDelete = false,
    bool isEmpty = false,
  }) {
    if (isEmpty) {
      return const SizedBox(width: 70, height: 70);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isDelete) {
          if (_mpinController.text.isNotEmpty) {
            _mpinController.text = _mpinController.text.substring(
              0,
              _mpinController.text.length - 1,
            );
            setState(() {});
          }
        } else {
          if (_mpinController.text.length < 6) {
            _mpinController.text += number;
            setState(() {});
            if (_mpinController.text.length == 6) {
              _verifyMpin();
            }
          }
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: isDelete
              ? Icon(
                  Icons.backspace_outlined,
                  color: Colors.white.withOpacity(0.6),
                  size: 24,
                )
              : Text(
                  number,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return GestureDetector(
      onTap: _isLoading || _isLocked ? null : _verifyMpin,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: _isLocked
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF008169), Color(0xFF1AA88A)],
                ),
          color: _isLocked ? Colors.white.withOpacity(0.05) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLocked
              ? null
              : [
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
              : Text(
                  _isLocked ? 'Try again in $_lockoutSeconds s' : 'Verify',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isLocked
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _verifyMpin() async {
    if (_isLocked) return;

    final mpin = _mpinController.text.trim();
    if (mpin.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await MpinService.verifyMpin(mpin);

      if (isValid) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          // Navigate directly to home screen on success
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
        }
      } else {
        // Invalid MPIN – backend returned 401
        setState(() {
          _attemptsLeft--;
          _errorMessage = 'Invalid MPIN. $_attemptsLeft attempts remaining.';
          _mpinController.clear();
          _isLoading = false;
        });

        if (_attemptsLeft == 0) {
          _lockout();
        }
      }
    } catch (e) {
      // Show the actual error message from the service (e.g., "MPIN not set", network error)
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  void _lockout() {
    setState(() {
      _isLocked = true;
      _lockoutSeconds = 30;
      _errorMessage = 'Too many attempts. Please wait 30 seconds.';
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _lockoutSeconds--);
      return _lockoutSeconds > 0;
    }).then((_) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _attemptsLeft = 3;
          _errorMessage = null;
          _mpinController.clear();
        });
      }
    });
  }

  void _showForgotMpinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset MPIN', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be logged out and need to login again to set a new MPIN.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear stored MPIN status and go to login
              MpinService.clearMpinStatus();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mpinController.dispose();
    _mpinFocusNode.dispose();
    super.dispose();
  }
}