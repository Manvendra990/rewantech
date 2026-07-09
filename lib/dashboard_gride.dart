import 'package:flutter/material.dart';
import 'package:rtstrack/auth/register_page.dart';
import 'package:rtstrack/task_assing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rtstrack/services/task_services.dart';
import 'package:rtstrack/compney_info/employee/team_attendance.dart';
import 'package:rtstrack/lead/leads_screen.dart';
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
  // int _navIndex = 0;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _leadNotifService = LeadNotificationService();
  final _taskService = TaskService();
  Map<String, dynamic>? _userData;
  late Future<Map<String, dynamic>> _attendanceFuture;

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

  // ---------------------------------------------------------------------
  // Task actions: mark complete / edit
  // ---------------------------------------------------------------------

  Future<void> _markTaskComplete(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final projectId = doc.reference.parent.parent?.id;
    if (projectId == null) return;

    final completedByName = (_userData?['name'] ?? 'Unknown').toString();

    try {
      await _taskService.markTaskComplete(projectId, doc.id, completedByName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task marked as completed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  void _showEditTaskDialog(BuildContext context, QueryDocumentSnapshot doc) {
    final projectId = doc.reference.parent.parent?.id;
    if (projectId == null) return;

    final data = doc.data() as Map<String, dynamic>;

    final titleController = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final descController = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );
    String priority = (data['priority'] ?? 'medium').toString();

    // Preserve existing assignees as-is (not editable in this quick dialog)
    final assignedUids = List<String>.from(data['assignedToUids'] ?? []);
    final assignedNames = List<String>.from(data['assignedToNames'] ?? []);
    final assignees = List<Map<String, String>>.generate(
      assignedUids.length,
      (i) => {
        'uid': assignedUids[i],
        'name': i < assignedNames.length ? assignedNames[i] : '',
      },
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newTitle = titleController.text.trim();
                    if (newTitle.isEmpty) return;

                    final error = await _taskService.updateTask(
                      projectId: projectId,
                      taskId: doc.id,
                      title: newTitle,
                      description: descController.text.trim(),
                      reminderDate: data['reminderDate'],
                      reminderTime: data['reminderTime'],
                      priority: priority,
                      assignees: assignees,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error == null
                                ? 'Task updated'
                                : 'Failed to update: $error',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Pending tasks bottom sheet
  // ---------------------------------------------------------------------

  void _showPendingTasksSheet(
    BuildContext context,
    List<QueryDocumentSnapshot> pendingDocs,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    'Pending Tasks (${pendingDocs.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _heading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: pendingDocs.isEmpty
                        ? const Center(
                            child: Text(
                              'No pending tasks 🎉',
                              style: TextStyle(color: _subtitle),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: pendingDocs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = pendingDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final title = (data['title'] ?? 'Untitled Task')
                                  .toString();
                              final status = (data['status'] ?? 'pending')
                                  .toString();
                              final priority = (data['priority'] ?? '')
                                  .toString();
                              final reminderDate = data['reminderDate'];

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _markTaskComplete(context, doc),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          if (reminderDate != null &&
                                              reminderDate
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 3,
                                              ),
                                              child: Text(
                                                'Due: $reminderDate',
                                                style: const TextStyle(
                                                  color: _subtitle,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ),
                                          if (priority.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                'Priority: $priority',
                                                style: const TextStyle(
                                                  color: _subtitle,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      color: _subtitle,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _showEditTaskDialog(context, doc),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AttendanceScreen()),
            );
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
            .where('status', isEqualTo: 'new')
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
                    onTap: () => _showPendingTasksSheet(context, pendingDocs),
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

  _DashboardItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.countStream,
    this.totalStream,
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
                  Text(
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
