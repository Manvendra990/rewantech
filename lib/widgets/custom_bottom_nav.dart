// import 'package:flutter/material.dart';

// class CustomBottomNav extends StatelessWidget {
//   final int currentIndex;
//   final ValueChanged<int> onTap;

//   const CustomBottomNav({
//     super.key,
//     required this.currentIndex,
//     required this.onTap,
//   });

//   static const _subtitle = Color(0xFF6B7280);
//   static const _selected = Color(0xFF2F6FED);

//   @override
//   Widget build(BuildContext context) {
//     return BottomNavigationBar(
//       currentIndex: currentIndex,
//       onTap: onTap,
//       selectedItemColor: _selected,
//       unselectedItemColor: _subtitle,
//       items: const [
//         BottomNavigationBarItem(
//           icon: Icon(Icons.assignment_outlined),
//           label: 'Tasks',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.groups_outlined),
//           label: 'Team Board',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.person_outline),
//           label: 'Profile',
//         ),
//       ],
//     );
//   }
// }
