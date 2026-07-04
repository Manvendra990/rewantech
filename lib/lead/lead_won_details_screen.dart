import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rtstrack/services/lead_service.dart';

/// Screen shown when a lead is marked "Won" — captures deal/project
/// details, payment structure, and agent incentive info.
class LeadWonDetailsScreen extends StatefulWidget {
  final String leadId;
  final String userName;

  /// Existing won-details map, if the lead was already filled in before
  /// (i.e. this is an edit, not a first-time entry).
  final Map<String, dynamic>? existing;

  const LeadWonDetailsScreen({
    super.key,
    required this.leadId,
    required this.userName,
    this.existing,
  });

  @override
  State<LeadWonDetailsScreen> createState() => _LeadWonDetailsScreenState();
}

class _LeadWonDetailsScreenState extends State<LeadWonDetailsScreen> {
  final _leadService = LeadService();
  final _formKey = GlobalKey<FormState>();

  static const _bg = Color(0xFFF4F5FB);
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _primary = Color(0xFF2F6FED);
  static const _primaryBg = Color(0xFFE3EBFD);
  static const _green = Color(0xFF16A34A);

  final _serviceOptions = const [
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

  final _paymentMethods = const [
    'Bank Transfer',
    'UPI',
    'Cheque',
    'Cash',
    'Card',
    'Other',
  ];

  late final TextEditingController _projectNameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _customServiceCtrl;
  late final TextEditingController _agentNameCtrl;
  late final TextEditingController _clientContactCtrl;
  late final TextEditingController _totalAmountCtrl;
  late final TextEditingController _monthlyAmountCtrl;
  late final TextEditingController _receivedCtrl;
  late final TextEditingController _incentivePercentCtrl;
  late final TextEditingController _incentiveAmountCtrl;

  final _incentiveFocus = FocusNode();

  String _serviceName = 'Web Development';
  String _paymentType = 'One-time'; // or 'Monthly'
  String _paymentMethod = 'Bank Transfer';
  DateTime _dealClosedDate = DateTime.now();
  DateTime? _nextPaymentDate;
  bool _incentiveManuallyEdited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};

    _projectNameCtrl = TextEditingController(text: e['projectName'] ?? '');
    _descCtrl = TextEditingController(text: e['description'] ?? '');
    _customServiceCtrl = TextEditingController(
      text: _serviceOptions.contains(e['serviceName'])
          ? ''
          : (e['serviceName'] ?? ''),
    );
    _agentNameCtrl = TextEditingController(
      text: e['agentName'] ?? widget.userName,
    );
    _clientContactCtrl = TextEditingController(text: e['clientContact'] ?? '');
    _totalAmountCtrl = TextEditingController(
      text: e['totalAmount'] != null ? _stripZero(e['totalAmount']) : '',
    );
    _monthlyAmountCtrl = TextEditingController(
      text: e['monthlyAmount'] != null ? _stripZero(e['monthlyAmount']) : '',
    );
    _receivedCtrl = TextEditingController(
      text: e['amountReceived'] != null ? _stripZero(e['amountReceived']) : '',
    );
    _incentivePercentCtrl = TextEditingController(
      text: e['incentivePercent'] != null
          ? _stripZero(e['incentivePercent'])
          : '',
    );
    _incentiveAmountCtrl = TextEditingController(
      text: e['incentiveAmount'] != null
          ? _stripZero(e['incentiveAmount'])
          : '',
    );

    if (e.isNotEmpty) {
      _serviceName = _serviceOptions.contains(e['serviceName'])
          ? e['serviceName']
          : 'Other';
      _paymentType = e['paymentType'] ?? 'One-time';
      _paymentMethod = _paymentMethods.contains(e['paymentMethod'])
          ? e['paymentMethod']
          : 'Bank Transfer';
      if (e['dealClosedDate'] is Timestamp) {
        _dealClosedDate = (e['dealClosedDate'] as Timestamp).toDate();
      }
      if (e['nextPaymentDate'] is Timestamp) {
        _nextPaymentDate = (e['nextPaymentDate'] as Timestamp).toDate();
      }
      _incentiveManuallyEdited = e['incentiveAmount'] != null;
    }

    _totalAmountCtrl.addListener(_recalcIncentive);
    _incentivePercentCtrl.addListener(_recalcIncentive);
    _incentiveFocus.addListener(() {
      if (_incentiveFocus.hasFocus) {
        setState(() => _incentiveManuallyEdited = true);
      }
    });
  }

  String _stripZero(dynamic n) {
    final d = (n as num).toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  void _recalcIncentive() {
    if (_incentiveManuallyEdited) return;
    final total = double.tryParse(_totalAmountCtrl.text) ?? 0;
    final pct = double.tryParse(_incentivePercentCtrl.text) ?? 0;
    final amount = total * pct / 100;
    _incentiveAmountCtrl.text = amount == 0 ? '' : _stripZero(amount);
  }

  void _resetIncentiveToAuto() {
    setState(() => _incentiveManuallyEdited = false);
    _recalcIncentive();
  }

  @override
  void dispose() {
    _projectNameCtrl.dispose();
    _descCtrl.dispose();
    _customServiceCtrl.dispose();
    _agentNameCtrl.dispose();
    _clientContactCtrl.dispose();
    _totalAmountCtrl.dispose();
    _monthlyAmountCtrl.dispose();
    _receivedCtrl.dispose();
    _incentivePercentCtrl.dispose();
    _incentiveAmountCtrl.dispose();
    _incentiveFocus.dispose();
    super.dispose();
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

  Future<void> _pickDate({required bool isDealDate}) async {
    final initial = isDealDate
        ? _dealClosedDate
        : (_nextPaymentDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDealDate) {
          _dealClosedDate = picked;
        } else {
          _nextPaymentDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final total = double.tryParse(_totalAmountCtrl.text) ?? 0;
    final monthly = double.tryParse(_monthlyAmountCtrl.text);
    final received = double.tryParse(_receivedCtrl.text) ?? 0;
    final incentivePercent = double.tryParse(_incentivePercentCtrl.text);
    final incentiveAmount = double.tryParse(_incentiveAmountCtrl.text);

    final service = _serviceName == 'Other'
        ? _customServiceCtrl.text.trim()
        : _serviceName;

    final details = <String, dynamic>{
      'projectName': _projectNameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'serviceName': service,
      'agentName': _agentNameCtrl.text.trim(),
      'clientContact': _clientContactCtrl.text.trim(),
      'paymentType': _paymentType,
      'totalAmount': total,
      'monthlyAmount': _paymentType == 'Monthly' ? monthly : null,
      'amountReceived': received,
      'pendingAmount': total - received,
      'paymentMethod': _paymentMethod,
      'incentivePercent': incentivePercent,
      'incentiveAmount': incentiveAmount,
      'dealClosedDate': Timestamp.fromDate(_dealClosedDate),
      'nextPaymentDate': _paymentType == 'Monthly' && _nextPaymentDate != null
          ? Timestamp.fromDate(_nextPaymentDate!)
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _leadService.updateWonDetails(widget.leadId, details);
      if (!mounted) return;
      Navigator.pop(context, details);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save nahi hua, try again: $err')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(icon, size: 16, color: _primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _subtitle,
      ),
    ),
  );

  InputDecoration _decoration({
    String? hint,
    String? prefixText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: _heading,
        fontWeight: FontWeight.w600,
      ),
      suffixIcon: suffix,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFEDF1FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    String? prefixText,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _heading),
      decoration: _decoration(
        hint: hint,
        prefixText: prefixText,
        suffix: suffix,
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _subtitle),
          style: const TextStyle(fontSize: 14, color: _heading),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(label(e))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: _subtitle,
            ),
            const SizedBox(width: 10),
            Text(
              date != null ? _formatDate(date) : label,
              style: TextStyle(
                fontSize: 13,
                color: date != null ? _heading : const Color(0xFF9CA3AF),
                fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_totalAmountCtrl.text) ?? 0;
    final received = double.tryParse(_receivedCtrl.text) ?? 0;
    final pending = total - received;

    String paymentStatusLabel;
    Color paymentStatusColor;
    Color paymentStatusBg;
    if (total <= 0) {
      paymentStatusLabel = 'Amount pending';
      paymentStatusColor = _subtitle;
      paymentStatusBg = const Color(0xFFE5E7EB);
    } else if (received >= total) {
      paymentStatusLabel = 'Fully Paid';
      paymentStatusColor = _green;
      paymentStatusBg = const Color(0xFFDCFCE7);
    } else if (received > 0) {
      paymentStatusLabel = 'Partially Paid';
      paymentStatusColor = const Color(0xFFB45309);
      paymentStatusBg = const Color(0xFFFEF3C7);
    } else {
      paymentStatusLabel = 'Payment Pending';
      paymentStatusColor = const Color(0xFFE11D48);
      paymentStatusBg = const Color(0xFFFDE2E6);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _heading),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Deal Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _heading,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Won banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                        'Lead won! Deal ki details bharo taaki record accurate rahe.',
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

              // ── Project Info ─────────────────────
              _sectionCard(
                title: 'Project Information',
                icon: Icons.work_outline_rounded,
                children: [
                  _label('Project Name'),
                  _textField(
                    _projectNameCtrl,
                    hint: 'e.g. E-commerce Website Revamp',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Project name required hai'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _label('Service'),
                  _dropdown<String>(
                    value: _serviceName,
                    items: _serviceOptions,
                    label: (e) => e,
                    onChanged: (v) => setState(() => _serviceName = v!),
                  ),
                  if (_serviceName == 'Other') ...[
                    const SizedBox(height: 12),
                    _label('Custom Service Name'),
                    _textField(
                      _customServiceCtrl,
                      hint: 'Service ka naam likho',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _label('Project Description'),
                  _textField(
                    _descCtrl,
                    hint: 'Scope, deliverables, timeline...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _label('Deal Closed Date'),
                  _dateField(
                    label: 'Select date',
                    date: _dealClosedDate,
                    onTap: () => _pickDate(isDealDate: true),
                  ),
                ],
              ),

              // ── Agent & Client ─────────────────────
              _sectionCard(
                title: 'Agent & Client',
                icon: Icons.people_alt_outlined,
                children: [
                  _label('Agent Name (who won the lead)'),
                  _textField(
                    _agentNameCtrl,
                    hint: 'Agent ka naam',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Agent name required hai'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _label('Client Contact (optional)'),
                  _textField(
                    _clientContactCtrl,
                    hint: 'Phone or email',
                    keyboardType: TextInputType.text,
                  ),
                ],
              ),

              // ── Payment Structure ─────────────────────
              _sectionCard(
                title: 'Payment Structure',
                icon: Icons.payments_outlined,
                children: [
                  _label('Payment Type'),
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
                          onTap: () => setState(() => _paymentType = 'Monthly'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _label(
                    _paymentType == 'Monthly'
                        ? 'Total Contract Value'
                        : 'Total Amount',
                  ),
                  _textField(
                    _totalAmountCtrl,
                    hint: '0',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Valid amount daalo';
                      return null;
                    },
                  ),
                  if (_paymentType == 'Monthly') ...[
                    const SizedBox(height: 12),
                    _label('Monthly Payment Amount'),
                    _textField(
                      _monthlyAmountCtrl,
                      hint: '0',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _label('Next Payment Due Date'),
                    _dateField(
                      label: 'Select date',
                      date: _nextPaymentDate,
                      onTap: () => _pickDate(isDealDate: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _label('Amount Received'),
                  _textField(
                    _receivedCtrl,
                    hint: '0',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _label('Payment Method'),
                  _dropdown<String>(
                    value: _paymentMethod,
                    items: _paymentMethods,
                    label: (e) => e,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: paymentStatusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 15,
                          color: paymentStatusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$paymentStatusLabel${total > 0 ? ' · Pending: ${_formatINR(pending < 0 ? 0 : pending)}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: paymentStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Agent Incentive ─────────────────────
              _sectionCard(
                title: 'Agent Incentive',
                icon: Icons.card_giftcard_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Incentive %'),
                            _textField(
                              _incentivePercentCtrl,
                              hint: '0',
                              suffix: const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Text(
                                  '%',
                                  style: TextStyle(color: _subtitle),
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Incentive Amount'),
                            _textField(
                              _incentiveAmountCtrl,
                              hint: '0',
                              prefixText: '₹ ',
                              focusNode: _incentiveFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                            ),
                          ],
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
                          color: _primary,
                        ),
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Amount % × total se auto-calculate ho raha hai',
                        style: TextStyle(fontSize: 11, color: _subtitle),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _heading,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Save Deal Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primaryBg : const Color(0xFFEDF1FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primary : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? _primary : _subtitle,
          ),
        ),
      ),
    );
  }
}
