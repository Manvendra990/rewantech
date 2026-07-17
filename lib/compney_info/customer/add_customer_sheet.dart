import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_model.dart';
import 'customer_helpers.dart';

class AddCustomerSheet extends StatefulWidget {
  final String? leadId;
  final String initialOwnerName;
  final String initialBusinessName;
  final String initialPhoneNumber;
  final String initialProjectName;
  final String initialDescription;
  final String initialAgentName;
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

  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _requiredNumberValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;
    if (double.tryParse(value!.trim()) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

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

  String _paymentType = 'One-time'; 
  String _paymentMethod = _paymentMethods.first;
  final _totalAmountController = TextEditingController();
  final _monthlyAmountController = TextEditingController();
  final _amountReceivedController = TextEditingController();
  DateTime? _nextPaymentDate;

  late final _agentNameController = TextEditingController(
    text: widget.existingCustomer?.dealDetails?.agentName ??
        widget.initialAgentName,
  );

  DateTime _dealClosedDate = DateTime.now();
  final _incentivePercentController = TextEditingController();
  final _incentiveAmountController = TextEditingController();
  final _incentiveFocus = FocusNode();
  bool _incentiveManuallyEdited = false;

  String _serviceProvidedName = _serviceOptions.first;
  final _customServiceProvidedController = TextEditingController();
  final _monthlyTasksController = TextEditingController();
  final _serviceChargesController = TextEditingController();

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
    _serviceChargesController.dispose();
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
    final chargesText = _serviceChargesController.text.trim();
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

      _serviceProvidedName = _serviceOptions.first;
      _customServiceProvidedController.clear();
      _monthlyTasksController.clear();
      _serviceChargesController.clear();
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

  Future<void> _createProjectForNewCustomer({
    required String customerId,
    required String businessName,
  }) async {
    if (widget.leadId != null) {
      final existing = await FirebaseFirestore.instance
          .collection('projects')
          .where('leadId', isEqualTo: widget.leadId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to auto-create a project'),
          ),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('projects').add({
      'name': businessName,
      'createdBy': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'new',
      'customerId': customerId,
      'leadId': widget.leadId,
    });
  }

  Future<void> _saveToCloud() async {
    if (_formKey.currentState?.validate() ?? false) {
      final ownerName = _ownerNameController.text.trim();
      final businessName = _businessNameController.text.trim();

      setState(() => _isSaving = true);

      final total = _paymentType == 'One-time'
          ? (double.tryParse(_totalAmountController.text) ?? 0)
          : (double.tryParse(_monthlyAmountController.text) ?? 0);
      final monthly = double.tryParse(_monthlyAmountController.text);
      final received = double.tryParse(_amountReceivedController.text) ?? 0;
      final incentivePercent = double.tryParse(_incentivePercentController.text);
      final incentiveAmount = double.tryParse(_incentiveAmountController.text);

      final effectiveLeadId = _isEditMode
          ? widget.existingCustomer!.dealDetails?.leadId
          : widget.leadId;

      final hasDealInfo = _isFromWonLead ||
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
              nextPaymentDate: _paymentType == 'Monthly' ? _nextPaymentDate : null,
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
          final customerDoc = await FirebaseFirestore.instance
              .collection('customers')
              .add({
            'ownerName': ownerName,
            'businessName': businessName,
            'phoneNumber': _phoneController.text.trim(),
            'leadId': widget.leadId,
            'socialAccounts': _socialAccounts.map((e) => e.toMap()).toList(),
            'services': _services.map((e) => e.toMap()).toList(),
            'dealDetails': dealDetails?.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _createProjectForNewCustomer(
            customerId: customerDoc.id,
            businessName: businessName,
          );
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all the required fields correctly'),
        ),
      );
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
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
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
                    TextFormField(
                      controller: _ownerNameController,
                      validator: _requiredValidator,
                      decoration: _inputDecoration(
                        'Owner Name *',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _businessNameController,
                      validator: _requiredValidator,
                      decoration: _inputDecoration(
                        'Business Name *',
                        Icons.storefront_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: _requiredValidator,
                      decoration: _inputDecoration(
                        'Contact Number *',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Agent Incentive',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _agentNameController,
                      validator: _requiredValidator,
                      decoration: _inputDecoration(
                        'Agent Name (who won the lead) *',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            formatDate(_dealClosedDate),
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
                          child: TextFormField(
                            controller: _incentivePercentController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _requiredNumberValidator,
                            decoration: _inputDecoration(
                              'Incentive % *',
                              Icons.percent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _incentiveAmountController,
                            focusNode: _incentiveFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _requiredNumberValidator,
                            decoration: _inputDecoration(
                              'Incentive Amount *',
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
                    const Text(
                      'Add Social Media Account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _platformController,
                      decoration: _inputDecoration(
                        'Platform Name',
                        Icons.apps,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _socialIdController,
                      decoration: _inputDecoration(
                        'User ID / Username',
                        Icons.alternate_email,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                    const Text(
                      'Services Provided',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _toggleChip(
                            label: 'One-time',
                            selected: _paymentType == 'One-time',
                            onTap: () =>
                                setState(() => _paymentType = 'One-time'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _toggleChip(
                            label: 'Monthly',
                            selected: _paymentType == 'Monthly',
                            onTap: () =>
                                setState(() => _paymentType = 'Monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_paymentType == 'One-time') ...[
                      TextFormField(
                        controller: _totalAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredNumberValidator,
                        decoration: _inputDecoration(
                          'Total Amount *',
                          Icons.currency_rupee,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_paymentType == 'Monthly') ...[
                      DatePickerTile(
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
                    TextFormField(
                      controller: _amountReceivedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _requiredNumberValidator,
                      decoration: _inputDecoration(
                        'Amount Received *',
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
                      onChanged: (v) =>
                          setState(() => _serviceProvidedName = v!),
                    ),
                    if (_serviceProvidedName == 'Other') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customServiceProvidedController,
                        decoration: _inputDecoration(
                          'Custom Service Name',
                          Icons.edit_outlined,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _serviceChargesController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Monthly Charges (for this service)',
                        Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _monthlyTasksController,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        'Monthly Tasks (e.g. 8 posts, 4 videos, 2 ads)',
                        Icons.checklist_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_paymentType == 'Monthly') ...[
                      TextFormField(
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
                    DatePickerTile(
                      label: 'Service Start Date',
                      date: _serviceStartDate,
                      icon: Icons.play_circle_outline,
                      onTap: () => _pickDate(
                        initial: _serviceStartDate,
                        onPicked: (d) => setState(() => _serviceStartDate = d),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DatePickerTile(
                      label: 'Payment Date',
                      date: _paymentDate,
                      icon: Icons.event_outlined,
                      onTap: () => _pickDate(
                        initial: _paymentDate,
                        onPicked: (d) => setState(() => _paymentDate = d),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DatePickerTile(
                      label: 'Payment Received Date',
                      date: _paymentReceivedDate,
                      icon: Icons.payments_outlined,
                      onTap: () => _pickDate(
                        initial: _paymentReceivedDate,
                        onPicked: (d) =>
                            setState(() => _paymentReceivedDate = d),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DatePickerTile(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => _removeService(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${s.monthlyCharges.toStringAsFixed(0)}/month · Start: ${formatDate(s.startDate)}',
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
                                  'Due: ${formatDate(s.paymentDate)}  ·  Received: ${formatDate(s.paymentReceivedDate)}  ·  Next: ${formatDate(s.nextPaymentDate)}',
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
                              : (_isEditMode
                                  ? 'Update Customer'
                                  : 'Save to Cloud'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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