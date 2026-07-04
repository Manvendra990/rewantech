import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

class DomainDetail {
  final String docId;
  final String domainName;
  final String gmailAccount;
  final String registrar;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String notes;

  DomainDetail({
    required this.docId,
    required this.domainName,
    required this.gmailAccount,
    required this.registrar,
    required this.purchaseDate,
    required this.expiryDate,
    required this.notes,
  });

  factory DomainDetail.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DomainDetail(
      docId: doc.id,
      domainName: data['domainName'] ?? '',
      gmailAccount: data['gmailAccount'] ?? '',
      registrar: data['registrar'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      notes: data['notes'] ?? '',
    );
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft <= 30;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------

class DomainDetailScreen extends StatefulWidget {
  const DomainDetailScreen({super.key});

  @override
  State<DomainDetailScreen> createState() => _DomainDetailScreenState();
}

class _DomainDetailScreenState extends State<DomainDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference _domainsRef = FirebaseFirestore.instance.collection(
    'domains',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddDomainSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddDomainSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Domains',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDomainSheet,
        icon: const Icon(Icons.add),
        backgroundColor: Color(0xFF2F6FED),
        label: const Text('Add Domain'),
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
                  hintText: 'Search by domain or gmail account',
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

          // ---------------- Domain list ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _domainsRef
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
                final domains = docs.map((d) => DomainDetail.fromDoc(d)).where((
                  dm,
                ) {
                  if (_searchQuery.isEmpty) return true;
                  return dm.domainName.toLowerCase().contains(_searchQuery) ||
                      dm.gmailAccount.toLowerCase().contains(_searchQuery);
                }).toList();

                if (domains.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No domains yet.\nTap "Add Domain" to create one.'
                          : 'No results for "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: domains.length,
                  itemBuilder: (context, index) {
                    return _DomainCard(domain: domains[index]);
                  },
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
// DOMAIN CARD
// ---------------------------------------------------------------------------

class _DomainCard extends StatelessWidget {
  final DomainDetail domain;

  const _DomainCard({required this.domain});

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DomainDetailSheet(domain: domain),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.green;
    String statusText = 'Active';
    if (domain.isExpired) {
      statusColor = Colors.red;
      statusText = 'Expired';
    } else if (domain.isExpiringSoon) {
      statusColor = Colors.orange;
      statusText = 'Expiring soon';
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.language,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          domain.domainName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(domain.gmailAccount),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(domain.expiryDate),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DOMAIN DETAIL VIEW (bottom sheet shown on tap)
// ---------------------------------------------------------------------------

class _DomainDetailSheet extends StatelessWidget {
  final DomainDetail domain;

  const _DomainDetailSheet({required this.domain});

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
            domain.domainName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _row('Gmail Account', domain.gmailAccount),
          _row('Registrar', domain.registrar),
          _row('Purchase Date', _formatDate(domain.purchaseDate)),
          _row('Expiry Date', _formatDate(domain.expiryDate)),
          if (domain.notes.isNotEmpty) _row('Notes', domain.notes),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD DOMAIN BOTTOM SHEET (form)
// ---------------------------------------------------------------------------

class _AddDomainSheet extends StatefulWidget {
  const _AddDomainSheet();

  @override
  State<_AddDomainSheet> createState() => _AddDomainSheetState();
}

class _AddDomainSheetState extends State<_AddDomainSheet> {
  final _domainNameController = TextEditingController();
  final _gmailController = TextEditingController();
  final _registrarController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _domainNameController.dispose();
    _gmailController.dispose();
    _registrarController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isPurchaseDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveToCloud() async {
    final domainName = _domainNameController.text.trim();
    final gmailAccount = _gmailController.text.trim();

    if (domainName.isEmpty || gmailAccount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Domain name and gmail account are required'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('domains').add({
        'domainName': domainName,
        'gmailAccount': gmailAccount,
        'registrar': _registrarController.text.trim(),
        'purchaseDate': _purchaseDate != null
            ? Timestamp.fromDate(_purchaseDate!)
            : null,
        'expiryDate': _expiryDate != null
            ? Timestamp.fromDate(_expiryDate!)
            : null,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Domain saved to cloud')));
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
                  'Add Domain',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _domainNameController,
                  decoration: _inputDecoration('Domain Name', Icons.language),
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
                  controller: _registrarController,
                  decoration: _inputDecoration(
                    'Registrar / Provider (optional)',
                    Icons.store_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                // Purchase date
                InkWell(
                  onTap: () => _pickDate(isPurchaseDate: true),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      'Purchase Date',
                      Icons.calendar_today_outlined,
                    ),
                    child: Text(_formatDate(_purchaseDate)),
                  ),
                ),
                const SizedBox(height: 14),

                // Expiry date
                InkWell(
                  onTap: () => _pickDate(isPurchaseDate: false),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      'Expiry Date',
                      Icons.event_busy_outlined,
                    ),
                    child: Text(_formatDate(_expiryDate)),
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
