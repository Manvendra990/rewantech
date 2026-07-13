import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rtstrack/services/task_services.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _taskService = TaskService();
  final _firestore = FirebaseFirestore.instance;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _blue = Color(0xFF2F6FED);

  bool _saving = false;

  // uid → 'present' | 'absent' | 'leave'
  final Map<String, String> _statusMap = {};

  Future<void> _loadTodayAttendance(List<Map<String, dynamic>> members) async {
    final snap = await _firestore
        .collection('attendance')
        .doc(today)
        .collection('members')
        .get();

    final Map<String, String> loaded = {};
    for (final doc in snap.docs) {
      loaded[doc.id] = doc.data()['status'] ?? 'absent';
    }

    // jo load nahi hue unhe default 'absent'
    for (final m in members) {
      final uid = m['uid'] as String;
      loaded.putIfAbsent(uid, () => 'absent');
    }

    if (!mounted) return;
    setState(
      () => _statusMap
        ..clear()
        ..addAll(loaded),
    );
  }

  Future<void> _saveAttendance(List<Map<String, dynamic>> members) async {
    setState(() => _saving = true);

    final batch = _firestore.batch();
    final dateRef = _firestore.collection('attendance').doc(today);

    // Date doc
    batch.set(dateRef, {
      'date': today,
      'markedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final m in members) {
      final uid = m['uid'] as String;
      final ref = dateRef.collection('members').doc(uid);
      batch.set(ref, {
        'uid': uid,
        'name': m['name'],
        'status': _statusMap[uid] ?? 'absent',
        'date': today,
      });
    }

    await batch.commit();
    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved successfully ✅')),
    );
    Navigator.pop(context, true);
  }

  // Sab members ko ek saath present/absent mark karne ke liye
  void _toggleAllPresent(bool? value, List<Map<String, dynamic>> members) {
    setState(() {
      for (final m in members) {
        final uid = m['uid'] as String;
        _statusMap[uid] = (value ?? false) ? 'present' : 'absent';
      }
    });
  }

  Widget _statusChip(
    String uid,
    String label,
    Color color,
    Color bg,
    IconData icon,
  ) {
    final selected = _statusMap[uid] == label.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _statusMap[uid] = label.toLowerCase()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _heading),
        title: const Text(
          'Attendance',
          style: TextStyle(
            color: _heading,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3EBFD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _taskService.getTeammates(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!;

          // Pehli baar load karo
          if (_statusMap.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadTodayAttendance(members);
            });
          }

          final presentCount = _statusMap.values
              .where((s) => s == 'present')
              .length;
          final absentCount = _statusMap.values
              .where((s) => s == 'absent')
              .length;
          final leaveCount = _statusMap.values
              .where((s) => s == 'leave')
              .length;

          // Sab present hain ya nahi, checkbox ki state ke liye
          final allPresent =
              members.isNotEmpty &&
              members.every((m) => _statusMap[m['uid'] as String] == 'present');

          return Column(
            children: [
              // Select all present checkbox
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      Checkbox(
                        value: allPresent,
                        activeColor: const Color(0xFF16A34A),
                        onChanged: (value) => _toggleAllPresent(value, members),
                      ),
                      const Text(
                        'Mark all Present',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _heading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Summary cards
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _summaryCard(
                      'Present',
                      presentCount,
                      const Color(0xFF16A34A),
                      const Color(0xFFDCFCE7),
                    ),
                    const SizedBox(width: 10),
                    _summaryCard(
                      'Absent',
                      absentCount,
                      const Color(0xFFE11D48),
                      const Color(0xFFFDE2E6),
                    ),
                    const SizedBox(width: 10),
                    _summaryCard(
                      'Leave',
                      leaveCount,
                      const Color(0xFFCA8A04),
                      const Color(0xFFFEF9C3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: members.length,
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final uid = m['uid'] as String;
                    final name = m['name'] as String;
                    final role = m['role'] as String;

                    return Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _heading,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: _heading,
                                      ),
                                    ),
                                    Text(
                                      role,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _subtitle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              _statusChip(
                                uid,
                                'Present',
                                const Color(0xFF16A34A),
                                const Color(0xFFDCFCE7),
                                Icons.check_circle_outline,
                              ),
                              _statusChip(
                                uid,
                                'Absent',
                                const Color(0xFFE11D48),
                                const Color(0xFFFDE2E6),
                                Icons.cancel_outlined,
                              ),
                              _statusChip(
                                uid,
                                'Leave',
                                const Color(0xFFCA8A04),
                                const Color(0xFFFEF9C3),
                                Icons.event_busy_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // Save button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _heading,
        onPressed: _saving
            ? null
            : () async {
                final members = await _taskService.getTeammates().first;
                await _saveAttendance(members);
              },
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          _saving ? 'Saving...' : 'Save Attendance',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
