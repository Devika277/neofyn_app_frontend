// lib/screens/account/change_mpin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mpin_service.dart';

class ChangeMpinScreen extends StatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  State<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends State<ChangeMpinScreen> {
  final _currentMpinController = TextEditingController();
  final _newMpinController = TextEditingController();
  final _confirmMpinController = TextEditingController();

  bool _isLoading = false;
  bool _isCurrentVisible = false;
  bool _isNewVisible = false;
  bool _isConfirmVisible = false;
  String? _errorMessage;

  // Track which field is active
  int _activeFieldIndex = 0; // 0: current, 1: new, 2: confirm

  @override
  void dispose() {
    _currentMpinController.dispose();
    _newMpinController.dispose();
    _confirmMpinController.dispose();
    super.dispose();
  }

  TextEditingController _getActiveController() {
    switch (_activeFieldIndex) {
      case 0:
        return _currentMpinController;
      case 1:
        return _newMpinController;
      case 2:
        return _confirmMpinController;
      default:
        return _currentMpinController;
    }
  }

  bool _allFieldsFilled() {
    return _currentMpinController.text.length == 6 &&
        _newMpinController.text.length == 6 &&
        _confirmMpinController.text.length == 6;
  }

  bool _isWeakPin(String pin) {
    const weakPins = [
      '000000',
      '111111',
      '222222',
      '333333',
      '444444',
      '555555',
      '666666',
      '777777',
      '888888',
      '999999',
      '123456',
      '654321',
      '121212',
      '112233',
      '123123',
    ];
    return weakPins.contains(pin);
  }

  void _onNumberTap(String number) {
    final controller = _getActiveController();
    if (controller.text.length < 6) {
      controller.text += number;
      setState(() => _errorMessage = null);

      // Auto advance to next field when current is full
      if (controller.text.length == 6 && _activeFieldIndex < 2) {
        setState(() => _activeFieldIndex++);
      }
    }
  }

  void _onDeleteTap() {
    final controller = _getActiveController();
    if (controller.text.isNotEmpty) {
      controller.text = controller.text.substring(
        0,
        controller.text.length - 1,
      );
      setState(() => _errorMessage = null);
    } else if (_activeFieldIndex > 0) {
      // Move to previous field if current is empty
      setState(() => _activeFieldIndex--);
      final prevController = _getActiveController();
      if (prevController.text.isNotEmpty) {
        prevController.text = prevController.text.substring(
          0,
          prevController.text.length - 1,
        );
      }
    }
  }

  void _selectField(int index) {
    setState(() => _activeFieldIndex = index);
  }

  void _clearAll() {
    _currentMpinController.clear();
    _newMpinController.clear();
    _confirmMpinController.clear();
    setState(() {
      _errorMessage = null;
      _activeFieldIndex = 0;
    });
  }

  Future<void> _changeMpin() async {
    final currentMpin = _currentMpinController.text.trim();
    final newMpin = _newMpinController.text.trim();
    final confirmMpin = _confirmMpinController.text.trim();

    // Validate current MPIN
    if (currentMpin.length != 6) {
      setState(() => _errorMessage = 'Please enter current MPIN');
      return;
    }

    // Validate new MPIN
    if (newMpin.length != 6) {
      setState(() => _errorMessage = 'Please enter new MPIN');
      return;
    }

    if (newMpin == currentMpin) {
      setState(() => _errorMessage = 'New MPIN must be different from current');
      return;
    }

    if (_isWeakPin(newMpin)) {
      setState(() => _errorMessage = 'Choose a more secure MPIN');
      return;
    }

    // Validate confirm MPIN
    if (newMpin != confirmMpin) {
      setState(() => _errorMessage = 'New MPINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await MpinService.changeMpin(currentMpin, newMpin);
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MPIN changed successfully!'),
            backgroundColor: Color(0xFF008169),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Widget _buildMpinField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required bool isActive,
    required VoidCallback onVisibilityToggle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF008169).withOpacity(0.6)
                : Colors.white.withOpacity(0.1),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.white70 : Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dot display
                  Row(
                    children: List.generate(6, (index) {
                      final hasValue = index < controller.text.length;
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasValue
                              ? const Color(0xFF008169)
                              : Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: hasValue
                                ? const Color(0xFF008169)
                                : Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: onVisibilityToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final buttonSize = 70.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('1', buttonSize),
            _buildKey('2', buttonSize),
            _buildKey('3', buttonSize),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4', buttonSize),
            _buildKey('5', buttonSize),
            _buildKey('6', buttonSize),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7', buttonSize),
            _buildKey('8', buttonSize),
            _buildKey('9', buttonSize),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('', buttonSize, isDelete: true),
            _buildKey('0', buttonSize),
            _buildKey('', buttonSize, isEmpty: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(
    String number,
    double size, {
    bool isDelete = false,
    bool isEmpty = false,
  }) {
    if (isEmpty) {
      return SizedBox(width: size, height: size);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isDelete) {
          _onDeleteTap();
        } else {
          _onNumberTap(number);
        }
      },
      onLongPress: isDelete ? _clearAll : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isDelete
              ? Icon(Icons.backspace_outlined, color: Colors.white54, size: 24)
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
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white60,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Change MPIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40), // Balance
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Current MPIN
                      _buildMpinField(
                        controller: _currentMpinController,
                        label: 'Current MPIN',
                        isVisible: _isCurrentVisible,
                        isActive: _activeFieldIndex == 0,
                        onVisibilityToggle: () {
                          setState(
                            () => _isCurrentVisible = !_isCurrentVisible,
                          );
                        },
                        onTap: () => _selectField(0),
                      ),

                      const SizedBox(height: 12),

                      // New MPIN
                      _buildMpinField(
                        controller: _newMpinController,
                        label: 'New MPIN',
                        isVisible: _isNewVisible,
                        isActive: _activeFieldIndex == 1,
                        onVisibilityToggle: () {
                          setState(() => _isNewVisible = !_isNewVisible);
                        },
                        onTap: () => _selectField(1),
                      ),

                      const SizedBox(height: 12),

                      // Confirm MPIN
                      _buildMpinField(
                        controller: _confirmMpinController,
                        label: 'Confirm New MPIN',
                        isVisible: _isConfirmVisible,
                        isActive: _activeFieldIndex == 2,
                        onVisibilityToggle: () {
                          setState(
                            () => _isConfirmVisible = !_isConfirmVisible,
                          );
                        },
                        onTap: () => _selectField(2),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
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

                      // Change MPIN Button - Only visible when all fields are filled
                      if (_allFieldsFilled()) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _isLoading ? null : _changeMpin,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF008169), Color(0xFF1AA88A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF008169,
                                  ).withOpacity(0.3),
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
                                      'Change MPIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

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
                            'Encrypted & Secure',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Custom Keypad at bottom
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: _buildKeypad(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
