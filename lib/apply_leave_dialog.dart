import 'package:flutter/material.dart';

import 'models/leave_balance.dart';
import 'models/leave_type.dart';
import 'services/leave_application_service.dart';
import 'services/leave_service.dart';
import 'services/opening_balance_service.dart';
import 'theme.dart';

Future<bool?> showApplyLeaveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _ApplyLeaveDialog(),
  );
}

class _ApplyLeaveDialog extends StatefulWidget {
  const _ApplyLeaveDialog();

  @override
  State<_ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<_ApplyLeaveDialog> {
  late Future<List<LeaveType>> _leaveTypesFuture;
  late Future<List<LeaveBalance>> _balancesFuture;
  final _remarksController = TextEditingController();

  LeaveType? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _withPay = true;
  bool _isSubmitting = false;
  List<LeaveBalance> _balances = const [];

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes();
    _balancesFuture = LeaveService.fetchCurrentEmployeeBalances();
    _balancesFuture.then((balances) {
      if (mounted) setState(() => _balances = balances);
    });
  }

  double get _availableBalance {
    final leaveType = _selectedLeaveType;
    if (leaveType == null) return 0;
    final matches = _balances.where((b) => b.leaveTypeId == leaveType.id);
    return matches.isEmpty ? 0 : matches.first.availableBalance;
  }

  bool get _isOverBalance =>
      _selectedLeaveType != null && _requestedDays > _availableBalance;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  int get _requestedDays {
    if (_startDate == null || _endDate == null) return 0;
    var count = 0;
    var current = _startDate!;
    while (!current.isAfter(_endDate!)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _handleSubmit() async {
    final leaveType = _selectedLeaveType;
    if (leaveType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a leave type')));
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a start and end date')),
      );
      return;
    }
    if (_requestedDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected range has no weekdays')),
      );
      return;
    }
    if (_isOverBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough balance: requesting $_requestedDays day(s), '
            'only ${_availableBalance.toStringAsFixed(2)} available',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await LeaveApplicationService.submitApplication(
        leaveTypeId: leaveType.id,
        startDate: _startDate!,
        days: _requestedDays,
        withPay: _withPay,
        remarks: _remarksController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: navyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: navyBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Apply for Leave',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: navyBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade500,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<LeaveType>>(
                future: _leaveTypesFuture,
                builder: (context, snapshot) {
                  final types = snapshot.data ?? const [];
                  return DropdownButtonFormField<LeaveType>(
                    initialValue: _selectedLeaveType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Leave Type',
                      prefixIcon: const Icon(Icons.event_note_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF1F2F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      for (final type in types)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (type) =>
                        setState(() => _selectedLeaveType = type),
                  );
                },
              ),
              if (_selectedLeaveType != null) ...[
                const SizedBox(height: 10),
                _BalanceBanner(
                  available: _availableBalance,
                  isOver: _isOverBalance,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start Date',
                      value: _formatDate(_startDate),
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'End Date',
                      value: _formatDate(_endDate),
                      onTap: _pickEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: taupe.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: navyBlue.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requested: $_requestedDays weekday(s)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: navyBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: _withPay,
                  onChanged: (value) => setState(() => _withPay = value),
                  title: const Text(
                    'With pay',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: navyBlue,
                    ),
                  ),
                  activeTrackColor: navyBlue,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                decoration: InputDecoration(
                  labelText: 'Remarks (optional)',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Icon(Icons.notes_rounded),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (_isSubmitting || _isOverBalance)
                        ? null
                        : _handleSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: navyBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Submitting…' : 'Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: navyBlue.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: navyBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.available, required this.isOver});

  final double available;
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final color = isOver ? Colors.red.shade700 : navyBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOver
            ? Colors.red.withValues(alpha: 0.08)
            : navyBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: isOver
            ? Border.all(color: Colors.red.shade200)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.block_rounded : Icons.check_circle_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOver
                  ? 'Not enough balance — ${available.toStringAsFixed(2)} day(s) available'
                  : 'Available balance: ${available.toStringAsFixed(2)} days',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
