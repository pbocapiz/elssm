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

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes();
    _balancesFuture = LeaveService.fetchCurrentEmployeeBalances();
  }

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
    return AlertDialog(
      title: const Text('Apply for Leave'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<List<LeaveType>>(
                future: _leaveTypesFuture,
                builder: (context, snapshot) {
                  final types = snapshot.data ?? const [];
                  return DropdownButtonFormField<LeaveType>(
                    initialValue: _selectedLeaveType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Leave Type'),
                    items: [
                      for (final type in types)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (type) =>
                        setState(() => _selectedLeaveType = type),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_selectedLeaveType != null)
                FutureBuilder<List<LeaveBalance>>(
                  future: _balancesFuture,
                  builder: (context, snapshot) {
                    final balances = snapshot.data;
                    if (balances == null) return const SizedBox.shrink();
                    final matches = balances.where(
                      (b) => b.leaveTypeId == _selectedLeaveType!.id,
                    );
                    final available = matches.isEmpty
                        ? 0.0
                        : matches.first.availableBalance;
                    final over = _requestedDays > available;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            over
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                            size: 16,
                            color: over
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Available balance: ${available.toStringAsFixed(2)} days'
                              '${over ? ' — this request exceeds your balance' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: over
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStartDate,
                      child: Text(_formatDate(_startDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEndDate,
                      child: Text(_formatDate(_endDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Requested: $_requestedDays weekday(s)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _withPay,
                onChanged: (value) => setState(() => _withPay = value ?? true),
                title: const Text('With pay'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: FilledButton.styleFrom(backgroundColor: navyBlue),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
