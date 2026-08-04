import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_deduction_dialog.dart';
import 'leave_history_page.dart';
import 'models/leave_transaction.dart';
import 'models/leave_type.dart';
import 'services/credit_service.dart';
import 'services/deduction_service.dart';
import 'services/leave_application_service.dart';
import 'services/opening_balance_service.dart';
import 'services/transaction_service.dart';
import 'theme.dart';

class LeaveRecordsPage extends StatefulWidget {
  const LeaveRecordsPage({super.key});

  @override
  State<LeaveRecordsPage> createState() => _LeaveRecordsPageState();
}

class _LeaveRecordsPageState extends State<LeaveRecordsPage> {
  late Future<List<LeaveType>> _leaveTypesFuture;
  LeaveType? _selectedLeaveType;
  int _selectedYear = DateTime.now().year;
  int? _selectedEmployeeId;
  late Future<List<LeaveTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes();
    _transactionsFuture = TransactionService.fetchOfficeTransactions(
      year: _selectedYear,
    );
  }

  void _reload() {
    setState(() {
      _transactionsFuture = TransactionService.fetchOfficeTransactions(
        leaveTypeId: _selectedLeaveType?.id,
        year: _selectedYear,
      );
    });
  }

  Future<void> _handleReview(
    LeaveTransaction transaction,
    String status,
  ) async {
    final verb = status == 'APPROVED' ? 'approve' : 'reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verb[0].toUpperCase()}${verb.substring(1)} request?'),
        content: Text(
          '${transaction.employeeName} — ${transaction.leaveTypeName}, '
          '${transaction.amount.abs().toStringAsFixed(3)} day(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: status == 'APPROVED'
                  ? Colors.green.shade700
                  : Colors.redAccent,
            ),
            child: Text(verb[0].toUpperCase() + verb.substring(1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await LeaveApplicationService.updateStatus(
        applicationId: transaction.sourceId!,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${status.toLowerCase()}')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $error')));
    }
  }

  Future<void> _openAddDeductionDialog() async {
    final added = await showAddDeductionDialog(context);
    if (added == true) _reload();
  }

  Future<void> _openEditDialog(LeaveTransaction transaction) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditTransactionDialog(transaction: transaction),
    );
    if (saved == true) _reload();
  }

  Future<void> _handleDelete(LeaveTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this record?'),
        content: Text(
          '${transaction.employeeName} — ${transaction.leaveTypeName}, '
          '${transaction.amount.abs().toStringAsFixed(3)} day(s). '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sourceId = transaction.sourceId;
    if (sourceId == null) return;

    try {
      switch (transaction.type) {
        case LeaveTransactionType.openingBalance:
          await OpeningBalanceService.deleteOpeningBalance(sourceId);
        case LeaveTransactionType.credit:
          await CreditService.deleteCredit(sourceId);
        case LeaveTransactionType.deduction:
          await DeductionService.deleteDeduction(sourceId);
        case LeaveTransactionType.application:
          await LeaveApplicationService.deleteApplication(sourceId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Record removed')));
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        onPressed: _openAddDeductionDialog,
        icon: const Icon(Icons.remove_circle_outline_rounded),
        label: const Text('Add Deduction'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<LeaveTransaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                final employees = <int, String>{};
                for (final transaction in snapshot.data ?? const []) {
                  employees[transaction.employeeId] = transaction.employeeName;
                }
                final employeeEntries = employees.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value));

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedEmployeeId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Filter by User',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Users'),
                              ),
                              for (final entry in employeeEntries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) =>
                                setState(() => _selectedEmployeeId = id),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: FutureBuilder<List<LeaveType>>(
                            future: _leaveTypesFuture,
                            builder: (context, snapshot) {
                              final types = snapshot.data ?? const [];
                              return DropdownButtonFormField<LeaveType?>(
                                initialValue: _selectedLeaveType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by Leave Type',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Leave Types'),
                                  ),
                                  for (final type in types)
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(type.name),
                                    ),
                                ],
                                onChanged: (type) {
                                  setState(() => _selectedLeaveType = type);
                                  _reload();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                            ),
                            items: [
                              for (
                                var y = DateTime.now().year - 2;
                                y <= DateTime.now().year + 1;
                                y++
                              )
                                DropdownMenuItem(value: y, child: Text('$y')),
                            ],
                            onChanged: (year) {
                              if (year == null) return;
                              setState(() => _selectedYear = year);
                              _reload();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<LeaveTransaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load records.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final transactions = (snapshot.data ?? const [])
                    .where(
                      (transaction) =>
                          _selectedEmployeeId == null ||
                          transaction.employeeId == _selectedEmployeeId,
                    )
                    .toList();
                if (transactions.isEmpty) {
                  return Center(
                    child: Text(
                      'No leave records found for your office.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return TransactionTile(
                      transaction: transaction,
                      showEmployeeName: true,
                      onApprove: () => _handleReview(transaction, 'APPROVED'),
                      onReject: () => _handleReview(transaction, 'REJECTED'),
                      onEdit: transaction.sourceId == null
                          ? null
                          : () => _openEditDialog(transaction),
                      onDelete: transaction.sourceId == null
                          ? null
                          : () => _handleDelete(transaction),
                    );
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

class _EditTransactionDialog extends StatefulWidget {
  const _EditTransactionDialog({required this.transaction});

  final LeaveTransaction transaction;

  @override
  State<_EditTransactionDialog> createState() =>
      _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late final _amountController = TextEditingController(
    text: widget.transaction.amount.abs().toStringAsFixed(3),
  );
  late final _remarksController = TextEditingController(
    text: widget.transaction.type == LeaveTransactionType.openingBalance
        ? ''
        : (widget.transaction.remarks ?? ''),
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.transaction.type) {
    LeaveTransactionType.openingBalance => 'Edit Opening Balance',
    LeaveTransactionType.credit => 'Edit Credit',
    LeaveTransactionType.deduction => 'Edit Deduction',
    LeaveTransactionType.application => 'Edit Application',
  };

  String get _amountLabel => switch (widget.transaction.type) {
    LeaveTransactionType.openingBalance => 'Opening Balance (days)',
    LeaveTransactionType.credit => 'Earned (days)',
    LeaveTransactionType.deduction => 'Days to Deduct',
    LeaveTransactionType.application => 'Days',
  };

  bool get _showRemarks =>
      widget.transaction.type != LeaveTransactionType.openingBalance;

  Future<void> _handleSubmit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of days')),
      );
      return;
    }

    final sourceId = widget.transaction.sourceId;
    if (sourceId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final remarks = _remarksController.text;
      switch (widget.transaction.type) {
        case LeaveTransactionType.openingBalance:
          await OpeningBalanceService.updateOpeningBalanceById(
            id: sourceId,
            amount: amount,
          );
        case LeaveTransactionType.credit:
          await CreditService.updateCredit(
            id: sourceId,
            earned: amount,
            remarks: remarks,
          );
        case LeaveTransactionType.deduction:
          await DeductionService.updateDeduction(
            id: sourceId,
            amount: amount,
            remarks: remarks,
          );
        case LeaveTransactionType.application:
          await LeaveApplicationService.updateApplication(
            id: sourceId,
            days: amount.round(),
            remarks: remarks,
          );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $error')));
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
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
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
              const SizedBox(height: 8),
              Text(
                '${widget.transaction.employeeName} — '
                '${widget.transaction.leaveTypeName}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                ],
                decoration: InputDecoration(labelText: _amountLabel),
              ),
              if (_showRemarks) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: FilledButton.styleFrom(backgroundColor: navyBlue),
                    child: Text(_isSubmitting ? 'Saving…' : 'Save'),
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
