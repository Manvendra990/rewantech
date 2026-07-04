import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  final String projectId;
  final Map<String, dynamic> taskData;

  const TaskDetailPage({
    super.key,
    required this.taskId,
    required this.projectId,
    required this.taskData,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _firestore = FirebaseFirestore.instance;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _currentUid;
  String? _currentName;
  List<Map<String, dynamic>> _teammates = [];
  List<String> _mentionSuggestions = [];
  bool _showMentions = false;
  bool _sending = false;

  // ── Task completion state ──────────────────────────
  late String _status;
  String? _completedBy;
  bool _completing = false;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _status = widget.taskData['status'] ?? 'pending';
    _completedBy = widget.taskData['completedBy'];
    _loadUser();
    _loadTeammates();
    _commentCtrl.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markComplete() async {
    if (_currentName == null || _completing || _status == 'completed') return;
    setState(() => _completing = true);

    await _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks')
        .doc(widget.taskId)
        .update({
          'status': 'completed',
          'completedBy': _currentName,
          'completedAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    setState(() {
      _status = 'completed';
      _completedBy = _currentName;
      _completing = false;
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    final name = prefs.getString('name') ?? '';
    if (!mounted) return;
    setState(() {
      _currentUid = uid;
      _currentName = name;
    });
  }

  Future<void> _loadTeammates() async {
    final snap = await _firestore.collection('registration').get();
    if (!mounted) return;
    setState(() {
      _teammates = snap.docs
          .map((d) => {'uid': d.id, 'name': (d.data()['name'] ?? '') as String})
          .toList();
    });
  }

  void _onCommentChanged() {
    final text = _commentCtrl.text;
    final atIndex = text.lastIndexOf('@');

    if (atIndex != -1) {
      final query = text.substring(atIndex + 1).toLowerCase();
      final suggestions = _teammates
          .where(
            (m) =>
                m['name'].toString().toLowerCase().contains(query) &&
                m['uid'] != _currentUid,
          )
          .map((m) => m['name'] as String)
          .toList();

      setState(() {
        _mentionSuggestions = suggestions;
        _showMentions = suggestions.isNotEmpty;
      });
    } else {
      setState(() => _showMentions = false);
    }
  }

  void _insertMention(String name) {
    final text = _commentCtrl.text;
    final atIndex = text.lastIndexOf('@');
    final newText = '${text.substring(0, atIndex)}@$name ';
    _commentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _showMentions = false);
  }

  List<Map<String, dynamic>> _getMentionedUsers(String comment) {
    final mentioned = <Map<String, dynamic>>[];
    for (final teammate in _teammates) {
      final name = teammate['name'] as String;
      if (comment.contains('@$name')) {
        mentioned.add(teammate);
      }
    }
    return mentioned;
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _currentUid == null) return;

    setState(() => _sending = true);

    await _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks')
        .doc(widget.taskId)
        .collection('comments')
        .add({
          'text': text,
          'uid': _currentUid,
          'name': _currentName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });

    final mentionedUsers = _getMentionedUsers(text);
    for (final user in mentionedUsers) {
      await _firestore.collection('notifications').add({
        'toUid': user['uid'],
        'fromUid': _currentUid,
        'fromName': _currentName ?? '',
        'message': text,
        'taskId': widget.taskId,
        'projectId': widget.projectId,
        'taskTitle': widget.taskData['title'] ?? '',
        'type': 'mention',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _commentCtrl.clear();
    setState(() => _sending = false);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  Widget _buildCommentText(String text) {
    final spans = <TextSpan>[];
    final matches = RegExp(r'@\w[\w\s]*').allMatches(text).toList();

    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2F6FED),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.taskData;
    final priority = data['priority'] ?? 'Medium';
    final assignedNames = data['assignedToNames'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _heading),
        title: const Text(
          'Task Detail',
          style: TextStyle(
            color: _heading,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // ── Task Card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _status == 'completed'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF9C3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _status == 'completed'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFCA8A04),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // ── Complete icon button (sirf jab task pending ho) ──
                            if (_status != 'completed')
                              GestureDetector(
                                onTap: _completing ? null : _markComplete,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF16A34A,
                                    ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _completing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF16A34A),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF16A34A),
                                          size: 22,
                                        ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _heading,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if ((data['projectName'] ?? '').isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.folder_outlined,
                                size: 13,
                                color: _subtitle,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['projectName'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _subtitle,
                                ),
                              ),
                            ],
                          ),
                        // ── Completed by ────────────────────
                        if (_status == 'completed' &&
                            (_completedBy ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Completed by $_completedBy',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        if ((data['description'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const Divider(),
                          const SizedBox(height: 6),
                          Text(
                            data['description'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF374151),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: _subtitle,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              data['reminderDate'] != null
                                  ? '${data['reminderDate']}  ${data['reminderTime'] ?? ''}'
                                  : 'No date set',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _subtitle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Assigned To',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _subtitle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: assignedNames.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF1FA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFF111827),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _heading,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _subtitle,
                    ),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('tasks')
                        .doc(widget.taskId)
                        .collection('comments')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments = snapshot.data!.docs;

                      if (comments.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Koi comment nahi hai abhi\n@mention karke teammate ko tag karo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: _subtitle,
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: comments.map((doc) {
                          final c = doc.data() as Map<String, dynamic>;
                          final isMe = c['uid'] == _currentUid;
                          final ts = c['createdAt'] as Timestamp?;
                          final time = ts != null
                              ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                              : '';

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF111827)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      c['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2F6FED),
                                      ),
                                    ),
                                  if (!isMe) const SizedBox(height: 4),
                                  isMe
                                      ? Text(
                                          c['text'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        )
                                      : _buildCommentText(c['text'] ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white54
                                          : const Color(0xFF9CA3AF),
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
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Mention suggestions ────────────────────
            if (_showMentions)
              Container(
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (context, i) {
                    final name = _mentionSuggestions[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF111827),
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        '@$name',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _insertMention(name),
                    );
                  },
                ),
              ),

            // ── Comment Input ──────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (!_sending) _sendComment();
                        },
                        decoration: InputDecoration(
                          hintText: 'Comment likho... @mention ke liye @ likho',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFEDF1FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sending ? null : _sendComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF111827),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
