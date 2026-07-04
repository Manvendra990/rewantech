import 'package:flutter/material.dart';
import 'package:rtstrack/compney_info/employee/attendance_history.dart';
import 'package:rtstrack/compney_info/customer/customer_screen.dart';
import 'package:rtstrack/compney_info/employee/team_screen.dart';
import 'package:rtstrack/compney_info/pament/pament_history.dart';
// import 'package:rtstrack/dashboard_page.dart';
import 'package:rtstrack/compney_info/tools/doman_detail.dart';
import 'package:rtstrack/lead/leads_screen.dart';
import 'package:rtstrack/profilescreen.dart';
import 'package:rtstrack/services/auth_services.dart';
import 'package:rtstrack/auth/login_page.dart';
import 'package:rtstrack/compney_info/tools/subscription_Details.dart';
import 'package:rtstrack/compney_info/employee/team_attendance.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final String projectName;

  const AppDrawer({
    super.key,
    required this.userData,
    required this.projectName,
  });

  // ✅ isAdmin getter add karo
  bool get _isAdmin =>
      (userData?['role'] ?? '').toString().toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    final _authService = AuthService();
    final name = userData?['name'] ?? '';
    final role = userData?['role'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFF111827),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2F6FED),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'User' : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Menu Items ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                children: [
                  // _DrawerItem(
                  //   icon: Icons.show_chart,
                  //   label: 'DashBoard',
                  //   onTap: () {
                  //     // null tha, ab yeh karo
                  //     Navigator.pop(context);
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => const DashboardPage(projectId: '', projectName: '',),
                  //       ),
                  //     );
                  //   },
                  //   // trailing: Soon wala hata do
                  // ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen()),
                      );
                    },
                  ),
                  // _DrawerItem(
                  //   icon: Icons.show_chart,
                  //   label: 'Leads',
                  //   onTap: () {
                  //     // null tha, ab yeh karo
                  //     Navigator.pop(context);
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (_) => const LeadsScreen()),
                  //     );
                  //   },
                  //   // trailing: Soon wala hata do
                  // ),
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Team Board',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeamScreen()),
                      );
                    },
                  ),

                  // Attendance — sirf admin ko dikhao
                  // if (_isAdmin)
                  //   _DrawerItem(
                  //     icon: Icons.calendar_month_outlined,
                  //     label: 'Attendance',
                  //     onTap: () {
                  //       Navigator.pop(context);
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => const AttendanceScreen(),
                  //         ),
                  //       );
                  //     },
                  //   ),
                  if (_isAdmin)
                    _DrawerItem(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Customer Details',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(),
                          ),
                        );
                      },
                    ),
                  if (_isAdmin)
                    _DrawerItem(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Doman Details',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DomainDetailScreen(),
                          ),
                        );
                      },
                    ),
                  if (_isAdmin)
                    _DrawerItem(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Subscription Details',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionDetailScreen(),
                          ),
                        );
                      },
                    ),

                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Attendance History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttendanceHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  if (_isAdmin)
                    _DrawerItem(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Payment History',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentHistoryScreen(),
                          ),
                        );
                      },
                    ),

                  const Spacer(),
                  const Divider(),

                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: const Color(0xFFE11D48),
                    onTap: () async {
                      Navigator.pop(context);
                      await _authService.logout();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  }) : trailing = null;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF111827);
    final disabled = onTap == null;

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        icon,
        color: disabled ? const Color(0xFF9CA3AF) : c,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: disabled ? const Color(0xFF9CA3AF) : c,
        ),
      ),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
    );
  }
}
