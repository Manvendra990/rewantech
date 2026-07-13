import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EAttendanceHistoryScreen extends StatefulWidget {
  const EAttendanceHistoryScreen({super.key});

  @override
  State<EAttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<EAttendanceHistoryScreen> {
  static const _heading = Color(0xFF111827);
  static const _present = Color(0xFF16A34A);
  static const _absent = Color(0xFFDC2626);
  static const _leave = Color(0xFFF59E0B);

  late DateTime _focusedMonth;
  late DateTime _today;
  DateTime? _selectedDay;

  bool _loading = true;
  // date-only DateTime (time stripped) -> status string
  Map<DateTime, String> _statusByDay = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = _today;
    _loadMonth(_focusedMonth);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _statusByDay = {};
        _loading = false;
      });
      return;
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final map = <DateTime, String>{};

    try {
      final futures = <Future<void>>[];
      for (var day = 1; day <= daysInMonth; day++) {
        final date = DateTime(month.year, month.month, day);
        final docId = DateFormat('yyyy-MM-dd').format(date);
        futures.add(
          FirebaseFirestore.instance
              .collection('attendance')
              .doc(docId)
              .collection('members')
              .doc(uid)
              .get()
              .then((snap) {
                if (snap.exists) {
                  map[date] = (snap.data()?['status'] ?? 'absent').toString();
                }
              }),
        );
      }
      await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _statusByDay = map;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load attendance: $e')));
    }
  }

  void _changeMonth(int delta) {
    final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    setState(() => _focusedMonth = newMonth);
    _loadMonth(newMonth);
  }

  Color? _dotColor(String? status) {
    switch (status) {
      case 'present':
        return _present;
      case 'absent':
        return _absent;
      case 'leave':
      case 'holiday':
        return _leave;
    }
    return null;
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fullDateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _markToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final status = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mark today's attendance",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: _present),
                  title: const Text('Present'),
                  onTap: () => Navigator.pop(context, 'present'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: _absent),
                  title: const Text('Absent'),
                  onTap: () => Navigator.pop(context, 'absent'),
                ),
                ListTile(
                  leading: const Icon(Icons.beach_access, color: _leave),
                  title: const Text('Leave'),
                  onTap: () => Navigator.pop(context, 'leave'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (status == null) return;

    try {
      final docId = DateFormat('yyyy-MM-dd').format(_today);
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .collection('members')
          .doc(uid)
          .set({'status': status});
      _loadMonth(_focusedMonth);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final selectedStatus = _selectedDay != null
        ? _statusByDay[_selectedDay]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        foregroundColor: _heading,
        title: const Text(
          'Attendance History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _markToday,
        backgroundColor: primary,
        tooltip: "Mark today's attendance",
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMPLOYEE PORTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _heading,
                ),
              ),
              const SizedBox(height: 20),

              // ---------------- Action buttons ----------------
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export coming soon')),
                        );
                      },
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Report'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _heading,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request leave coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text('Request Leave'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---------------- Calendar card ----------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _monthLabel(_focusedMonth),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _heading,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _loading
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          )
                        : _CalendarGrid(
                            month: _focusedMonth,
                            today: _today,
                            selectedDay: _selectedDay,
                            statusByDay: _statusByDay,
                            dotColorFor: _dotColor,
                            primary: primary,
                            onDayTap: (day) {
                              setState(() => _selectedDay = day);
                            },
                          ),
                  ],
                ),
              ),

              if (_selectedDay != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color:
                              _dotColor(selectedStatus) ?? Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _fullDateLabel(_selectedDay!),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _heading,
                          ),
                        ),
                      ),
                      Text(
                        selectedStatus != null
                            ? selectedStatus[0].toUpperCase() +
                                  selectedStatus.substring(1)
                            : 'No record',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              _dotColor(selectedStatus) ?? Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ---------------- Legend ----------------
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: const [
                  _LegendDot(color: _present, label: 'Present'),
                  _LegendDot(color: _absent, label: 'Absent'),
                  _LegendDot(color: _leave, label: 'Leave'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final Map<DateTime, String> statusByDay;
  final Color? Function(String?) dotColorFor;
  final Color primary;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.statusByDay,
    required this.dotColorFor,
    required this.primary,
    required this.onDayTap,
  });

  static const _weekdayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  bool _isWeekend(DateTime d) => d.weekday == DateTime.sunday;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Mon=1 ... Sun=7. Grid starts on Monday, matching
    // the MON..SUN header row.
    final leadingBlanks = firstOfMonth.weekday - 1;

    final cells = <Widget>[];

    for (final label in _weekdayLabels) {
      cells.add(
        Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = _isSameDay(date, today);
      final isSelected = selectedDay != null && _isSameDay(date, selectedDay!);
      final isWeekend = _isWeekend(date);
      final status = statusByDay[date];
      final dotColor = dotColorFor(status);

      final highlightToday = isToday;
      final highlightSelectedOnly = isSelected && !isToday;

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: highlightToday
                  ? primary.withValues(alpha: 0.12)
                  : highlightSelectedOnly
                  ? Colors.grey.shade100
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: highlightToday
                  ? Border.all(color: primary, width: 1.2)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isWeekend
                        ? Colors.grey.shade300
                        : (isToday ? primary : const Color(0xFF111827)),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 6,
                  child: dotColor != null
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 0.75,
      children: cells,
    );
  }
}
