import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/leave_type.dart';
import 'models/office_employee_leave_balance.dart';
import 'services/deduction_service.dart';
import 'services/opening_balance_service.dart';
import 'theme.dart';

Future<bool?> showAddDeductionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _AddDeductionDialog(),
  );
}

class _AddDeductionDialog extends StatefulWidget {
  const _AddDeductionDialog();

  @override
  State<_AddDeductionDialog> createState() => _AddDeductionDialogState();
}

class _AddDeductionDialogState extends State<_AddDeductionDialog> {
  late Future<List<LeaveType>> _leaveTypesFuture;
  Future<List<OfficeEmployeeLeaveBalance>>? _balancesFuture;
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  LeaveType? _selectedLeaveType;
  OfficeEmployeeLeaveBalance? _selectedEmployee;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes().then((types) {
      if (types.isNotEmpty && mounted) {
        setState(() => _selectedLeaveType = types.first);
        _loadBalances();
      }
      return types;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _loadBalances() {
    final leaveType = _selectedLeaveType;
    if (leaveType == null) return;
    setState(() {
      _selectedEmployee = null;
      _balancesFuture = DeductionService.fetchOfficeBalances(
        leaveTypeId: leaveType.id,
      );
    });
  }

  Future<void> _handleSubmit() async {
    final leaveType = _selectedLeaveType;
    final employee = _selectedEmployee;
    if (leaveType == null || employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a leave type and employee')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of days')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await DeductionService.createDeduction(
        employeeId: employee.employeeId,
        leaveTypeId: leaveType.id,
        amount: amount,
        deductionDate: DateTime.now(),
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
                      Icons.remove_circle_outline_rounded,
                      color: navyBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Record Leave Deduction',
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
                    decoration: const InputDecoration(
                      labelText: 'Leave Type',
                      prefixIcon: Icon(Icons.event_note_rounded),
                    ),
                    items: [
                      for (final type in types)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (type) {
                      setState(() => _selectedLeaveType = type);
                      _loadBalances();
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<OfficeEmployeeLeaveBalance>>(
                future: _balancesFuture,
                builder: (context, snapshot) {
                  final balances = snapshot.data ?? const [];
                  return DropdownButtonFormField<OfficeEmployeeLeaveBalance>(
                    initialValue: _selectedEmployee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    items: [
                      for (final balance in balances)
                        DropdownMenuItem(
                          value: balance,
                          child: Text(
                            '${balance.fullName} '
                            '(${balance.availableBalance.toStringAsFixed(3)} days left)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (balance) =>
                        setState(() => _selectedEmployee = balance),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Days to Deduct',
                  prefixIcon: Icon(Icons.remove_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Remarks',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Icon(Icons.notes_rounded),
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
                    onPressed: _isSubmitting ? null : _handleSubmit,
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
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Saving…' : 'Save'),
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
