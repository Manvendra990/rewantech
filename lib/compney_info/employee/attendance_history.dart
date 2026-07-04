import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _blue = Color(0xFF2F6FED);

  // date → uid → status
  Map<String, Map<String, String>> _attendanceData = {};
  List<String> _dates = [];
  List<Map<String, String>> _members = []; // [{uid, name}]
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // 1. Saare members load karo
    final memberSnap = await _firestore.collection('registration').get();
    final members = memberSnap.docs
        .map((d) => {'uid': d.id, 'name': (d.data()['name'] ?? '') as String})
        .toList();

    // 2. Saari attendance dates load karo
    final dateSnap = await _firestore
        .collection('attendance')
        .orderBy('date', descending: true)
        .get();

    final Map<String, Map<String, String>> data = {};
    final List<String> dates = [];

    for (final dateDoc in dateSnap.docs) {
      final date = dateDoc.id;
      dates.add(date);
      data[date] = {};

      final memberSnap = await _firestore
          .collection('attendance')
          .doc(date)
          .collection('members')
          .get();

      for (final m in memberSnap.docs) {
        data[date]![m.id] = m.data()['status'] ?? 'absent';
      }
    }

    if (!mounted) return;
    setState(() {
      _members = members;
      _dates = dates;
      _attendanceData = data;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF16A34A);
      case 'leave':
        return const Color(0xFFCA8A04);
      default:
        return const Color(0xFFE11D48);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFFDCFCE7);
      case 'leave':
        return const Color(0xFFFEF9C3);
      default:
        return const Color(0xFFFDE2E6);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'P';
      case 'leave':
        return 'L';
      default:
        return 'A';
    }
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd MMM').format(d);
    } catch (_) {
      return date;
    }
  }

  // Member ka attendance summary
  Map<String, int> _memberSummary(String uid) {
    int present = 0, absent = 0, leave = 0;
    for (final date in _dates) {
      final status = _attendanceData[date]?[uid] ?? 'absent';
      if (status == 'present')
        present++;
      else if (status == 'leave')
        leave++;
      else
        absent++;
    }
    return {'present': present, 'absent': absent, 'leave': leave};
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
          'Attendance Report',
          style: TextStyle(
            color: _heading,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: _heading),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dates.isEmpty
          ? const Center(
              child: Text(
                'Koi attendance record nahi hai',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _subtitle,
                ),
              ),
            )
          : Column(
              children: [
                // Legend
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _legendChip(
                        'P',
                        'Present',
                        const Color(0xFF16A34A),
                        const Color(0xFFDCFCE7),
                      ),
                      const SizedBox(width: 8),
                      _legendChip(
                        'A',
                        'Absent',
                        const Color(0xFFE11D48),
                        const Color(0xFFFDE2E6),
                      ),
                      const SizedBox(width: 8),
                      _legendChip(
                        'L',
                        'Leave',
                        const Color(0xFFCA8A04),
                        const Color(0xFFFEF9C3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Table
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Table(
                          border: TableBorder.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          children: [
                            // Header row
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                              ),
                              children: [
                                // Name column header
                                _headerCell('Member', isFirst: true),
                                // Date columns
                                ..._dates.map(
                                  (d) => _headerCell(_formatDate(d)),
                                ),
                                // Summary columns
                                _headerCell('P'),
                                _headerCell('A'),
                                _headerCell('L'),
                              ],
                            ),

                            // Member rows
                            ..._members.map((member) {
                              final uid = member['uid']!;
                              final name = member['name']!;
                              final summary = _memberSummary(uid);

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: _members.indexOf(member) % 2 == 0
                                      ? Colors.white
                                      : const Color(0xFFF9FAFB),
                                ),
                                children: [
                                  // Name cell
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(
                                            0xFF111827,
                                          ),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: _heading,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Status cells
                                  ..._dates.map((date) {
                                    final status =
                                        _attendanceData[date]?[uid] ?? 'absent';
                                    return _statusCell(status);
                                  }),

                                  // Summary cells
                                  _summaryCell(
                                    '${summary['present']}',
                                    const Color(0xFF16A34A),
                                    const Color(0xFFDCFCE7),
                                  ),
                                  _summaryCell(
                                    '${summary['absent']}',
                                    const Color(0xFFE11D48),
                                    const Color(0xFFFDE2E6),
                                  ),
                                  _summaryCell(
                                    '${summary['leave']}',
                                    const Color(0xFFCA8A04),
                                    const Color(0xFFFEF9C3),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _headerCell(String text, {bool isFirst = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: isFirst ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusCell(String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _statusBg(status),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _statusColor(status),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCell(String value, Color color, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendChip(String code, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
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
    );
  }
}
