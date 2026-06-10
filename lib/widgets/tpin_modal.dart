// lib/widgets/tpin_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/AEPS/auth_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../screens/account/set_tpin_screen.dart';

class TPINModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String tpin) onVerified;
  final String? actionLabel;   // optional: "Authorise ₹500 transfer"

  const TPINModal({
    super.key,
    required this.onClose,
    required this.onVerified,
    this.actionLabel,
  });

  @override
  State<TPINModal> createState() => _TPINModalState();
}

class _TPINModalState extends State<TPINModal> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus first field after modal is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  String _getTpin() => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final tpin = _getTpin();
    if (tpin.length != 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final isValid = await AuthService().verifyTpin(tpin);
      if (!isValid) {
        setState(() {
          _error = 'Invalid TPIN. Please try again.';
          _loading = false;
        });
        _clearAndRefocus();
        return;
      }
      // Success → return TPIN to caller
      widget.onVerified(tpin);
      widget.onClose();  // close modal
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      _clearAndRefocus();
    }
  }

  void _clearAndRefocus() {
    for (var c in _controllers) c.clear();
    _focusNodes.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    // If user hasn't set TPIN yet → show different UI
    if (user != null && !user.tpinSet) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
              const SizedBox(height: 12),
              const Text('TPIN Not Set', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You must set a Transaction PIN before making any transfers.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onClose();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SetTPINScreen()),
                        );
                      },
                      child: const Text('Set TPIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Normal TPIN entry modal
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enter TPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (widget.actionLabel != null)
                        Text(widget.actionLabel!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 55,
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [LengthLimitingTextInputFormatter(1), FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      }
                      setState(() => _error = '');
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                );
              }),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error, style: TextStyle(color: Colors.red.shade600, fontSize: 12))),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                widget.onClose();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SetTPINScreen()));
              },
              child: const Text('Forgot TPIN? Reset it'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper to show the modal from any screen
Future<void> showTPINModal({
  required BuildContext context,
  required Function(String tpin) onVerified,
  String? actionLabel,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TPINModal(
      onClose: () => Navigator.pop(ctx),
      onVerified: onVerified,
      actionLabel: actionLabel,
    ),
  );
}