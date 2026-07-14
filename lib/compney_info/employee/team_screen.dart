import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rtstrack/services/task_services.dart';
import 'package:rtstrack/task_details_page.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _taskService = TaskService();
  late final Stream<List<Map<String, dynamic>>> _teammatesStream;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _blue = Color(0xFF2F6FED);

  @override
  void initState() {
    super.initState();
    _teammatesStream = _taskService.getTeammates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  void _showMemberTasks(Map<String, dynamic> member) {
    final uid = member['uid'] as String;
    final name = (member['name'] ?? '').toString();

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _teammatesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFE11D48),
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Team details loading',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _heading,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _subtitle, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allMembers = snapshot.data!;
            final team = allMembers
                .where(
                  (m) => (m['name'] ?? '').toString().toLowerCase().contains(
                    _searchQuery,
                  ),
                )
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Team Board',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _heading,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Your Team',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _heading,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3EBFD),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${allMembers.length} ${allMembers.length == 1 ? 'member' : 'members'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F6FED),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search teammates...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                      ),
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
                const SizedBox(height: 12),
                Expanded(
                  child: team.isEmpty
                      ? Center(
                          child: Text(
                            allMembers.isEmpty
                                ? 'No members right now...'
                                : 'No matching available...',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _subtitle,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: team.length,
                          itemBuilder: (context, i) {
                            final member = team[i];
                            final name = (member['name'] ?? '').toString();
                            final role = (member['role'] ?? '').toString();
                            final isMe =
                                member['uid'] == _taskService.currentUid;

                            return GestureDetector(
                              onTap: () => _showMemberTasks(member),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    _initialsAvatar(name, radius: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isEmpty ? 'Unnamed' : name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: _heading,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE5E9F5),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              role.isEmpty
                                                  ? 'No role set'
                                                  : role,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _subtitle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isMe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF111827),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'You',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 90,
        title: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Text(
            "Task List",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _heading,
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
