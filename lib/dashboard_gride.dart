import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rtstrack/auth/register_page.dart';
// import 'package:rtstrack/compney_info/employee/attendance_history.dart';
import 'package:rtstrack/compney_info/employee/employee_attendance_history.dart';
import 'package:rtstrack/task_assing_screen.dart';
import 'package:rtstrack/task_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rtstrack/services/task_services.dart';
import 'package:rtstrack/compney_info/employee/team_attendance.dart';
import 'package:rtstrack/lead/leads_screen.dart';
import 'package:rtstrack/project_screen.dart';
import 'package:rtstrack/services/auth_services.dart';
import 'package:rtstrack/services/lead_notifire_service.dart';
import 'package:rtstrack/widgets/custom_app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardGridScreen extends StatefulWidget {
  const DashboardGridScreen({super.key});

  @override
  State<DashboardGridScreen> createState() => _DashboardGridScreenState();
}

class _DashboardGridScreenState extends State<DashboardGridScreen> {
  // int _navIndex = 0;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _leadNotifService = LeadNotificationService();
  final _taskService = TaskService();
  Map<String, dynamic>? _userData;
  late Future<Map<String, dynamic>> _attendanceFuture;

  // NOTE: adjust this if your user doc uses a different field/value for
  // role (e.g. 'isAdmin': true instead of 'role': 'admin').
  bool get _isAdmin =>
      (_userData?['role'] ?? '').toString().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _taskService.getMyAttendanceSummary();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid == null) return;

    final data = await _authService.getUserData(uid);
    if (!mounted) return;
    setState(() {
      _userData = data;
    });
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
            activeCount > 0
                ? 'You have $activeCount active tasks today. Stay focused.'
                : 'No active tasks right now. Nice and clear!',
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

  Widget _attendanceCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _attendanceFuture,
      builder: (context, snap) {
        final present = snap.data?['present'] ?? 0;
        final total = snap.data?['total'] ?? 0;
        final prog = total == 0 ? 0.0 : present / total;

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EAttendanceHistoryScreen(),
              ),
            );
            if (mounted) {
              setState(() {
                _attendanceFuture = _taskService.getMyAttendanceSummary();
              });
            }
          },
          child: Container(
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
                  'Attendance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$present / $total days present',
                  style: const TextStyle(fontSize: 12, color: _subtitle),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(prog * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: prog,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E9F5),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMemberTasks() {
    // final prefs = _userData;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final name = (_userData?['name'] ?? 'My Tasks').toString();

    if (uid.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          _MemberTasksSheet(uid: uid, name: name, taskService: _taskService),
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
        // Total count of all projects (adjust collection/query as needed)
        countStream: FirebaseFirestore.instance
            .collection('projects')
            .where('status', isEqualTo: 'new')
            .snapshots()
            .map((snap) => snap.docs.length),
        totalStream: FirebaseFirestore.instance
            .collection('projects')
            .snapshots()
            .map((snap) => snap.docs.length),
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
        // Total count of all leads (adjust collection/query as needed)
        countStream: FirebaseFirestore.instance
            .collection('leads')
            .where('status', isEqualTo: 'New')
            .snapshots()
            .map((snap) => snap.docs.length),
        totalStream: FirebaseFirestore.instance
            .collection('leads')
            .snapshots()
            .map((snap) => snap.docs.length),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeadsScreen()),
          );
        },
      ),

      if (_isAdmin)
        _DashboardItem(
          icon: Icons.how_to_reg_outlined,
          label: 'Attendance',
          subtitle: 'Mark Presence',
          // Live "present/total", shown beside the icon (not as the
          // subtitle) — X = today's attendance/{yyyy-MM-dd}/members docs
          // with status == 'present', Y = total registered employees.
          // Present count is highlighted in green.
          iconTrailingBuilder: (context) {
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registration')
                  .snapshots(),
              builder: (context, teamSnap) {
                final total = teamSnap.data?.docs.length ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .doc(todayStr)
                      .collection('members')
                      .where('status', isEqualTo: 'present')
                      .snapshots(),
                  builder: (context, presSnap) {
                    final present = presSnap.data?.docs.length ?? 0;
                    return RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: '$present',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: '/$total'),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AttendanceScreen()),
            );
            if (mounted) {
              setState(() {
                _attendanceFuture = _taskService.getMyAttendanceSummary();
              });
            }
          },
        ),
      if (_isAdmin)
        _DashboardItem(
          icon: Icons.people_alt_outlined,
          label: 'Add User',
          subtitle: 'Manage Users',

          // Total count of all members (adjust collection name to match your actual registration collection if this differs)
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            );
          },
        ),
      _DashboardItem(
        icon: Icons.playlist_add_check_circle_outlined,
        label: 'Assign Task',
        subtitle: 'New Task',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssignTaskPage()),
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
            // Icon(Icons.grid_view_rounded, color: primary),
            // const SizedBox(width: 8),
            // Text(
            //   'Dashboard',
            //   style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            // ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/app_icon.png', // 👈 apna path daal do
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(width: 10),
            const Text(
              'Rewan Tech',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _heading,
              ),
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
              StreamBuilder<QuerySnapshot>(
                stream: _taskService.getAllMyTasks(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _momentumCard(activeCount: 0, progress: 0);
                  }

                  final docs = snapshot.data!.docs;
                  final pendingDocs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['status'] != 'completed';
                  }).toList();

                  final total = docs.length;
                  final completed = total - pendingDocs.length;
                  final active = pendingDocs.length;
                  final progress = total == 0 ? 0.0 : completed / total;

                  return GestureDetector(
                    onTap: () => _showMemberTasks(),
                    child: _momentumCard(
                      activeCount: active,
                      progress: progress,
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _attendanceCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .where('status', isEqualTo: 'active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final loading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final count = snapshot.data?.docs.length ?? 0;
                        return _StatCard(
                          label: 'Active Projects',
                          value: loading
                              ? '--'
                              : count.toString().padLeft(2, '0'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leads')
                          .where('status', isEqualTo: 'new')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final loading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final count = snapshot.data?.docs.length ?? 0;
                        return _StatCard(
                          label: 'New Leads',
                          value: loading
                              ? '--'
                              : count.toString().padLeft(2, '0'),
                        );
                      },
                    ),
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
  // Optional stream of a total count to show as a badge on the card.
  final Stream<int>? countStream;
  final Stream<int>? totalStream;
  // Optional override to render a dynamic subtitle (e.g. a live
  // "3/12 present" string) instead of the static `subtitle` text.
  final Widget Function(BuildContext context)? subtitleBuilder;
  // Optional widget shown to the right of the icon (same row), e.g. a
  // live "3/12" present count.
  final Widget Function(BuildContext context)? iconTrailingBuilder;

  _DashboardItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.countStream,
    this.totalStream,
    this.subtitleBuilder,
    this.iconTrailingBuilder,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                      if (item.iconTrailingBuilder != null) ...[
                        const Spacer(),
                        item.iconTrailingBuilder!(context),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  item.totalStream == null
                      ? Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : StreamBuilder<int>(
                          stream: item.totalStream,
                          builder: (context, snapshot) {
                            final total = snapshot.data;
                            final text = total != null
                                ? '${item.label}    ($total)'
                                : item.label;
                            return Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 2),
                  item.subtitleBuilder != null
                      ? item.subtitleBuilder!(context)
                      : Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                ],
              ),
              if (item.countStream != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: StreamBuilder<int>(
                    stream: item.countStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count <= 0) return const SizedBox.shrink();
                      return Container(
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTasksSheet extends StatefulWidget {
  final String uid;
  final String name;
  final TaskService taskService;

  const _MemberTasksSheet({
    required this.uid,
    required this.name,
    required this.taskService,
  });

  @override
  State<_MemberTasksSheet> createState() => _MemberTasksSheetState();
}

class _MemberTasksSheetState extends State<_MemberTasksSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Critical':
        return const Color(0xFFE11D48);
      case 'High':
        return const Color(0xFF2F6FED);
      case 'Medium':
        return const Color(0xFFCA8A04);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _priorityBg(String p) {
    switch (p) {
      case 'Critical':
        return const Color(0xFFFDE2E6);
      case 'High':
        return const Color(0xFFE3EBFD);
      case 'Medium':
        return const Color(0xFFFEF9C3);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Widget _taskList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            ' Oh Oh!Has no task',
            style: TextStyle(color: _subtitle, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        final priority = data['priority'] ?? 'Medium';
        final status = data['status'] ?? 'pending';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailPage(
                  taskId: docs[i].id,
                  projectId: docs[i].reference.parent.parent?.id ?? '',
                  taskData: data,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _priorityBg(priority),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _priorityColor(priority),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'completed'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: status == 'completed'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCA8A04),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (data['reminderDate'] != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: _subtitle,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['reminderDate'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: _subtitle,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _heading,
                  ),
                ),
                if ((data['description'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    data['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _subtitle),
                  ),
                ],
                if ((data['projectName'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: _subtitle,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data['projectName'],
                        style: const TextStyle(fontSize: 11, color: _subtitle),
                      ),
                    ],
                  ),
                ],
                if (status == 'completed' &&
                    (data['completedBy'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Completed by ${data['completedBy']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
          70,
        ), // AppBar height + extra margin
        child: Padding(
          padding: const EdgeInsets.only(top: 36), // 👈 margin at top
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              "Task List",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _heading,
              ),
            ),
          ),
        ),
      ),
      body: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF111827),
                        child: Text(
                          widget.name.isNotEmpty
                              ? widget.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _heading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF1FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: _subtitle,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Pending'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('tasks')
                    .where('assignedToUids', arrayContains: widget.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final all = snapshot.data!.docs;
                  final pending = all.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['status'] == 'pending';
                  }).toList();
                  final completed = all.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['status'] == 'completed';
                  }).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [_taskList(pending), _taskList(completed)],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
