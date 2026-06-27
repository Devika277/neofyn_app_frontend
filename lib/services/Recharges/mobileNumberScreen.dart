// // lib/services/Recharges/mobileNumberScreen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'rechargeDetails_screen.dart';

// class MobileNumberScreen extends StatefulWidget {
//   const MobileNumberScreen({Key? key}) : super(key: key);

//   @override
//   State<MobileNumberScreen> createState() => _MobileNumberScreenState();
// }

// class _MobileNumberScreenState extends State<MobileNumberScreen> {
//   final TextEditingController _controller = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   void _onContinue() {
//     if (_formKey.currentState?.validate() ?? false) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => RechargeDetailsScreen(mobile: _controller.text.trim()),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Mobile Recharge'),
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Enter Mobile Number',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _controller,
//                 keyboardType: TextInputType.phone,
//                 maxLength: 10,
//                 // Only allow digits
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 decoration: const InputDecoration(
//                   hintText: '10-digit mobile number',
//                   prefixText: '+91  ',
//                   border: OutlineInputBorder(),
//                   counterText: '',
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter mobile number';
//                   }
//                   if (value.length != 10) {
//                     return 'Mobile number must be exactly 10 digits';
//                   }
//                   // Indian mobile numbers start with 6-9
//                   if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
//                     return 'Enter a valid Indian mobile number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _onContinue,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   child: const Text(
//                     'CONTINUE',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }