import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rtstrack/services/task_services.dart';

class AssignTaskPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String? taskId; // ✅ edit ke liye
  final Map<String, dynamic>? existingData; // ✅ prefill ke liye

  const AssignTaskPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.taskId,
    this.existingData,
  });

  @override
  State<AssignTaskPage> createState() => _AssignTaskPageState();
}

class _AssignTaskPageState extends State<AssignTaskPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _taskService = TaskService();
  late final Stream<List<Map<String, dynamic>>> _teammatesStream;

  DateTime? _reminderDate;
  TimeOfDay? _reminderTime;
  String _priority = 'High';
  final Map<String, String> _selectedAssignees = {};
  String _searchQuery = '';
  bool _loading = false;

  // 👇 Attachment ke liye
  PlatformFile? _pickedFile;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _fieldFill = Color(0xFFEDF1FA);

  @override
  void initState() {
    super.initState();
    _teammatesStream = _taskService.getTeammates();

    // ✅ Edit mode — existing data se prefill
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _titleCtrl.text = d['title'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _priority = d['priority'] ?? 'High';

      if (d['reminderDate'] != null) {
        _reminderDate = DateTime.tryParse(d['reminderDate']);
      }

      // assignees prefill
      final uids = d['assignedToUids'] as List? ?? [];
      final names = d['assignedToNames'] as List? ?? [];
      for (int i = 0; i < uids.length; i++) {
        _selectedAssignees[uids[i]] = names.length > i ? names[i] : '';
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _reminderDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  // 👇 File picker
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: kIsWeb, // web pe bytes chahiye, path nahi milega
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Widget _priorityChip(String label, IconData icon, Color color, Color bg) {
    final selected = _priority == label;
    return GestureDetector(
      onTap: () => setState(() => _priority = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignTask() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedAssignees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task title aur kam se kam ek teammate select karo'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final assignees = _selectedAssignees.entries
        .map((e) => {'uid': e.key, 'name': e.value})
        .toList();

    DateTime? reminderDateTime;
    if (_reminderDate != null && _reminderTime != null) {
      reminderDateTime = DateTime(
        _reminderDate!.year,
        _reminderDate!.month,
        _reminderDate!.day,
        _reminderTime!.hour,
        _reminderTime!.minute,
      );
    }

    String? error;

    if (widget.taskId != null) {
      // ✅ Edit mode — update karo
      error = await _taskService.updateTask(
        projectId: widget.projectId,
        taskId: widget.taskId!,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        reminderDate: _reminderDate != null
            ? DateFormat('yyyy-MM-dd').format(_reminderDate!)
            : null,
        reminderTime: _reminderTime != null
            ? _reminderTime!.format(context)
            : null,
        priority: _priority,
        assignees: assignees,
      );
    } else {
      // ✅ Create mode
      error = await _taskService.createTask(
        projectId: widget.projectId,
        projectName: widget.projectName,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        reminderDate: _reminderDate != null
            ? DateFormat('yyyy-MM-dd').format(_reminderDate!)
            : null,
        reminderTime: _reminderTime != null
            ? _reminderTime!.format(context)
            : null,
        priority: _priority,
        assignees: assignees,
        reminderDateTime: reminderDateTime,
        attachmentFile: _pickedFile,
      );
    }

    setState(() => _loading = false);

    if (error == null) {
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _heading),
        // 👇 Header me project name dikhao
        title: Text(
          widget.projectName,
          style: const TextStyle(
            color: _heading,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: const [
          Icon(Icons.notifications_none, color: _heading),
          SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Body ke top pe
          Text(
            widget.taskId != null ? 'Edit Task' : 'Assign a Task',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Delegate responsibilities and track progress within your team ecosystem.',
            style: TextStyle(color: _subtitle, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Task Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Title',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  decoration: _decoration(
                    'e.g., Q4 Revenue Projection Analysis',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: _decoration(
                    'Provide detailed context, goals, and any necessary resources...',
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Reminder Date',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _decoration('mm/dd/yyyy').copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: _subtitle,
                      ),
                    ),
                    child: Text(
                      _reminderDate != null
                          ? DateFormat('MM/dd/yyyy').format(_reminderDate!)
                          : 'mm/dd/yyyy',
                      style: TextStyle(
                        color: _reminderDate != null
                            ? _heading
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reminder Time',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: _decoration('--:-- --').copyWith(
                      suffixIcon: const Icon(
                        Icons.access_time,
                        size: 18,
                        color: _subtitle,
                      ),
                    ),
                    child: Text(
                      _reminderTime != null
                          ? _reminderTime!.format(context)
                          : '--:-- --',
                      style: TextStyle(
                        color: _reminderTime != null
                            ? _heading
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 👇 Attachment field
                const Text(
                  'Attachment',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 18,
                          color: _subtitle,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pickedFile != null
                                ? _pickedFile!.name
                                : 'File attach karein (optional)',
                            style: TextStyle(
                              color: _pickedFile != null
                                  ? _heading
                                  : const Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_pickedFile != null)
                          GestureDetector(
                            onTap: () => setState(() => _pickedFile = null),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: _subtitle,
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

          // Priority Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Priority',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _priorityChip(
                      'Critical',
                      Icons.error_outline,
                      const Color(0xFFE11D48),
                      const Color(0xFFFDE2E6),
                    ),
                    _priorityChip(
                      'High',
                      Icons.bolt,
                      const Color(0xFF2F6FED),
                      const Color(0xFFE3EBFD),
                    ),
                    _priorityChip(
                      'Medium',
                      Icons.remove,
                      const Color.fromARGB(255, 224, 212, 103),
                      const Color(0xFFE5E9F5),
                    ),
                    _priorityChip(
                      'Low',
                      Icons.remove,
                      const Color(0xFF374151),
                      const Color(0xFFE5E9F5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assign To Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign To Teammate',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: _decoration('Search teammates...').copyWith(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _teammatesStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final teammates = snapshot.data!
                        .where(
                          (m) => m['name'].toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                    return Column(
                      children: teammates.map((member) {
                        final selected = _selectedAssignees.containsKey(
                          member['uid'],
                        );
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedAssignees.remove(member['uid']);
                            } else {
                              _selectedAssignees[member['uid']] =
                                  member['name'];
                            }
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEFF4FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: selected
                                      ? const Color(0xFF2F6FED)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF111827),
                                  child: Text(
                                    member['name'].isNotEmpty
                                        ? member['name'][0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
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
                                        member['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        member['role'],
                                        style: const TextStyle(
                                          color: _subtitle,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Color(0xFF2F6FED),
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _assignTask,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
              label: Text(
                _loading ? '' : 'Assign Task',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _subtitle)),
            ),
          ),
        ],
      ),
    );
  }
}
