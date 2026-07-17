import 'package:flutter/material.dart';

String formatDate(DateTime? date) {
  if (date == null) return '-';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$d/$m/$y';
}

String formatINR(num amount) {
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

class DetailChipText extends StatelessWidget {
  final String label;
  final String value;

  const DetailChipText({super.key, required this.label, required this.value});

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

class DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onTap;

  const DatePickerTile({
    super.key,
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
              date != null ? formatDate(date) : 'Select date',
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