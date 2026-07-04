import 'package:flutter/material.dart';
import 'package:rtstrack/auth/register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rtstrack/compney_info/customer/customer_screen.dart';
import 'package:rtstrack/compney_info/employee/attendance_history.dart';
import 'package:rtstrack/compney_info/employee/team_attendance.dart';
import 'package:rtstrack/compney_info/employee/team_screen.dart';
import 'package:rtstrack/compney_info/pament/pament_history.dart';
import 'package:rtstrack/compney_info/tools/doman_detail.dart';
import 'package:rtstrack/compney_info/tools/subscription_Details.dart';
import 'package:rtstrack/lead/leads_screen.dart';
import 'package:rtstrack/profilescreen.dart';
import 'package:rtstrack/project_screen.dart';
import 'package:rtstrack/services/auth_services.dart';
import 'package:rtstrack/services/lead_notifire_service.dart';
import 'package:rtstrack/widgets/custom_app_drawer.dart';

class DashboardGridScreen extends StatefulWidget {
  const DashboardGridScreen({super.key});

  @override
  State<DashboardGridScreen> createState() => _DashboardGridScreenState();
}

class _DashboardGridScreenState extends State<DashboardGridScreen> {
  int _navIndex = 0;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _leadNotifService = LeadNotificationService();
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid == null) return;

    final data = await _authService.getUserData(uid);
    if (!mounted) return;
    setState(() => _userData = data);
  }

  Widget _momentumCard({required int activeCount, required double progress}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Momentum',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have $activeCount active tasks today. Stay focused.',
            style: const TextStyle(color: _subtitle, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Progress',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E9F5),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final items = <_DashboardItem>[
      _DashboardItem(
        icon: Icons.folder_outlined,
        label: 'Projects',
        subtitle: 'Manage Work',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProjectScreen()),
          );
        },
      ),
      _DashboardItem(
        icon: Icons.groups_outlined,
        label: 'Leads',
        subtitle: 'Sales Pipeline',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeadsScreen()),
          );
        },
      ),

      _DashboardItem(
        icon: Icons.how_to_reg_outlined,
        label: 'Attendance',
        subtitle: 'Mark Presence',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AttendanceScreen()),
          );
        },
      ),
      _DashboardItem(
        icon: Icons.how_to_reg_outlined,
        label: 'Add User',
        subtitle: 'Manage Users',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RegisterPage()),
          );
        },
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      onEndDrawerChanged: (isOpen) {
        if (!isOpen) {
          // Drawer band hone par mark read — user ne dekh liya
          _leadNotifService.markAllRead();
        }
      },
      endDrawer: AppDrawer(userData: _userData, projectName: ''),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.grid_view_rounded, color: primary),
            const SizedBox(width: 8),
            Text(
              'Dashboard',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: StreamBuilder<int>(
                stream: _leadNotifService.unreadCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primary.withOpacity(0.1),
                        child: Text(
                          (_userData?['name'] ?? '').toString().isNotEmpty
                              ? (_userData!['name'] as String)[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE11D48),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${_userData?['name'] ?? 'Alex'}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here is your daily activity overview.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _momentumCard(activeCount: 8, progress: 0.65),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Active Projects', value: '12'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'New Leads', value: '08'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  return _DashboardCard(item: items[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  _DashboardItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _DashboardCard extends StatelessWidget {
  final _DashboardItem item;

  const _DashboardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: primary, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
