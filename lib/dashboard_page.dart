import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:rtstrack/assign_task_page.dart';
import 'package:rtstrack/auth/login_page.dart';
// import 'package:rtstrack/compney_info/employee/team_screen.dart';
// import 'package:rtstrack/profilescreen.dart';
import 'package:rtstrack/services/auth_services.dart';
import 'package:rtstrack/services/lead_notifire_service.dart';
import 'package:rtstrack/services/task_services.dart';
import 'package:rtstrack/widgets/alarm_helper.dart';
import 'package:rtstrack/widgets/custom_app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rtstrack/task_assing_screen.dart';

class DashboardPage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const DashboardPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _authService = AuthService();
  final _taskService = TaskService();

  // int _navIndex = 0;
  Map<String, dynamic>? _userData;

  Stream<QuerySnapshot>? _tasksStream;
  late final Stream<List<Map<String, dynamic>>> _teammatesStream;
  late Future<Map<String, dynamic>> _attendanceFuture;
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _leadNotifService = LeadNotificationService();

  // ✅ Admin check — same pattern used across the app (ProjectScreen, etc.)
  bool get _isAdmin =>
      (_userData?['role'] ?? '').toString().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    AlarmHelper.requestPermissions();
    _loadUser();
    _teammatesStream = _taskService.getTeammates();
    _attendanceFuture = _taskService.getMyAttendanceSummary();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');

    if (uid != null) {
      final data = await _authService.getUserData(uid);
      if (!mounted) return;

      await prefs.setString('name', data?['name'] ?? ''); // ✅ yeh add karo

      setState(() {
        _userData = data;
        // ✅ Admin sees ALL tasks in this project (no assignee filter).
        // Non-admins only see tasks assigned to them, same as before.
        _tasksStream = _isAdmin
            ? FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('tasks')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
            : _taskService.getMyTasks(widget.projectId);
      });
    }
  }

  Widget _attachmentIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
      icon = Icons.image_outlined;
      color = const Color(0xFF2F6FED);
    } else if (ext == 'pdf') {
      icon = Icons.picture_as_pdf_outlined;
      color = const Color(0xFFE11D48);
    } else {
      icon = Icons.attach_file;
      color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _openAttachment(String url, String fileName) async {
    if (url.isEmpty) return;

    final ext = fileName.split('.').last.toLowerCase();

    // Image preview
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Other files — url_launcher se open karo
      // pubspec mein add karo: url_launcher: ^6.0.0
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening: $fileName'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFE11D48);
      case 'High':
        return const Color(0xFF2F6FED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _priorityBg(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFFDE2E6);
      case 'High':
        return const Color(0xFFE3EBFD);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Widget _initialsAvatar(String name, {double radius = 18}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF111827),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showTaskDetail(
    BuildContext context,
    String taskId,
    Map<String, dynamic> data,
  ) {
    final priority = data['priority'] ?? 'Medium';
    final assignedNames = data['assignedToNames'] as List? ?? [];
    final status = data['status'] ?? 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Handle
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
            const SizedBox(height: 20),

            // Priority + Edit button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityBg(priority),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(priority),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'completed'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: status == 'completed'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFCA8A04),
                    ),
                  ),
                ),
                const Spacer(),
                // Edit button — admin only
                if (_isAdmin)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignTaskPage(
                            projectId: widget.projectId,
                            projectName: widget.projectName,
                            taskId: taskId, // ✅ pass karo
                            existingData: data, // ✅ pass karo
                          ),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF2F6FED),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Project name
            Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  data['projectName'] ?? widget.projectName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              data['title'] ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            if ((data['description'] ?? '').toString().trim().isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Reminder
            const Text(
              'Reminder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  data['reminderDate'] != null
                      ? '${data['reminderDate']}  ${data['reminderTime'] ?? ''}'
                      : 'No date set',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Attachment
            if ((data['attachmentName'] ?? '').isNotEmpty) ...[
              const Text(
                'Attachment',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openAttachment(
                  data['attachmentUrl'] ?? '',
                  data['attachmentName'] ?? '',
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _attachmentIcon(data['attachmentName'] ?? ''),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['attachmentName'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Tap to open',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Assigned to
            const Text(
              'Assigned To',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            ...assignedNames.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF111827),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Mark complete — sirf pending tasks ke liye, aur sirf admin ko
            if (status == 'pending' && _isAdmin)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await AlarmHelper.cancelTaskAlarm(taskId);
                    await _taskService.markTaskComplete(
                      widget.projectId,
                      taskId,
                      _userData?['name'] ?? 'Unknown', // 👈 add karo
                    );
                  },
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Mark as Complete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Project task list bottom sheet — shared by the "Completed"/"Active"
  // buttons, the Daily Momentum card, and the Critical/High priority
  // cards. `docs` should already be filtered to whatever subset the
  // caller wants shown; `title`/`emptyMessage` adapt the header + empty
  // state. Reuses _showTaskDetail for full detail / edit / mark-complete,
  // so we don't duplicate that logic here.
  // ---------------------------------------------------------------------
  void _showTasksSheet(
    BuildContext context,
    List<QueryDocumentSnapshot> docs, {
    required String title,
    required String emptyMessage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    '$title (${docs.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _heading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: docs.isEmpty
                        ? Center(
                            child: Text(
                              emptyMessage,
                              style: const TextStyle(
                                color: _subtitle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final taskTitle =
                                  (data['title'] ?? 'Untitled Task')
                                      .toString();
                              final priority = (data['priority'] ?? 'Medium')
                                  .toString();
                              final reminderDate = data['reminderDate'];
                              final isCompleted =
                                  data['status'] == 'completed';

                              return GestureDetector(
                                onTap: () {
                                  // Close this sheet, then open full task
                                  // detail (which already has edit +
                                  // mark-complete built in).
                                  Navigator.pop(sheetContext);
                                  _showTaskDetail(context, doc.id, data);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F6FA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _priorityBg(priority),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              taskTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isCompleted
                                            ? Icons.check_circle
                                            : Icons.chevron_right,
                                        size: isCompleted ? 18 : 20,
                                        color: isCompleted
                                            ? const Color(0xFF16A34A)
                                            : _subtitle,
                                      ),
                                    ],
                                  ),
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

  // ── Completed / Active toggle buttons shown above the task list ──
  Widget _taskStatusButtons({
    required List<QueryDocumentSnapshot> completedDocs,
    required List<QueryDocumentSnapshot> activeDocs,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showTasksSheet(
              context,
              completedDocs,
              title: 'Completed Tasks',
              emptyMessage: 'No completed tasks yet',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Completed (${completedDocs.length})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _showTasksSheet(
              context,
              activeDocs,
              title: 'Active Tasks',
              emptyMessage: 'No pending tasks 🎉',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active (${activeDocs.length})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F6FED),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteTask(String taskId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Task delete karein?'),
        content: Text(
          '"$title" permanently delete ho jayega. Ye undo nahi ho sakta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE11D48)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AlarmHelper.cancelTaskAlarm(taskId);
      await _taskService.deleteTask(widget.projectId, taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task delete ho gaya')));
    }
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

  // ✅ Now takes the actual doc lists (not just counts) and is tappable —
  // tapping Critical or High opens the same bottom sheet used everywhere
  // else on this page, filtered to that priority.
  Widget _priorityCards({
    required List<QueryDocumentSnapshot> criticalDocs,
    required List<QueryDocumentSnapshot> highDocs,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showTasksSheet(
              context,
              criticalDocs,
              title: 'Critical Tasks',
              emptyMessage: 'No critical tasks 🎉',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE2E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${criticalDocs.length}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Critical',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: () => _showTasksSheet(
              context,
              highDocs,
              title: 'High Priority Tasks',
              emptyMessage: 'No high priority tasks 🎉',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBFD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${highDocs.length}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2F6FED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'High',
                    style: TextStyle(
                      color: Color(0xFF2F6FED),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tasksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: _heading,
                ),
              ),
              const SizedBox(width: 10),
              // 👇 Project name header me dikhao
              Expanded(
                child: Text(
                  widget.projectName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _heading,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                child: StreamBuilder<int>(
                  stream: _leadNotifService.unreadCountStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _initialsAvatar(_userData?['name'] ?? '', radius: 16),
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
            ],
          ),
        ),

        const Divider(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search tasks or owners...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFEDF1FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _tasksStream,
            builder: (context, snapshot) {
              if (_tasksStream == null || !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final allDocs = snapshot.data!.docs;

              final activeDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'pending'; // ✅ active → pending
              }).toList();

              // Used by the "Completed" button + sheet above the task
              // list. Filtered on the exact 'completed' status (rather
              // than "everything that isn't pending") so the sheet only
              // ever shows genuinely completed tasks for this project.
              final completedDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'completed';
              }).toList();

              final completedCount = allDocs.length - activeDocs.length;
              final progress = allDocs.isEmpty
                  ? 0.0
                  : completedCount / allDocs.length;

              // ✅ Now kept as doc lists (not just counts) so the priority
              // cards can open the bottom sheet with the exact matching
              // tasks.
              final criticalDocs = activeDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['priority'] == 'Critical';
              }).toList();

              final highDocs = activeDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['priority'] == 'High';
              }).toList();

              if (activeDocs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showTasksSheet(
                          context,
                          activeDocs,
                          title: 'Active Tasks',
                          emptyMessage: 'No pending tasks 🎉',
                        ),
                        child: _momentumCard(
                          activeCount: activeDocs.length,
                          progress: progress,
                        ),
                      ),
                      // const SizedBox(height: 14),
                      // _attendanceCard(),
                      const SizedBox(height: 14),
                      _priorityCards(
                        criticalDocs: criticalDocs,
                        highDocs: highDocs,
                      ),
                      const SizedBox(height: 20),
                      _taskStatusButtons(
                        completedDocs: completedDocs,
                        activeDocs: activeDocs,
                      ),
                      const SizedBox(height: 32),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'There are no active tasks 🎉',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _subtitle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ✅ FIX: uses the SAME activeDocs/progress computed above
                  // from _tasksStream (this project only), instead of the
                  // old separate getAllMyTasks() stream. That duplicate
                  // stream queried across ALL projects (ignoring this one)
                  // and needed a composite Firestore index it likely didn't
                  // have — so it silently failed and always fell back to
                  // activeCount: 0, progress: 0. That's why the bar looked
                  // static no matter what you did on this screen.
                  GestureDetector(
                    onTap: () => _showTasksSheet(
                      context,
                      activeDocs,
                      title: 'Active Tasks',
                      emptyMessage: 'No pending tasks 🎉',
                    ),
                    child: _momentumCard(
                      activeCount: activeDocs.length,
                      progress: progress,
                    ),
                  ),

                  const SizedBox(height: 14),
                  // _attendanceCard(),
                  // const SizedBox(height: 14),
                  _priorityCards(
                    criticalDocs: criticalDocs,
                    highDocs: highDocs,
                  ),
                  const SizedBox(height: 20),
                  // ── Completed (left) / Active (right) buttons — tap
                  // either to open the full task list for this project,
                  // filtered to that status. ──
                  _taskStatusButtons(
                    completedDocs: completedDocs,
                    activeDocs: activeDocs,
                  ),
                  const SizedBox(height: 10),
                  ...activeDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final priority = data['priority'] ?? 'Medium';
                    final title = data['title'] ?? '';
                    final description = (data['description'] ?? '')
                        .toString()
                        .trim();
                    final assignedNames =
                        data['assignedToNames'] as List? ?? [];
                    final createdByName = (data['assignedByName'] ?? '')
                        .toString();
                    return GestureDetector(
                      // ✅ ye add karo
                      onTap: () => _showTaskDetail(context, doc.id, data),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              // onTap: () async {
                              //   await AlarmHelper.cancelTaskAlarm(doc.id);
                              //   await _taskService.markTaskComplete(
                              //     widget.projectId,
                              //     doc.id,
                              //     _userData?['name'] ??
                              //         'Unknown', // 👈 add karo
                              //   );
                              // },
                              // child: Container(
                              //   margin: const EdgeInsets.only(
                              //     top: 22,
                              //     right: 10,
                              //   ),
                              //   width: 22,
                              //   height: 22,
                              //   decoration: BoxDecoration(
                              //     shape: BoxShape.circle,
                              //     border: Border.all(
                              //       color: const Color(0xFF2F6FED),
                              //       width: 2,
                              //     ),
                              //   ),
                              // ),
                              child: Icon(
                                Icons.push_pin_rounded,
                                color: Colors.red,
                              ),
                            ),
                            Expanded(
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          priority.toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _priorityColor(priority),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: _subtitle,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['reminderDate'] != null
                                              ? '${data['reminderDate']} ${data['reminderTime'] ?? ''}'
                                              : 'No date',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _subtitle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _heading,
                                    ),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _subtitle,
                                      ),
                                    ),
                                  ],
                                  // 👇 Attachment name dikhao agar hai
                                  if ((data['attachmentName'] ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.attach_file,
                                          size: 13,
                                          color: _subtitle,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            data['attachmentName'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _subtitle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 👇 "Created by" — shown at the right side of
                            // the card. Falls back gracefully if the task
                            // doc doesn't have this field (older tasks).
                            if (createdByName.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Created by',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _subtitle,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 9,
                                        backgroundColor: _heading,
                                        child: Text(
                                          createdByName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 70,
                                        ),
                                        child: Text(
                                          createdByName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _heading,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                            // IconButton(
                            //   onPressed: () => _confirmDeleteTask(doc.id, title),
                            //   icon: const Icon(
                            //     Icons.delete_outline,
                            //     color: Color(0xFFE11D48),
                            //     size: 20,
                            //   ),
                            //   padding: EdgeInsets.zero,
                            //   constraints: const BoxConstraints(),
                            //   splashRadius: 18,
                            // ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _teamTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _teammatesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final team = snapshot.data!;

        if (team.isEmpty) {
          return const Center(
            child: Text(
              'Team members nahi mile',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _subtitle,
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          itemCount: team.length,
          itemBuilder: (context, i) {
            final member = team[i];
            return ListTile(
              leading: _initialsAvatar(member['name'] ?? ''),
              title: Text(
                member['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(member['role'] ?? ''),
            );
          },
        );
      },
    );
  }

  Widget _profileTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _initialsAvatar(_userData?['name'] ?? '', radius: 32),
          const SizedBox(height: 14),
          Text(
            _userData?['name'] ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _userData?['email'] ?? '',
            style: const TextStyle(color: _subtitle),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: ${_userData?['role'] ?? ''}',
            style: const TextStyle(color: _subtitle),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _authService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      onEndDrawerChanged: (isOpen) {
        if (!isOpen) {
          // Drawer band hone par mark read — user ne dekh liya
          _leadNotifService.markAllRead();
        }
      },
      endDrawer: AppDrawer(
        userData: _userData,
        projectName: widget.projectName,
      ),
      body: SafeArea(child: _tasksTab()),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F6FED),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssignTaskPage(
                projectId: widget.projectId,
                projectName: widget.projectName,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}