import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/mpin_service.dart';
import '../../layout/UserHomeScreen.dart';
import 'login_screen.dart';

class MpinVerifyScreen extends StatefulWidget {
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

                  const SizedBox(height: 16),

                  // Verify Button
                  _buildVerifyButton(),

                  const SizedBox(height: 15),

                  // ─── FORGOT MPIN BUTTON ──────────────────────
                  TextButton(
                    onPressed: _isLocked ? null : _showForgotMpinOptions,
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

                  const SizedBox(height: 2),

                  // ─── LOGOUT BUTTON ───────────────────────────
                  TextButton(
                    onPressed: _isLocked ? null : _handleLogout,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: _isLocked
                              ? Colors.white.withOpacity(0.3)
                              : Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: _isLocked
                                ? Colors.white.withOpacity(0.3)
                                : Colors.red.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
        SizedBox(
          width: 0,
          height: 0,
          child: TextField(
            controller: _mpinController,
            focusNode: _mpinFocusNode,
            keyboardType: TextInputType.none,
            maxLength: 6,
            autofocus: false,
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
        }
      } else {
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

  // ─── FORGOT MPIN - CONTACT ADMIN ────────────────────────
  void _showForgotMpinOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF008169).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Color(0xFF1AA88A),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Forgot MPIN?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              const Text(
                'Please contact the administrator to reset your MPIN or set a new one.\n\nThe admin will help you remove the existing MPIN and set up a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Contact Admin Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // _showContactAdminDialog();
                  },
                  icon: const Icon(Icons.support_agent_rounded, size: 20),
                  label: const Text(
                    'Contact Admin',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008169),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logout Option
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CONTACT ADMIN DIALOG ───────────────────────────────
  /*void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: Color(0xFF1AA88A), size: 24),
            SizedBox(width: 10),
            Text(
              'Contact Admin',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reach out to the administrator using any of the methods below to reset your MPIN.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 20),
            _ContactRow(icon: Icons.call_rounded, label: 'Call', value: '+91 98765 43210'),
            SizedBox(height: 12),
            _ContactRow(icon: Icons.chat_rounded, label: 'WhatsApp', value: '+91 98765 43210'),
            SizedBox(height: 12),
            _ContactRow(icon: Icons.email_rounded, label: 'Email', value: 'support@neofyn.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF1AA88A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }*/

  // ─── LOGOUT HANDLER ─────────────────────────────────────
  // ─── LOGOUT HANDLER ──────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nYou will need to login again to access the app.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear all stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear MPIN status
      MpinService.clearMpinStatus();

      // Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _mpinController.dispose();
    _mpinFocusNode.dispose();
    super.dispose();
  }
}

// ─── CONTACT ROW WIDGET ───────────────────────────────────
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1AA88A)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}