import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rtstrack/compney_info/customer/customer_screen.dart';
import 'package:rtstrack/services/lead_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _leadService = LeadService();
  String _userName = '';

  static const _bg = Color(0xFFF4F5FB);
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _statuses = ['New', 'In Progress', 'Won', 'Lost'];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    if (mounted) setState(() => _userName = name);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Won':
        return const Color(0xFF16A34A);
      case 'Lost':
        return const Color(0xFFE11D48);
      case 'In Progress':
        return const Color(0xFF2F6FED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Won':
        return const Color(0xFFDCFCE7);
      case 'Lost':
        return const Color(0xFFFDE2E6);
      case 'In Progress':
        return const Color(0xFFE3EBFD);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  bool _isLocked(String status) => status == 'Won' || status == 'Lost';

  // ── Status change entry point (tap the status chip on a lead card) ──
  void _changeStatus(String leadId, Map<String, dynamic> data) {
    final current = data['status'] ?? 'New';

    if (_isLocked(current)) return; // Won/Lost leads can't be reassigned

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            const SizedBox(height: 16),
            const Text(
              'Status change karo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _heading,
              ),
            ),
            const SizedBox(height: 14),
            ..._statuses.map((s) {
              final isSelected = s == current;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  if (s == current) return;
                  _handleStatusSelected(leadId, data, s);
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _statusBg(s) : const Color(0xFFEDF1FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        s,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? _statusColor(s) : _subtitle,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(
                          Icons.check_circle,
                          color: _statusColor(s),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStatusSelected(
    String leadId,
    Map<String, dynamic> data,
    String newStatus,
  ) async {
    if (newStatus == 'Lost') {
      await _confirmAndMarkLost(leadId);
    } else if (newStatus == 'Won') {
      await _confirmAndMarkWon(leadId, data);
    } else {
      await _leadService.updateLeadStatus(leadId, newStatus);
    }
  }

  // ── Lost flow: confirm + reason ──────────────────────────
  Future<void> _confirmAndMarkLost(String leadId) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mark Lead as Lost?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kya aap sure hain ki ye lead lost mark karna chahte hain? Ye action wapas nahi ho sakta.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Reason for losing this lead...',
                  filled: true,
                  fillColor: const Color(0xFFEDF1FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
              ),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Reason likhna zaroori hai')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text(
                'Yes, Mark Lost',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('leads').doc(leadId).update({
      'status': 'Lost',
      'lostReason': reasonCtrl.text.trim(),
      'lostAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Won flow: confirm, then open Add Customer sheet ──────
  Future<void> _confirmAndMarkWon(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Lead as Won?'),
        content: const Text(
          'Kya aap sure hain? Confirm karne ke baad customer details bharni hongi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Mark Won',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCustomerSheet(
        leadId: leadId,
        initialOwnerName: data['clientName'] ?? '',
        initialPhoneNumber: data['phoneNumber'] ?? '',
        initialProjectName: data['title'] ?? '',
        initialDescription: data['description'] ?? '',
        initialAgentName: _userName,
      ),
    );

    if (saved == true) {
      await FirebaseFirestore.instance.collection('leads').doc(leadId).update({
        'status': 'Won',
        'wonAt': FieldValue.serverTimestamp(),
      });
    }
    // If the sheet was dismissed without saving, the lead status stays
    // untouched — the user can retry marking it Won later.
  }

  // ── Comments ──────────────────────────────────────────
  void _openComments(String leadId, String leadTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        leadId: leadId,
        leadTitle: leadTitle,
        userName: _userName,
        leadService: _leadService,
      ),
    );
  }

  void _showCreateLead() {
    final titleCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              const Text(
                'New Lead',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _heading,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              _inputField(titleCtrl, 'Lead Title', Icons.title),
              const SizedBox(height: 12),

              // Client
              _inputField(clientCtrl, 'Client Name', Icons.person_outline),
              const SizedBox(height: 12),

              // Phone Number
              _inputField(
                phoneCtrl,
                'Phone Number',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFEDF1FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty ||
                              clientCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Title aur Client naam zaroori hai',
                                ),
                              ),
                            );
                            return;
                          }
                          setModal(() => loading = true);
                          await _leadService.createLead(
                            title: titleCtrl.text.trim(),
                            clientName: clientCtrl.text.trim(),
                            phoneNumber: phoneCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            status: 'New',
                            createdByName: _userName,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Lead',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFEDF1FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _heading),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leads',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _heading,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showCreateLead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'New',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _leadService.getLeads(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFE11D48)),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.show_chart,
                    size: 48,
                    color: Color(0xFFD1D5DB),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Lead',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _subtitle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create New Lead',
                    style: TextStyle(fontSize: 13, color: _subtitle),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'New';
              final locked = _isLocked(status);
              final lostReason = (data['lostReason'] ?? '').toString().trim();
              final createdAt = data['createdAt'] as Timestamp?;
              final date = createdAt != null
                  ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                        // ── Status chip w/ change arrow (locked once Won/Lost) ──
                        GestureDetector(
                          onTap: locked
                              ? null
                              : () => _changeStatus(doc.id, data),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBg(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(status),
                                  ),
                                ),
                                if (!locked) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 13,
                                    color: _statusColor(status),
                                  ),
                                ] else ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 11,
                                    color: _statusColor(status),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _subtitle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: _subtitle,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['clientName'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _subtitle,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _openComments(doc.id, data['title'] ?? ''),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 13,
                                  color: _subtitle,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Comments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _subtitle,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if ((data['phoneNumber'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: _subtitle,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['phoneNumber'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: _subtitle,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((data['description'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        data['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _subtitle),
                      ),
                    ],
                    // ── Lost reason banner ──
                    if (status == 'Lost' && lostReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE2E6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 13,
                              color: Color(0xFFE11D48),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lostReason,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 13,
                          color: _subtitle,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'By ${data['createdByName'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _subtitle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COMMENTS BOTTOM SHEET
// ---------------------------------------------------------------------------

class _CommentsSheet extends StatefulWidget {
  final String leadId;
  final String leadTitle;
  final String userName;
  final LeadService leadService;

  const _CommentsSheet({
    required this.leadId,
    required this.leadTitle,
    required this.userName,
    required this.leadService,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _commentCtrl.clear();

    await widget.leadService.addComment(
      leadId: widget.leadId,
      text: text,
      userName: widget.userName,
    );

    if (!mounted) return;
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

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}  $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // const SizedBox(height: 14),
            // const Row(
            //   children: [
            //     SizedBox(width: 20),
            //     Icon(Icons.chat_bubble_outline, size: 16, color: _subtitle),
            //     SizedBox(width: 8),
            //     Text(
            //       'Comments',
            //       style: TextStyle(
            //         fontSize: 15,
            //         fontWeight: FontWeight.w700,
            //         color: _heading,
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 20),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: _subtitle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _heading,
                        ),
                      ),
                      if (widget.leadTitle.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.leadTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _subtitle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.leadService.getComments(widget.leadId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Pehla comment karo!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _subtitle,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: docs.map((doc) {
                      final comment = doc.data() as Map<String, dynamic>;
                      final isMe =
                          comment['uid'] == widget.leadService.currentUid;
                      final name = comment['userName'] ?? '';
                      final initial = name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '?';

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF111827),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _subtitle,
                                          ),
                                        ),
                                      ),
                                    GestureDetector(
                                      onLongPress: isMe
                                          ? () async {
                                              final del = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Comment delete?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFFE11D48,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (del == true) {
                                                await widget.leadService
                                                    .deleteComment(
                                                      widget.leadId,
                                                      doc.id,
                                                    );
                                              }
                                            }
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? const Color(0xFF111827)
                                              : const Color(0xFFF4F5FB),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(
                                              isMe ? 16 : 4,
                                            ),
                                            bottomRight: Radius.circular(
                                              isMe ? 4 : 16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          comment['text'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isMe
                                                ? Colors.white
                                                : _heading,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatTime(
                                        comment['createdAt'] as Timestamp?,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _subtitle,
                                      ),
                                    ),
                                  ],
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
            ),

            // ── Comment Input ──────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEDF1FA))),
              ),
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
                          hintText: 'Comment likho...',
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
