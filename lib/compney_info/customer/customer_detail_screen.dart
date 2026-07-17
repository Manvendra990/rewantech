import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_model.dart';
import 'customer_helpers.dart';
import 'add_customer_sheet.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key});

  @override
  State<CustomerDetailScreen> createState() => CustomerDetailScreenState();
}

class CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference _customersRef =
      FirebaseFirestore.instance.collection('customers');

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
                final customers = docs
                    .map((d) => Customer.fromDoc(d))
                    .where((c) {
                      if (_searchQuery.isEmpty) return true;
                      return c.ownerName.toLowerCase().contains(_searchQuery) ||
                          c.businessName.toLowerCase().contains(_searchQuery);
                    })
                    .toList();

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
            backgroundColor: Theme.of(context)
                .colorScheme.primary
                .withValues(alpha: 0.1),
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
                        '${formatINR(deal.totalAmount)} total (${deal.paymentType})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Received: ${formatINR(deal.amountReceived)}  ·  Pending: ${formatINR(deal.pendingAmount)}',
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
                          DetailChipText(
                            label: 'Agent',
                            value: deal.agentName.isEmpty ? '-' : deal.agentName,
                          ),
                          DetailChipText(
                            label: 'Closed',
                            value: formatDate(deal.dealClosedDate),
                          ),
                          if (deal.incentiveAmount != null)
                            DetailChipText(
                              label: 'Incentive',
                              value: formatINR(deal.incentiveAmount!),
                            ),
                          if (deal.paymentType == 'Monthly')
                            DetailChipText(
                              label: 'Next Due',
                              value: formatDate(deal.nextPaymentDate),
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
                                color: s.paymentStatus.color
                                    .withValues(alpha: 0.15),
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
                            DetailChipText(
                              label: 'Start',
                              value: formatDate(s.startDate),
                            ),
                            DetailChipText(
                              label: 'Payment Due',
                              value: formatDate(s.paymentDate),
                            ),
                            DetailChipText(
                              label: 'Received',
                              value: formatDate(s.paymentReceivedDate),
                            ),
                            DetailChipText(
                              label: 'Next Payment',
                              value: formatDate(s.nextPaymentDate),
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