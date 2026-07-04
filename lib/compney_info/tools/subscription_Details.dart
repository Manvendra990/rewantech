import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

class SubscriptionDetail {
  final String docId;
  final String toolName;
  final double monthlyPrice;
  final String gmailAccount;
  final DateTime? renewalDate;
  final String category;
  final String notes;

  SubscriptionDetail({
    required this.docId,
    required this.toolName,
    required this.monthlyPrice,
    required this.gmailAccount,
    required this.renewalDate,
    required this.category,
    required this.notes,
  });

  factory SubscriptionDetail.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionDetail(
      docId: doc.id,
      toolName: data['toolName'] ?? '',
      monthlyPrice: (data['monthlyPrice'] ?? 0).toDouble(),
      gmailAccount: data['gmailAccount'] ?? '',
      renewalDate: (data['renewalDate'] as Timestamp?)?.toDate(),
      category: data['category'] ?? '',
      notes: data['notes'] ?? '',
    );
  }

  bool get isRenewingSoon {
    if (renewalDate == null) return false;
    final daysLeft = renewalDate!.difference(DateTime.now()).inDays;
    return daysLeft <= 7 && daysLeft >= 0;
  }

  bool get isOverdue {
    if (renewalDate == null) return false;
    return renewalDate!.isBefore(DateTime.now());
  }
}

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------

class SubscriptionDetailScreen extends StatefulWidget {
  const SubscriptionDetailScreen({super.key});

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference _subsRef = FirebaseFirestore.instance.collection(
    'subscriptions',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddSubscriptionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSubscriptionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Tool'),
        backgroundColor: Color(0xFF2F6FED),
      ),
      body: Column(
        children: [
          // ---------------- Search bar ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: 'Search by tool or gmail account',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
          ),

          // ---------------- List + total spend ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _subsRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final allSubs = docs
                    .map((d) => SubscriptionDetail.fromDoc(d))
                    .toList();

                final filtered = allSubs.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  return s.toolName.toLowerCase().contains(_searchQuery) ||
                      s.gmailAccount.toLowerCase().contains(_searchQuery);
                }).toList();

                final totalMonthly = allSubs.fold<double>(
                  0,
                  (sum, s) => sum + s.monthlyPrice,
                );

                return Column(
                  children: [
                    // Total monthly spend summary card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF2F6FED),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Monthly Spend',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${totalMonthly.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.subscriptions,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No subscriptions yet.\nTap "Add Tool" to create one.'
                                    : 'No results for "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _SubscriptionCard(sub: filtered[index]);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUBSCRIPTION CARD
// ---------------------------------------------------------------------------

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionDetail sub;

  const _SubscriptionCard({required this.sub});

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubscriptionDetailSheet(sub: sub),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.green;
    String statusText = 'Active';
    if (sub.isOverdue) {
      statusColor = Colors.red;
      statusText = 'Overdue';
    } else if (sub.isRenewingSoon) {
      statusColor = Colors.orange;
      statusText = 'Renews soon';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _showDetails(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF2F6FED).withValues(alpha: 0.1),
          child: Icon(Icons.build_circle_outlined, color: Color(0xFF2F6FED)),
        ),
        title: Text(
          sub.toolName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(sub.gmailAccount),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${sub.monthlyPrice.toStringAsFixed(0)}/mo',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUBSCRIPTION DETAIL VIEW (bottom sheet shown on tap)
// ---------------------------------------------------------------------------

class _SubscriptionDetailSheet extends StatelessWidget {
  final SubscriptionDetail sub;

  const _SubscriptionDetailSheet({required this.sub});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            sub.toolName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _row('Monthly Price', '₹${sub.monthlyPrice.toStringAsFixed(2)}'),
          _row('Gmail Account', sub.gmailAccount),
          _row('Category', sub.category),
          _row('Renewal Date', _formatDate(sub.renewalDate)),
          if (sub.notes.isNotEmpty) _row('Notes', sub.notes),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD SUBSCRIPTION BOTTOM SHEET (form)
// ---------------------------------------------------------------------------

class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet();

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _toolNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _gmailController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _renewalDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _toolNameController.dispose();
    _priceController.dispose();
    _gmailController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickRenewalDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _renewalDate = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveToCloud() async {
    final toolName = _toolNameController.text.trim();
    final priceText = _priceController.text.trim();
    final gmailAccount = _gmailController.text.trim();

    if (toolName.isEmpty || priceText.isEmpty || gmailAccount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tool name, price and gmail account are required'),
        ),
      );
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly price')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'toolName': toolName,
        'monthlyPrice': price,
        'gmailAccount': gmailAccount,
        'category': _categoryController.text.trim(),
        'renewalDate': _renewalDate != null
            ? Timestamp.fromDate(_renewalDate!)
            : null,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription saved to cloud')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Subscription',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _toolNameController,
                  decoration: _inputDecoration(
                    'Tool / Service Name',
                    Icons.build_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    'Monthly Price (₹)',
                    Icons.currency_rupee,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _gmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    'Associated Gmail Account',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _categoryController,
                  decoration: _inputDecoration(
                    'Category (optional)',
                    Icons.category_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                // Renewal date
                InkWell(
                  onTap: _pickRenewalDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      'Renewal Date',
                      Icons.calendar_today_outlined,
                    ),
                    child: Text(_formatDate(_renewalDate)),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: _inputDecoration('Notes (optional)', Icons.notes),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveToCloud,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save to Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2F6FED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }
}
