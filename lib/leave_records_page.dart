import 'package:flutter/material.dart';

import 'add_deduction_dialog.dart';
import 'leave_history_page.dart';
import 'models/leave_transaction.dart';
import 'models/leave_type.dart';
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
  late Future<List<LeaveTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes();
    _transactionsFuture = TransactionService.fetchOfficeTransactions();
  }

  void _reload() {
    setState(() {
      _transactionsFuture = TransactionService.fetchOfficeTransactions(
        leaveTypeId: _selectedLeaveType?.id,
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
          '${transaction.amount.abs().toStringAsFixed(2)} day(s).',
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
                      DropdownMenuItem(value: type, child: Text(type.name)),
                  ],
                  onChanged: (type) {
                    setState(() => _selectedLeaveType = type);
                    _reload();
                  },
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

                final transactions = snapshot.data ?? const [];
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
