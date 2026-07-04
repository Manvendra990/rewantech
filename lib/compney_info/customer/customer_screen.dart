import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MODELS
// ---------------------------------------------------------------------------

class SocialAccount {
  final String platform;
  final String id;
  final String password;

  SocialAccount({
    required this.platform,
    required this.id,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {'platform': platform, 'id': id, 'password': password};
  }

  factory SocialAccount.fromMap(Map<String, dynamic> map) {
    return SocialAccount(
      platform: map['platform'] ?? '',
      id: map['id'] ?? '',
      password: map['password'] ?? '',
    );
  }
}

/// Status of a service's payment cycle.
enum PaymentStatus { pending, completed, overdue }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.overdue:
        return Colors.red;
    }
  }

  static PaymentStatus fromLabel(String? label) {
    switch (label) {
      case 'Completed':
        return PaymentStatus.completed;
      case 'Overdue':
        return PaymentStatus.overdue;
      case 'Pending':
      default:
        return PaymentStatus.pending;
    }
  }
}

class ServiceProvided {
  final DateTime startDate;
  final String serviceName;
  final double monthlyCharges;
  final DateTime paymentDate;
  final PaymentStatus paymentStatus;
  final String monthlyTasks;
  final DateTime? paymentReceivedDate;
  final DateTime? nextPaymentDate;

  ServiceProvided({
    required this.startDate,
    required this.serviceName,
    required this.monthlyCharges,
    required this.paymentDate,
    required this.paymentStatus,
    required this.monthlyTasks,
    this.paymentReceivedDate,
    this.nextPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'serviceName': serviceName,
      'monthlyCharges': monthlyCharges,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentStatus': paymentStatus.label,
      'monthlyTasks': monthlyTasks,
      'paymentReceivedDate': paymentReceivedDate != null
          ? Timestamp.fromDate(paymentReceivedDate!)
          : null,
      'nextPaymentDate': nextPaymentDate != null
          ? Timestamp.fromDate(nextPaymentDate!)
          : null,
    };
  }

  factory ServiceProvided.fromMap(Map<String, dynamic> map) {
    return ServiceProvided(
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceName: map['serviceName'] ?? '',
      monthlyCharges: (map['monthlyCharges'] is num)
          ? (map['monthlyCharges'] as num).toDouble()
          : double.tryParse('${map['monthlyCharges']}') ?? 0,
      paymentDate:
          (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentStatus: PaymentStatusX.fromLabel(map['paymentStatus']),
      monthlyTasks: map['monthlyTasks'] ?? '',
      paymentReceivedDate: (map['paymentReceivedDate'] as Timestamp?)?.toDate(),
      nextPaymentDate: (map['nextPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}

/// Deal / won-lead details captured when a customer is created from a won
/// lead — the project, payment structure, and agent incentive info that used
/// to live in the separate "Deal Details" screen.
class DealDetails {
  final String? leadId;
  final String projectName;
  final String description;
  final String serviceName;
  final String agentName;
  final String paymentType; // 'One-time' or 'Monthly'
  final double totalAmount;
  final double? monthlyAmount;
  final double amountReceived;
  final double pendingAmount;
  final String paymentMethod;
  final double? incentivePercent;
  final double? incentiveAmount;
  final DateTime? dealClosedDate;
  final DateTime? nextPaymentDate;

  DealDetails({
    this.leadId,
    required this.projectName,
    required this.description,
    required this.serviceName,
    required this.agentName,
    required this.paymentType,
    required this.totalAmount,
    this.monthlyAmount,
    required this.amountReceived,
    required this.pendingAmount,
    required this.paymentMethod,
    this.incentivePercent,
    this.incentiveAmount,
    this.dealClosedDate,
    this.nextPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'projectName': projectName,
      'description': description,
      'serviceName': serviceName,
      'agentName': agentName,
      'paymentType': paymentType,
      'totalAmount': totalAmount,
      'monthlyAmount': monthlyAmount,
      'amountReceived': amountReceived,
      'pendingAmount': pendingAmount,
      'paymentMethod': paymentMethod,
      'incentivePercent': incentivePercent,
      'incentiveAmount': incentiveAmount,
      'dealClosedDate': dealClosedDate != null
          ? Timestamp.fromDate(dealClosedDate!)
          : null,
      'nextPaymentDate': nextPaymentDate != null
          ? Timestamp.fromDate(nextPaymentDate!)
          : null,
    };
  }

  factory DealDetails.fromMap(Map<String, dynamic> map) {
    return DealDetails(
      leadId: map['leadId'],
      projectName: map['projectName'] ?? '',
      description: map['description'] ?? '',
      serviceName: map['serviceName'] ?? '',
      agentName: map['agentName'] ?? '',
      paymentType: map['paymentType'] ?? 'One-time',
      totalAmount: (map['totalAmount'] is num)
          ? (map['totalAmount'] as num).toDouble()
          : double.tryParse('${map['totalAmount']}') ?? 0,
      monthlyAmount: map['monthlyAmount'] is num
          ? (map['monthlyAmount'] as num).toDouble()
          : null,
      amountReceived: (map['amountReceived'] is num)
          ? (map['amountReceived'] as num).toDouble()
          : double.tryParse('${map['amountReceived']}') ?? 0,
      pendingAmount: (map['pendingAmount'] is num)
          ? (map['pendingAmount'] as num).toDouble()
          : double.tryParse('${map['pendingAmount']}') ?? 0,
      paymentMethod: map['paymentMethod'] ?? 'Bank Transfer',
      incentivePercent: map['incentivePercent'] is num
          ? (map['incentivePercent'] as num).toDouble()
          : null,
      incentiveAmount: map['incentiveAmount'] is num
          ? (map['incentiveAmount'] as num).toDouble()
          : null,
      dealClosedDate: (map['dealClosedDate'] as Timestamp?)?.toDate(),
      nextPaymentDate: (map['nextPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}

class Customer {
  final String docId;
  final String ownerName;
  final String businessName;
  final String phoneNumber;
  final List<SocialAccount> socialAccounts;
  final List<ServiceProvided> services;
  final DealDetails? dealDetails;

  Customer({
    required this.docId,
    required this.ownerName,
    required this.businessName,
    required this.phoneNumber,
    required this.socialAccounts,
    required this.services,
    this.dealDetails,
  });

  factory Customer.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> rawAccounts = data['socialAccounts'] ?? [];
    final List<dynamic> rawServices = data['services'] ?? [];
    final rawDeal = data['dealDetails'];
    return Customer(
      docId: doc.id,
      ownerName: data['ownerName'] ?? '',
      businessName: data['businessName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      socialAccounts: rawAccounts
          .map((e) => SocialAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      services: rawServices
          .map((e) => ServiceProvided.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      dealDetails: rawDeal != null
          ? DealDetails.fromMap(Map<String, dynamic>.from(rawDeal))
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

String _formatDate(DateTime? date) {
  if (date == null) return '-';
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

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------

class CustomerDetailScreen extends StatefulWidget {
  CustomerDetailScreen({super.key});

  @override
  State<CustomerDetailScreen> createState() => CustomerDetailScreenState();
}

class CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference _customersRef = FirebaseFirestore.instance
      .collection('customers');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void openAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddCustomerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddCustomerSheet,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text(
          'Add Customer',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: theme.colorScheme.primary,
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
                  hintText: 'Search by owner or business name',
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

          // ---------------- Customer list ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _customersRef
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
                final customers = docs.map((d) => Customer.fromDoc(d)).where((
                  c,
                ) {
                  if (_searchQuery.isEmpty) return true;
                  return c.ownerName.toLowerCase().contains(_searchQuery) ||
                      c.businessName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (customers.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No customers yet.\nTap "Add Customer" to create one.'
                          : 'No results for "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    return _CustomerCard(customer: customers[index]);
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
// CUSTOMER CARD
// ---------------------------------------------------------------------------

class _CustomerCard extends StatelessWidget {
  final Customer customer;

  const _CustomerCard({required this.customer});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerDetailSheet(customer: customer),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCustomerSheet(existingCustomer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: The shadow lives on this outer Container (kept transparent),
    // while the white fill + rounded clip move onto a Material below.
    // This keeps the ListTile's ink splash / ripple visible — previously
    // the DecoratedBox/Container painted an opaque white background over
    // the InkWell's Material layer, which suppressed the ripple.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: () => _showDetails(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              customer.ownerName.isNotEmpty
                  ? customer.ownerName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            customer.ownerName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            customer.phoneNumber.isNotEmpty
                ? '${customer.businessName} · ${customer.phoneNumber}'
                : customer.businessName,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customer.dealDetails != null)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                ),
              if (customer.services.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text('${customer.services.length}'),
                    avatar: const Icon(Icons.design_services, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (customer.socialAccounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Chip(
                    label: Text('${customer.socialAccounts.length}'),
                    avatar: const Icon(Icons.link, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                tooltip: 'Edit customer',
                onPressed: () => _openEditSheet(context),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOMER DETAIL VIEW (bottom sheet shown on tap)
// ---------------------------------------------------------------------------

class _CustomerDetailSheet extends StatelessWidget {
  final Customer customer;

  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context) {
    final deal = customer.dealDetails;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
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
                customer.ownerName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                customer.businessName,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              if (customer.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      customer.phoneNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              if (deal != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Deal Details',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (deal.projectName.isNotEmpty)
                        Text(
                          deal.projectName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      if (deal.serviceName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            deal.serviceName,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatINR(deal.totalAmount)} total (${deal.paymentType})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Received: ${_formatINR(deal.amountReceived)}  ·  Pending: ${_formatINR(deal.pendingAmount)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _DetailChipText(
                            label: 'Agent',
                            value: deal.agentName.isEmpty
                                ? '-'
                                : deal.agentName,
                          ),
                          _DetailChipText(
                            label: 'Closed',
                            value: _formatDate(deal.dealClosedDate),
                          ),
                          if (deal.incentiveAmount != null)
                            _DetailChipText(
                              label: 'Incentive',
                              value: _formatINR(deal.incentiveAmount!),
                            ),
                          if (deal.paymentType == 'Monthly')
                            _DetailChipText(
                              label: 'Next Due',
                              value: _formatDate(deal.nextPaymentDate),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text(
                'Social Accounts',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (customer.socialAccounts.isEmpty)
                Text(
                  'No social accounts added.',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              else
                ...customer.socialAccounts.map(
                  (acc) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.public, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.platform,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                acc.id,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              const Text(
                'Services Provided',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (customer.services.isEmpty)
                Text(
                  'No services added.',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              else
                ...customer.services.map(
                  (s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.design_services, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.serviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: s.paymentStatus.color.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.paymentStatus.label,
                                style: TextStyle(
                                  color: s.paymentStatus.color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${s.monthlyCharges.toStringAsFixed(0)} / month',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (s.monthlyTasks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tasks: ${s.monthlyTasks}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _DetailChipText(
                              label: 'Start',
                              value: _formatDate(s.startDate),
                            ),
                            _DetailChipText(
                              label: 'Payment Due',
                              value: _formatDate(s.paymentDate),
                            ),
                            _DetailChipText(
                              label: 'Received',
                              value: _formatDate(s.paymentReceivedDate),
                            ),
                            _DetailChipText(
                              label: 'Next Payment',
                              value: _formatDate(s.nextPaymentDate),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailChipText extends StatelessWidget {
  final String label;
  final String value;

  const _DetailChipText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD CUSTOMER BOTTOM SHEET (form)
// ---------------------------------------------------------------------------

/// Public so it can be opened from other screens (e.g. LeadsScreen when a
/// lead is marked "Won") with prefilled data via `showModalBottomSheet`.
///
/// Pops with `true` when a customer is saved successfully, so the caller
/// can `await` the sheet and react (e.g. flip the source lead's status).
class AddCustomerSheet extends StatefulWidget {
  final String? leadId;
  final String initialOwnerName;
  final String initialBusinessName;
  final String initialPhoneNumber;
  final String initialProjectName;
  final String initialDescription;
  final String initialAgentName;

  /// When set, this sheet opens in **edit mode**: every field (owner,
  /// business, phone, social accounts, services, deal details) is prefilled
  /// from this customer, and saving performs a Firestore `update()` on this
  /// customer's doc instead of creating a new one.
  final Customer? existingCustomer;

  const AddCustomerSheet({
    super.key,
    this.leadId,
    this.initialOwnerName = '',
    this.initialBusinessName = '',
    this.initialPhoneNumber = '',
    this.initialProjectName = '',
    this.initialDescription = '',
    this.initialAgentName = '',
    this.existingCustomer,
  });

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  static const _serviceOptions = [
    'Web Development',
    'Mobile App Development',
    'Digital Marketing',
    'SEO',
    'Branding & Design',
    'Social Media Management',
    'Consulting',
    'Maintenance & Support',
    'Other',
  ];
  static const _paymentMethods = [
    'Bank Transfer',
    'UPI',
    'Cheque',
    'Cash',
    'Card',
    'Other',
  ];

  late final _ownerNameController = TextEditingController(
    text: widget.existingCustomer?.ownerName ?? widget.initialOwnerName,
  );
  late final _businessNameController = TextEditingController(
    text: widget.existingCustomer?.businessName ?? widget.initialBusinessName,
  );
  late final _phoneController = TextEditingController(
    text: widget.existingCustomer?.phoneNumber ?? widget.initialPhoneNumber,
  );
  final _platformController = TextEditingController();
  final _socialIdController = TextEditingController();
  final _socialPasswordController = TextEditingController();

  // ------ Payment structure ------
  String _paymentType = 'One-time'; // or 'Monthly'
  String _paymentMethod = _paymentMethods.first;
  final _totalAmountController = TextEditingController();
  final _monthlyAmountController = TextEditingController();
  final _amountReceivedController = TextEditingController();
  DateTime? _nextPaymentDate;

  // ------ Agent incentive ------
  late final _agentNameController = TextEditingController(
    text:
        widget.existingCustomer?.dealDetails?.agentName ??
        widget.initialAgentName,
  );
  // Captured the moment this sheet opens for the "Won" flow (same moment the
  // lead's status was set to Won). In edit mode this is overwritten in
  // initState with the deal's original closed date instead.
  DateTime _dealClosedDate = DateTime.now();
  final _incentivePercentController = TextEditingController();
  final _incentiveAmountController = TextEditingController();
  final _incentiveFocus = FocusNode();
  bool _incentiveManuallyEdited = false;

  // ------ Service form controllers (ongoing/recurring services) ------
  String _serviceProvidedName = _serviceOptions.first;
  final _customServiceProvidedController = TextEditingController();
  final _monthlyTasksController = TextEditingController();

  DateTime? _serviceStartDate;
  DateTime? _paymentDate;
  DateTime? _paymentReceivedDate;
  DateTime? _serviceNextPaymentDate;
  PaymentStatus _paymentStatus = PaymentStatus.pending;

  bool _obscurePassword = true;
  bool _isSaving = false;

  final List<SocialAccount> _socialAccounts = [];
  final List<ServiceProvided> _services = [];

  bool get _isFromWonLead => widget.leadId != null;
  bool get _isEditMode => widget.existingCustomer != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingCustomer;
    if (existing != null) {
      // Prefill social accounts and services with copies of the existing
      // ones so they show up as "Added Accounts" / "Added Services" and can
      // be removed/re-added like normal, without mutating the source lists.
      _socialAccounts.addAll(existing.socialAccounts);
      _services.addAll(existing.services);

      final deal = existing.dealDetails;
      if (deal != null) {
        _paymentType = deal.paymentType;
        _paymentMethod = deal.paymentMethod;
        if (deal.totalAmount != 0) {
          _totalAmountController.text = _stripZero(deal.totalAmount);
        }
        if (deal.monthlyAmount != null) {
          _monthlyAmountController.text = _stripZero(deal.monthlyAmount!);
        }
        if (deal.amountReceived != 0) {
          _amountReceivedController.text = _stripZero(deal.amountReceived);
        }
        _nextPaymentDate = deal.nextPaymentDate;
        _dealClosedDate = deal.dealClosedDate ?? DateTime.now();
        if (deal.incentivePercent != null) {
          _incentivePercentController.text = _stripZero(deal.incentivePercent!);
        }
        if (deal.incentiveAmount != null) {
          // Treat as manually set so re-calculation doesn't silently
          // overwrite a value that was intentionally edited before.
          _incentiveAmountController.text = _stripZero(deal.incentiveAmount!);
          _incentiveManuallyEdited = true;
        }
      }
    }

    _totalAmountController.addListener(_recalcIncentive);
    _incentivePercentController.addListener(_recalcIncentive);
    _incentiveFocus.addListener(() {
      if (_incentiveFocus.hasFocus) {
        setState(() => _incentiveManuallyEdited = true);
      }
    });
  }

  void _recalcIncentive() {
    if (_incentiveManuallyEdited) return;
    final total = double.tryParse(_totalAmountController.text) ?? 0;
    final pct = double.tryParse(_incentivePercentController.text) ?? 0;
    final amount = total * pct / 100;
    _incentiveAmountController.text = amount == 0 ? '' : _stripZero(amount);
  }

  void _resetIncentiveToAuto() {
    setState(() => _incentiveManuallyEdited = false);
    _recalcIncentive();
  }

  String _stripZero(num n) {
    final d = n.toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _platformController.dispose();
    _socialIdController.dispose();
    _socialPasswordController.dispose();
    _totalAmountController.dispose();
    _monthlyAmountController.dispose();
    _amountReceivedController.dispose();
    _incentivePercentController.dispose();
    _incentiveAmountController.dispose();
    _incentiveFocus.dispose();
    _agentNameController.dispose();
    _customServiceProvidedController.dispose();
    _monthlyTasksController.dispose();
    super.dispose();
  }

  void _addSocialAccount() {
    final platform = _platformController.text.trim();
    final id = _socialIdController.text.trim();
    final password = _socialPasswordController.text.trim();

    if (platform.isEmpty || id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter platform, user ID and password to add account'),
        ),
      );
      return;
    }

    setState(() {
      _socialAccounts.add(
        SocialAccount(platform: platform, id: id, password: password),
      );
      _platformController.clear();
      _socialIdController.clear();
      _socialPasswordController.clear();
    });
  }

  void _removeSocialAccount(int index) {
    setState(() => _socialAccounts.removeAt(index));
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onPicked(picked);
  }

  void _addService() {
    final serviceName = _serviceProvidedName == 'Other'
        ? _customServiceProvidedController.text.trim()
        : _serviceProvidedName;
    final chargesText = _monthlyAmountController.text.trim();
    final monthlyTasks = _monthlyTasksController.text.trim();
    final charges = double.tryParse(chargesText);

    if (serviceName.isEmpty ||
        charges == null ||
        _serviceStartDate == null ||
        _paymentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter service name, valid monthly charges, start date and payment date',
          ),
        ),
      );
      return;
    }

    setState(() {
      _services.add(
        ServiceProvided(
          startDate: _serviceStartDate!,
          serviceName: serviceName,
          monthlyCharges: charges,
          paymentDate: _paymentDate!,
          paymentStatus: _paymentStatus,
          monthlyTasks: monthlyTasks,
          paymentReceivedDate: _paymentReceivedDate,
          nextPaymentDate: _serviceNextPaymentDate,
        ),
      );

      // reset service form
      _serviceProvidedName = _serviceOptions.first;
      _customServiceProvidedController.clear();
      _monthlyTasksController.clear();
      _serviceStartDate = null;
      _paymentDate = null;
      _paymentReceivedDate = null;
      _serviceNextPaymentDate = null;
      _paymentStatus = PaymentStatus.pending;
    });
  }

  void _removeService(int index) {
    setState(() => _services.removeAt(index));
  }

  Future<void> _saveToCloud() async {
    final ownerName = _ownerNameController.text.trim();
    final businessName = _businessNameController.text.trim();

    if (ownerName.isEmpty || businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner name and business name are required'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // When payment type is Monthly, there's no "Total Amount" field in the
    // UI anymore — use the monthly amount as the effective total so
    // pendingAmount / hasDealInfo still work correctly.
    final total = _paymentType == 'One-time'
        ? (double.tryParse(_totalAmountController.text) ?? 0)
        : (double.tryParse(_monthlyAmountController.text) ?? 0);
    final monthly = double.tryParse(_monthlyAmountController.text);
    final received = double.tryParse(_amountReceivedController.text) ?? 0;
    final incentivePercent = double.tryParse(_incentivePercentController.text);
    final incentiveAmount = double.tryParse(_incentiveAmountController.text);

    // In edit mode, preserve the deal's original leadId (a customer edited
    // later shouldn't lose the link back to the lead it came from) instead
    // of using widget.leadId, which is only passed on the initial Won flow.
    final effectiveLeadId = _isEditMode
        ? widget.existingCustomer!.dealDetails?.leadId
        : widget.leadId;

    // Only attach deal details if this sheet was opened from a won lead, the
    // user actually filled in a total amount, or we're editing a customer
    // that already had deal details.
    final hasDealInfo =
        _isFromWonLead ||
        total > 0 ||
        (_isEditMode && widget.existingCustomer!.dealDetails != null);
    final dealDetails = hasDealInfo
        ? DealDetails(
            leadId: effectiveLeadId,
            projectName: widget.initialProjectName,
            description: widget.initialDescription,
            serviceName: '',
            agentName: _agentNameController.text.trim(),
            paymentType: _paymentType,
            totalAmount: total,
            monthlyAmount: _paymentType == 'Monthly' ? monthly : null,
            amountReceived: received,
            pendingAmount: total - received,
            paymentMethod: _paymentMethod,
            incentivePercent: incentivePercent,
            incentiveAmount: incentiveAmount,
            dealClosedDate: _dealClosedDate,
            nextPaymentDate: _paymentType == 'Monthly'
                ? _nextPaymentDate
                : null,
          )
        : null;

    try {
      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.existingCustomer!.docId)
            .update({
              'ownerName': ownerName,
              'businessName': businessName,
              'phoneNumber': _phoneController.text.trim(),
              'socialAccounts': _socialAccounts.map((e) => e.toMap()).toList(),
              'services': _services.map((e) => e.toMap()).toList(),
              'dealDetails': dealDetails?.toMap(),
            });
      } else {
        await FirebaseFirestore.instance.collection('customers').add({
          'ownerName': ownerName,
          'businessName': businessName,
          'phoneNumber': _phoneController.text.trim(),
          'leadId': widget.leadId,
          'socialAccounts': _socialAccounts.map((e) => e.toMap()).toList(),
          'services': _services.map((e) => e.toMap()).toList(),
          'dealDetails': dealDetails?.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Customer updated' : 'Customer saved to cloud',
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
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
                Text(
                  _isEditMode ? 'Edit Customer' : 'Add Customer',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (_isFromWonLead) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Lead won! Details confirm karo aur save karo.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Owner name
                TextField(
                  controller: _ownerNameController,
                  decoration: _inputDecoration(
                    'Owner Name',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 14),

                // Business name
                TextField(
                  controller: _businessNameController,
                  decoration: _inputDecoration(
                    'Business Name',
                    Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                // Contact number
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    'Contact Number',
                    Icons.phone_outlined,
                  ),
                ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),

                // -------------------------------------------------------
                // AGENT INCENTIVE
                // -------------------------------------------------------
                const Text(
                  'Agent Incentive',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _agentNameController,
                  decoration: _inputDecoration(
                    'Agent Name (who won the lead)',
                    Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                // Deal closed date — auto-set to the moment this sheet was
                // opened (i.e. the same moment the lead was marked Won), so
                // it's shown read-only rather than as a date picker.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deal Closed Date',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(_dealClosedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _incentivePercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          'Incentive %',
                          Icons.percent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _incentiveAmountController,
                        focusNode: _incentiveFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          'Incentive Amount',
                          Icons.currency_rupee,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_incentiveManuallyEdited) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _resetIncentiveToAuto,
                    child: const Text(
                      'Reset to auto-calculated amount',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Amount % × total se auto-calculate ho raha hai',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),

                // -------------------------------------------------------
                // SOCIAL MEDIA ACCOUNTS
                // -------------------------------------------------------
                const Text(
                  'Add Social Media Account',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _platformController,
                  decoration: _inputDecoration('Platform Name', Icons.apps),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _socialIdController,
                  decoration: _inputDecoration(
                    'User ID / Username',
                    Icons.alternate_email,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _socialPasswordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('Password', Icons.lock_outline)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _addSocialAccount,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ),

                if (_socialAccounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Added Accounts',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ..._socialAccounts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final acc = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.platform,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  acc.id,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeSocialAccount(index),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),

                // -------------------------------------------------------
                // SERVICES PROVIDED SECTION (payment structure + ongoing/recurring services)
                // -------------------------------------------------------
                const Text(
                  'Services Provided',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _toggleChip(
                        label: 'One-time',
                        selected: _paymentType == 'One-time',
                        onTap: () => setState(() => _paymentType = 'One-time'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _toggleChip(
                        label: 'Monthly',
                        selected: _paymentType == 'Monthly',
                        onTap: () => setState(() => _paymentType = 'Monthly'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // "Total Amount" only applies to One-time deals — fully
                // removed from the form when payment type is Monthly.
                if (_paymentType == 'One-time') ...[
                  TextField(
                    controller: _totalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(
                      'Total Amount',
                      Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_paymentType == 'Monthly') ...[
                  _DatePickerTile(
                    label: 'Next Payment Due Date',
                    date: _nextPaymentDate,
                    icon: Icons.event_repeat_outlined,
                    onTap: () => _pickDate(
                      initial: _nextPaymentDate,
                      onPicked: (d) => setState(() => _nextPaymentDate = d),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: _amountReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    'Amount Received',
                    Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: _inputDecoration(
                    'Payment Method',
                    Icons.account_balance_outlined,
                  ),
                  items: _paymentMethods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  initialValue: _serviceProvidedName,
                  decoration: _inputDecoration(
                    'Service',
                    Icons.design_services_outlined,
                  ),
                  items: _serviceOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _serviceProvidedName = v!),
                ),
                if (_serviceProvidedName == 'Other') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _customServiceProvidedController,
                    decoration: _inputDecoration(
                      'Custom Service Name',
                      Icons.edit_outlined,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                TextField(
                  controller: _monthlyTasksController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    'Monthly Tasks (e.g. 8 posts, 4 videos, 2 ads)',
                    Icons.checklist_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                if (_paymentType == 'Monthly') ...[
                  TextField(
                    controller: _monthlyAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(
                      'Monthly Payment Amount',
                      Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                DropdownButtonFormField<PaymentStatus>(
                  initialValue: _paymentStatus,
                  decoration: _inputDecoration(
                    'Payment Status',
                    Icons.info_outline,
                  ),
                  items: PaymentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentStatus = value);
                    }
                  },
                ),
                const SizedBox(height: 14),

                _DatePickerTile(
                  label: 'Service Start Date',
                  date: _serviceStartDate,
                  icon: Icons.play_circle_outline,
                  onTap: () => _pickDate(
                    initial: _serviceStartDate,
                    onPicked: (d) => setState(() => _serviceStartDate = d),
                  ),
                ),
                const SizedBox(height: 10),

                _DatePickerTile(
                  label: 'Payment Date',
                  date: _paymentDate,
                  icon: Icons.event_outlined,
                  onTap: () => _pickDate(
                    initial: _paymentDate,
                    onPicked: (d) => setState(() => _paymentDate = d),
                  ),
                ),
                const SizedBox(height: 10),

                _DatePickerTile(
                  label: 'Payment Received Date',
                  date: _paymentReceivedDate,
                  icon: Icons.payments_outlined,
                  onTap: () => _pickDate(
                    initial: _paymentReceivedDate,
                    onPicked: (d) => setState(() => _paymentReceivedDate = d),
                  ),
                ),
                const SizedBox(height: 10),

                _DatePickerTile(
                  label: 'Next Payment Date',
                  date: _serviceNextPaymentDate,
                  icon: Icons.event_repeat_outlined,
                  onTap: () => _pickDate(
                    initial: _serviceNextPaymentDate,
                    onPicked: (d) =>
                        setState(() => _serviceNextPaymentDate = d),
                  ),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _addService,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Service'),
                  ),
                ),

                if (_services.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Added Services',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ..._services.asMap().entries.map((entry) {
                    final index = entry.key;
                    final s = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.design_services, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.serviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: s.paymentStatus.color.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  s.paymentStatus.label,
                                  style: TextStyle(
                                    color: s.paymentStatus.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _removeService(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${s.monthlyCharges.toStringAsFixed(0)}/month · Start: ${_formatDate(s.startDate)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12.5,
                            ),
                          ),
                          if (s.monthlyTasks.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Tasks: ${s.monthlyTasks}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Due: ${_formatDate(s.paymentDate)}  ·  Received: ${_formatDate(s.paymentReceivedDate)}  ·  Next: ${_formatDate(s.nextPaymentDate)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

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
                        : Icon(
                            _isEditMode
                                ? Icons.save_outlined
                                : Icons.cloud_upload_outlined,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : (_isEditMode ? 'Update Customer' : 'Save to Cloud'),
                    ),
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

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
          ),
        ),
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

// ---------------------------------------------------------------------------
// SMALL REUSABLE DATE PICKER TILE
// ---------------------------------------------------------------------------

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
            Text(
              date != null ? _formatDate(date) : 'Select date',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: date != null ? Colors.black87 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}
