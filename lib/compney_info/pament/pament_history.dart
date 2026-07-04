// import 'package:flutter/material.dart';

// class PamentHistory extends StatefulWidget {
//   const PamentHistory({super.key});

//   @override
//   State<PamentHistory> createState() => _PamentHistoryState();
// }

// class _PamentHistoryState extends State<PamentHistory> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Project Screen')),
//       body: const Center(child: Text('Project Screen Content')),
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

/// A single logged payment transaction, stored in the top-level `payments`
/// collection. This is separate from the `services` / `dealDetails` data
/// embedded on a Customer doc — it's the actual running ledger of money
/// received (or refunded), so a history view can show/filter/search it
/// without touching the customer record itself.
class PaymentRecord {
  final String docId;
  final String customerId;
  final String customerName;
  final String businessName;
  final double amount;
  final String method; // Bank Transfer, UPI, Cheque, Cash, Card, Other
  final DateTime date;
  final String note;
  final bool isRefund;

  PaymentRecord({
    required this.docId,
    required this.customerId,
    required this.customerName,
    required this.businessName,
    required this.amount,
    required this.method,
    required this.date,
    required this.note,
    required this.isRefund,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'businessName': businessName,
      'amount': amount,
      'method': method,
      'date': Timestamp.fromDate(date),
      'note': note,
      'isRefund': isRefund,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PaymentRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentRecord(
      docId: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : double.tryParse('${data['amount']}') ?? 0,
      method: data['method'] ?? 'Other',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] ?? '',
      isRefund: data['isRefund'] ?? false,
    );
  }
}

class _CustomerOption {
  final String id;
  final String ownerName;
  final String businessName;

  _CustomerOption({
    required this.id,
    required this.ownerName,
    required this.businessName,
  });
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$d/$m/$y';
}

String _formatINR(num amount) {
  final isNeg = amount < 0;
  amount = amount.abs();
  String numStr = amount.toStringAsFixed(0);
  if (numStr.length > 3) {
    String lastThree = numStr.substring(numStr.length - 3);
    String rest = numStr.substring(0, numStr.length - 3);
    rest = rest.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+$)'),
      (m) => '${m[1]},',
    );
    numStr = '$rest,$lastThree';
  }
  return '${isNeg ? '-' : ''}₹$numStr';
}

const _bg = Color(0xFFF6F7FB);
const _cardFill = Color(0xFFF6F7FB);

enum _RangeFilter { all, thisMonth, last30, last7 }

extension on _RangeFilter {
  String get label {
    switch (this) {
      case _RangeFilter.all:
        return 'All Time';
      case _RangeFilter.thisMonth:
        return 'This Month';
      case _RangeFilter.last30:
        return 'Last 30 Days';
      case _RangeFilter.last7:
        return 'Last 7 Days';
    }
  }

  bool includes(DateTime date) {
    final now = DateTime.now();
    switch (this) {
      case _RangeFilter.all:
        return true;
      case _RangeFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case _RangeFilter.last30:
        return now.difference(date).inDays <= 30;
      case _RangeFilter.last7:
        return now.difference(date).inDays <= 7;
    }
  }
}

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final CollectionReference _paymentsRef = FirebaseFirestore.instance
      .collection('payments');

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _RangeFilter _range = _RangeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddPaymentSheet(),
    );
  }

  void _showRecordSheet(PaymentRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentRecordSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPaymentSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Payment', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _paymentsRef.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allRecords = (snapshot.data?.docs ?? [])
              .map((d) => PaymentRecord.fromDoc(d))
              .toList();

          final rangeFiltered = allRecords
              .where((r) => _range.includes(r.date))
              .toList();

          final filtered = rangeFiltered.where((r) {
            if (_searchQuery.isEmpty) return true;
            return r.customerName.toLowerCase().contains(_searchQuery) ||
                r.businessName.toLowerCase().contains(_searchQuery);
          }).toList();

          final totalReceived = rangeFiltered
              .where((r) => !r.isRefund)
              .fold<double>(0, (sum, r) => sum + r.amount);
          final totalRefunded = rangeFiltered
              .where((r) => r.isRefund)
              .fold<double>(0, (sum, r) => sum + r.amount);
          final netTotal = totalReceived - totalRefunded;

          return Column(
            children: [
              // ---------------- Summary card ----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SummaryCard(
                  netTotal: netTotal,
                  totalReceived: totalReceived,
                  totalRefunded: totalRefunded,
                  transactionCount: rangeFiltered.length,
                  range: _range,
                  onRangeChanged: (r) => setState(() => _range = r),
                ),
              ),

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
                      hintText: 'Search by customer or business name',
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

              // ---------------- List ----------------
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            allRecords.isEmpty
                                ? 'No payments logged yet.\nTap "Log Payment" to add one.'
                                : 'No payments match your filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final record = filtered[index];
                          final showDateHeader =
                              index == 0 ||
                              !_isSameDay(
                                filtered[index - 1].date,
                                record.date,
                              );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    12,
                                    4,
                                    8,
                                  ),
                                  child: Text(
                                    _dateHeaderLabel(record.date),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              _PaymentTile(
                                record: record,
                                onTap: () => _showRecordSheet(record),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateHeaderLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _formatDate(date);
  }
}

// ---------------------------------------------------------------------------
// SUMMARY CARD
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final double netTotal;
  final double totalReceived;
  final double totalRefunded;
  final int transactionCount;
  final _RangeFilter range;
  final ValueChanged<_RangeFilter> onRangeChanged;

  const _SummaryCard({
    required this.netTotal,
    required this.totalReceived,
    required this.totalRefunded,
    required this.transactionCount,
    required this.range,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Received',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              _RangeDropdown(range: range, onChanged: onRangeChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatINR(netTotal),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: netTotal < 0 ? Colors.red : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Received',
                  value: _formatINR(totalReceived),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: Colors.red,
                  label: 'Refunded',
                  value: _formatINR(totalRefunded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.receipt_long_outlined,
                  iconColor: primary,
                  label: 'Txns',
                  value: '$transactionCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeDropdown extends StatelessWidget {
  final _RangeFilter range;
  final ValueChanged<_RangeFilter> onChanged;

  const _RangeDropdown({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RangeFilter>(
      initialValue: range,
      onSelected: onChanged,
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => _RangeFilter.values
          .map((r) => PopupMenuItem(value: r, child: Text(r.label)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              range.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAYMENT LIST TILE
// ---------------------------------------------------------------------------

class _PaymentTile extends StatelessWidget {
  final PaymentRecord record;
  final VoidCallback onTap;

  const _PaymentTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = record.isRefund ? Colors.red : const Color(0xFF16A34A);

    // Shadow stays on the outer transparent Container; the white fill +
    // rounded clip live on the Material below so the ListTile's ink
    // splash/ripple stays visible on tap.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              record.isRefund
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            record.customerName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            record.businessName.isNotEmpty
                ? '${record.businessName} · ${record.method}'
                : record.method,
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.isRefund ? '-' : '+'}${_formatINR(record.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(record.date),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RECORD DETAIL SHEET (view / delete)
// ---------------------------------------------------------------------------

class _PaymentRecordSheet extends StatefulWidget {
  final PaymentRecord record;

  const _PaymentRecordSheet({required this.record});

  @override
  State<_PaymentRecordSheet> createState() => _PaymentRecordSheetState();
}

class _PaymentRecordSheetState extends State<_PaymentRecordSheet> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.record.docId)
          .delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        setState(() => _isDeleting = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: const Text(
          'This will remove this payment record permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _delete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final color = record.isRefund ? Colors.red : const Color(0xFF16A34A);

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
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(
                  record.isRefund
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (record.businessName.isNotEmpty)
                      Text(
                        record.businessName,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Text(
                '${record.isRefund ? '-' : '+'}${_formatINR(record.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Date', value: _formatDate(record.date)),
          _DetailRow(label: 'Method', value: record.method),
          _DetailRow(
            label: 'Type',
            value: record.isRefund ? 'Refund' : 'Payment Received',
          ),
          if (record.note.isNotEmpty)
            _DetailRow(label: 'Note', value: record.note),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _confirmDelete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                _isDeleting ? 'Deleting...' : 'Delete Record',
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD PAYMENT SHEET
// ---------------------------------------------------------------------------

class _AddPaymentSheet extends StatefulWidget {
  const _AddPaymentSheet();

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  static const _methods = [
    'Bank Transfer',
    'UPI',
    'Cheque',
    'Cash',
    'Card',
    'Other',
  ];

  _CustomerOption? _selectedCustomer;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _method = _methods.first;
  DateTime _date = DateTime.now();
  bool _isRefund = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _isSaving = true);

    final record = PaymentRecord(
      docId: '',
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.ownerName,
      businessName: _selectedCustomer!.businessName,
      amount: amount,
      method: _method,
      date: _date,
      note: _noteController.text.trim(),
      isRefund: _isRefund,
    );

    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .add(record.toMap());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment logged')));
        Navigator.pop(context, true);
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _cardFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                  'Log Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // ---- Payment / Refund toggle ----
                Row(
                  children: [
                    Expanded(
                      child: _toggleChip(
                        label: 'Received',
                        selected: !_isRefund,
                        color: const Color(0xFF16A34A),
                        onTap: () => setState(() => _isRefund = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _toggleChip(
                        label: 'Refund',
                        selected: _isRefund,
                        color: Colors.red,
                        onTap: () => setState(() => _isRefund = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- Customer picker (from Firestore) ----
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('customers')
                      .orderBy('ownerName')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _inputSkeleton();
                    }
                    final options = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _CustomerOption(
                        id: doc.id,
                        ownerName: data['ownerName'] ?? '',
                        businessName: data['businessName'] ?? '',
                      );
                    }).toList();

                    // Keep selection valid if the stream refreshes.
                    final currentId = _selectedCustomer?.id;
                    final matched = currentId == null
                        ? null
                        : options.where((o) => o.id == currentId).firstOrNull;

                    return DropdownButtonFormField<String>(
                      initialValue: matched?.id,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        'Customer',
                        Icons.person_outline,
                      ),
                      items: options
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(
                                o.businessName.isNotEmpty
                                    ? '${o.ownerName} · ${o.businessName}'
                                    : o.ownerName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final match = options
                            .where((o) => o.id == id)
                            .firstOrNull;
                        setState(() => _selectedCustomer = match);
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration('Amount', Icons.currency_rupee),
                ),
                const SizedBox(height: 14),

                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _cardFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Payment Date',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(_date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: _inputDecoration(
                    'Payment Method',
                    Icons.account_balance_outlined,
                  ),
                  items: _methods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _method = v!),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    'Note (optional)',
                    Icons.edit_note_outlined,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Saving...' : 'Save Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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

  Widget _inputSkeleton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : _cardFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// Small helper extension since this file targets a Dart SDK that may predate
// the built-in `firstOrNull` on some channels.
extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
