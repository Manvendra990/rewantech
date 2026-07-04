import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rtstrack/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _nameController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  bool _isCreating = false;
  String? _uid;
  String? _userRole;
  String _userName = '';

  static const _bg = Color(0xFFF0F4FF);
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _blue = Color(0xFF2F6FED);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid == null) return;

    final doc = await _firestore.collection('registration').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _uid = uid;
      _userRole = doc.data()?['role'] ?? '';
      _userName = doc.data()?['name'] ?? '';
    });
  }

  bool get _isAdmin => _userRole == 'Admin';

  Future<void> _createProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_uid == null) return;

    setState(() => _isCreating = true);

    await _firestore.collection('projects').add({
      'name': name,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _nameController.clear();
    setState(() => _isCreating = false);

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 20),
            const Text(
              'New Project',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _heading,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Project name...',
                filled: true,
                fillColor: const Color(0xFFEDF1FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createProject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String projectId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete it?'),
        content: Text('"$name" delete ho jayega.'),
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
      await _firestore.collection('projects').doc(projectId).delete();
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final dt = ts.toDate();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return 'Modified ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Modified ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Modified yesterday';
    return 'Modified ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                   const SizedBox(width: 10),
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
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Projects Title + New Button ─────────────
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Projects',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _heading,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showCreateSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'New',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── List ────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('projects')
                    .snapshots(), // orderBy hata diya — index issue avoid
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  // if (docs.isEmpty) {
                  //   return SingleChildScrollView(
                  //     padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                  //     child: Column(
                  //       children: [
                  //         _cloudStorageCard(),
                  //         const SizedBox(height: 40),
                  //         _emptyState(),
                  //       ],
                  //     ),
                  //   );
                  // }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    // +1 for cloud card, +1 for empty state at bottom
                    itemCount: docs.length + 1,
                    itemBuilder: (context, i) {
                      // Cloud card after all projects
                      if (i == docs.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                        );
                      }

                      final data = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;
                      final name = data['name'] ?? '';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final isFirst = i == 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DashboardPage(
                                projectId: id,
                                projectName: name,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? const Color(0xFFDBE9FF)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.folder_outlined,
                                    color: isFirst
                                        ? _blue
                                        : const Color(0xFF9CA3AF),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _heading,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _timeAgo(createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _subtitle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isAdmin)
                                  GestureDetector(
                                    onTap: () => _confirmDelete(id, name),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFE11D48),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _blue,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFDBE9FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: _blue, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ready for more? Create a new\nproject to start building.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _heading,
          ),
        ),
      ],
    );
  }
}
