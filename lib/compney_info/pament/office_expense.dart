import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfficeExpensePage extends StatefulWidget {
  const OfficeExpensePage({super.key});

  @override
  State<OfficeExpensePage> createState() => _OfficeExpensePageState();
}

class _OfficeExpensePageState extends State<OfficeExpensePage> {
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _primary = Color(0xFF2F6FED);
  static const _fieldFill = Color(0xFFEDF1FA);

  // Sentinel value used for the "Other" dropdown entry — kept distinct from
  // any real Firestore project id.
  static const _otherValue = '__other__';

  final _expensesRef = FirebaseFirestore.instance.collection('office_expenses');
  final _projectsRef = FirebaseFirestore.instance.collection('projects');
  final _firestore = FirebaseFirestore.instance;

  final _amountCtrl = TextEditingController();
  final _usedForCtrl = TextEditingController();
  final _otherProjectCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  // Selected dropdown value: either a real project doc id, or _otherValue.
  String? _selectedProjectId;
  String _selectedProjectName = '';

  String? _uid;
  String? _userRole;
  String _userName = '';
  bool get _isAdmin => _userRole == 'Admin';

  @override
  void initState() {
    super.initState();
    _loadUser();
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

  @override
  void dispose() {
    _amountCtrl.dispose();
    _usedForCtrl.dispose();
    _otherProjectCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: Icon(icon, color: _subtitle, size: 20),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addExpense() async {
    final amountText = _amountCtrl.text.trim();
    final usedFor = _usedForCtrl.text.trim();
    final isOther = _selectedProjectId == _otherValue;
    final otherProjectName = _otherProjectCtrl.text.trim();

    if (amountText.isEmpty || usedFor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount aur Used For bharo')),
      );
      return;
    }

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project select karo')));
      return;
    }

    if (isOther && otherProjectName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project ka naam likho')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Valid amount daalo')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _expensesRef.add({
        'amount': amount,
        'usedFor': usedFor,
        'date': Timestamp.fromDate(_selectedDate),
        // Store null projectId for "Other" since it isn't a real project doc.
        'projectId': isOther ? null : _selectedProjectId,
        'projectName': isOther ? otherProjectName : _selectedProjectName,
        'addedByUid': _uid,
        'addedByName': _userName.isNotEmpty ? _userName : 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _amountCtrl.clear();
      _usedForCtrl.clear();
      _otherProjectCtrl.clear();
      _selectedDate = DateTime.now();
      _selectedProjectId = null;
      _selectedProjectName = '';

      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(String docId, String usedFor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expense delete karein?'),
        content: Text('"$usedFor" wala entry permanently delete ho jayega.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _expensesRef.doc(docId).delete();
    }
  }

  void _showAddExpenseSheet() {
    // Reset selection state for a fresh sheet each time.
    _selectedProjectId = null;
    _selectedProjectName = '';
    _otherProjectCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
              const SizedBox(height: 18),
              const Text(
                'Add Office Expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _heading,
                ),
              ),
              const SizedBox(height: 18),

              // ── Project dropdown ─────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: _projectsRef.orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  final projectDocs = snapshot.data?.docs ?? [];

                  // Build dropdown items: each real project, then "Other"
                  // at the very end of the list.
                  final items = <DropdownMenuItem<String>>[
                    ...projectDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['name'] ??
                                  data['projectName'] ??
                                  'Untitled Project')
                              .toString();
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }),
                    const DropdownMenuItem<String>(
                      value: _otherValue,
                      child: Text('Other'),
                    ),
                  ];

                  // If a previously selected id no longer exists in the
                  // stream (e.g. still loading), fall back to null so the
                  // DropdownButtonFormField doesn't crash on an invalid value.
                  final validIds = {
                    ...projectDocs.map((d) => d.id),
                    _otherValue,
                  };
                  final currentValue = validIds.contains(_selectedProjectId)
                      ? _selectedProjectId
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: currentValue,
                        decoration: _decoration(
                          hint:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? 'Loading projects...'
                              : 'Select Project',
                          icon: Icons.folder_outlined,
                        ),
                        items: items,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            _selectedProjectId = value;
                            if (value == _otherValue) {
                              _selectedProjectName = '';
                            } else {
                              final match = projectDocs.firstWhere(
                                (d) => d.id == value,
                              );
                              final data = match.data() as Map<String, dynamic>;
                              _selectedProjectName =
                                  (data['name'] ??
                                          data['projectName'] ??
                                          'Untitled Project')
                                      .toString();
                            }
                          });
                        },
                      ),
                      if (_selectedProjectId == _otherValue) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _otherProjectCtrl,
                          decoration: _decoration(
                            hint: 'Enter project name',
                            icon: Icons.edit_outlined,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  hint: 'Amount (₹)',
                  icon: Icons.currency_rupee,
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _usedForCtrl,
                decoration: _decoration(
                  hint: 'Used for (e.g. Stationery, Internet bill)',
                  icon: Icons.edit_note_outlined,
                ),
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setSheetState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _subtitle,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          color: _heading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await _addExpense();
                          // Reflect any reset state (e.g. cleared controllers)
                          // back into the sheet's own setState scope, in case
                          // the sheet is still open (e.g. validation failed).
                          setSheetState(() {});
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Expense',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: const Text(
          'Office Expenses',
          style: TextStyle(color: _heading, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _expensesRef.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading expenses:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          double total = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += (data['amount'] as num?)?.toDouble() ?? 0;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expense',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${NumberFormat('#,##0.00').format(total)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${docs.length} entries',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'Koi expense entry nahi hai abhi tak',
                          style: TextStyle(color: _subtitle, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final amount =
                              (data['amount'] as num?)?.toDouble() ?? 0;
                          final usedFor = data['usedFor'] ?? '';
                          final projectName = data['projectName'] ?? '';
                          final addedByName = data['addedByName'] ?? '';
                          final date = (data['date'] as Timestamp?)?.toDate();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    color: _primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        usedFor,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _heading,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if (projectName.toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Text(
                                            projectName,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: _primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Text(
                                        date != null
                                            ? DateFormat(
                                                'dd MMM yyyy',
                                              ).format(date)
                                            : '-',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _subtitle,
                                        ),
                                      ),
                                      if (addedByName
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 11,
                                              color: _subtitle,
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                'Added by $addedByName',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: _subtitle,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${NumberFormat('#,##0.00').format(amount)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _heading,
                                  ),
                                ),
                                if (_isAdmin) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        _confirmDelete(doc.id, usedFor),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        onPressed: _showAddExpenseSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
