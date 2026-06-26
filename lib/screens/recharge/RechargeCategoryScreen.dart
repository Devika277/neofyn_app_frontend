// // lib/screens/bill_payment_screen.dart
// import 'package:flutter/material.dart';
// import 'package:my_app/screens/BBPS/bbps_payment_screen.dart';

// class BillPaymentScreen extends StatelessWidget {
//   // Only bill categories (from your summary table)
//   final List<Map<String, dynamic>> billCategories = [
//     {"name": "Electricity", "emoji": "⚡", "type": "electricity", "categoryId": "ELECTRICITY"},
//     {"name": "Water Bill",   "emoji": "💧", "type": "water",      "categoryId": "WATER"},
//     {"name": "Gas Bill",     "emoji": "🔥", "type": "gas",        "categoryId": "GAS"},
//     {"name": "Postpaid",     "emoji": "📱", "type": "postpaid",   "categoryId": "POSTPAID"},
//     {"name": "Loan Repayment","emoji": "🏦", "type": "loan",      "categoryId": "LOAN"},
//     {"name": "Insurance",    "emoji": "🛡️", "type": "insurance",  "categoryId": "INSURANCE"},
//     {"name": "Broadband",    "emoji": "🌐", "type": "broadband",  "categoryId": "BROADBAND"},
//     {"name": "Municipal Tax", "emoji": "🏛️", "type": "tax",       "categoryId": "MUNICIPAL"},
//     {"name": "Education Fee", "emoji": "📚", "type": "education", "categoryId": "EDUCATION"},
//     {"name": "Cable TV",      "emoji": "📺", "type": "cable",     "categoryId": "CABLE"},
//     {"name": "Rent",          "emoji": "🏠", "type": "rent",      "categoryId": "RENT"},
//     {"name": "Donation",      "emoji": "🙏", "type": "donation",  "categoryId": "DONATION"},
//   ];

//   BillPaymentScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text("Pay Bills", style: TextStyle(color: Colors.white)),
//         backgroundColor: const Color(0xFF1A1A1A),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: GridView.builder(
//         padding: const EdgeInsets.all(16),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 3,
//           childAspectRatio: 0.9,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//         ),
//         itemCount: billCategories.length,
//         itemBuilder: (context, index) {
//           final cat = billCategories[index];
//           return InkWell(
//             borderRadius: BorderRadius.circular(12),
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => BBPSPaymentScreen(
//                     preselectedCategory: cat['categoryId'],
//                     categoryName: cat['name'],
//                     categoryEmoji: cat['emoji'],
//                   ),
//                 ),
//               );
//             },
//             child: Container(
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1A1A1A),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.grey[800]!),
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(cat['emoji']!, style: const TextStyle(fontSize: 28)),
//                   const SizedBox(height: 8),
//                   Text(
//                     cat['name']!,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(color: Colors.white, fontSize: 11),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }