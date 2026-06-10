// lib/screens/account/set_tpin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/AEPS/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

enum TpinMode { set, change }

class SetTPINScreen extends StatefulWidget {
  const SetTPINScreen({super.key});

  @override
  State<SetTPINScreen> createState() => _SetTPINScreenState();
}

class _SetTPINScreenState extends State<SetTPINScreen> {
  late AuthService _authService;
  late TpinMode _mode;

  final List<TextEditingController> _currentControllers = List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _newControllers = List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _confirmControllers = List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _currentFocus = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _newFocus = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _confirmFocus = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    final user = context.read<AuthProvider>().user;
    final bool hasTpin = user?.tpinSet ?? false;
    _mode = hasTpin ? TpinMode.change : TpinMode.set;
  }

  @override
  void dispose() {
    for (var c in _currentControllers) c.dispose();
    for (var c in _newControllers) c.dispose();
    for (var c in _confirmControllers) c.dispose();
    for (var f in _currentFocus) f.dispose();
    for (var f in _newFocus) f.dispose();
    for (var f in _confirmFocus) f.dispose();
    super.dispose();
  }

  String? validateTpin(List<String> digits) {
    final tpin = digits.join();
    if (tpin.length != 6) return 'TPIN must be exactly 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(tpin)) return 'TPIN must contain only digits';
    if (RegExp(r'^(\d)\1{5}$').hasMatch(tpin)) return 'TPIN cannot be all same digits';
    if (['123456', '654321', '111111', '000000'].contains(tpin)) return 'TPIN too common';
    return null;
  }

  String _getTpinFromControllers(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text).join();
  }

  void _clearAll() {
    for (var c in _currentControllers) c.clear();
    for (var c in _newControllers) c.clear();
    for (var c in _confirmControllers) c.clear();
    setState(() => _error = '');
  }

  Future<void> _handleSet() async {
    final newTpin = _getTpinFromControllers(_newControllers);
    final confirmTpin = _getTpinFromControllers(_confirmControllers);

    final validation = validateTpin(_newControllers.map((c) => c.text).toList());
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    if (newTpin != confirmTpin) {
      setState(() => _error = 'TPINs do not match');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      final newToken = await _authService.setTpin(newTpin);
      if (newToken != null) {
        // ✅ FIX: remove 'await' because setAccessToken is synchronous
        context.read<AuthProvider>().setAccessToken(newToken);
      }
      await context.read<AuthProvider>().updateUser(tpinSet: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TPIN set successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleChange() async {
    final currentTpin = _getTpinFromControllers(_currentControllers);
    final newTpin = _getTpinFromControllers(_newControllers);
    final confirmTpin = _getTpinFromControllers(_confirmControllers);

    if (currentTpin.length != 6) {
      setState(() => _error = 'Please enter current TPIN');
      return;
    }
    final validation = validateTpin(_newControllers.map((c) => c.text).toList());
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    if (newTpin != confirmTpin) {
      setState(() => _error = 'New TPINs do not match');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      await _authService.changeTpin(currentTpin, newTpin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TPIN changed successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTpinRow(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 50,
              height: 60,
              child: TextFormField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                textAlign: TextAlign.center,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == TpinMode.set ? 'Set Transaction PIN' : 'Change Transaction PIN'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.shield, size: 60, color: Theme.of(context).primaryColor),
            const SizedBox(height: 12),
            Text(
              _mode == TpinMode.set
                  ? 'Secure your transactions with a 6-digit TPIN'
                  : 'Update your TPIN for added security',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            if (_mode == TpinMode.change)
              _buildTpinRow(_currentControllers, _currentFocus, 'Current TPIN'),
            _buildTpinRow(_newControllers, _newFocus, _mode == TpinMode.set ? 'New TPIN' : 'New TPIN'),
            _buildTpinRow(_confirmControllers, _confirmFocus, 'Confirm TPIN'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : (_mode == TpinMode.set ? _handleSet : _handleChange),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(_mode == TpinMode.set ? 'Set TPIN' : 'Change TPIN'),
              ),
            ),
            if (_mode == TpinMode.change)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact support to reset TPIN')),
                  );
                },
                child: const Text('Forgot TPIN? Contact support'),
              ),
          ],
        ),
      ),
    );
  }
}