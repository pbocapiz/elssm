import 'package:flutter/material.dart';

import 'apply_leave_dialog.dart';
import 'models/leave_transaction.dart';
import 'models/leave_type.dart';
import 'services/opening_balance_service.dart';
import 'services/transaction_service.dart';
import 'theme.dart';

class LeaveHistoryPage extends StatefulWidget {
  const LeaveHistoryPage({super.key});

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  late Future<List<LeaveType>> _leaveTypesFuture;
  LeaveType? _selectedLeaveType;
  late Future<List<LeaveTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes();
    _transactionsFuture = TransactionService.fetchCurrentEmployeeTransactions();
  }

  void _reload() {
    setState(() {
      _transactionsFuture = TransactionService.fetchCurrentEmployeeTransactions(
        leaveTypeId: _selectedLeaveType?.id,
      );
    });
  }

  Future<void> _openApplyDialog() async {
    final submitted = await showApplyLeaveDialog(context);
    if (submitted == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave application submitted')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        tooltip: 'Apply for leave',
        onPressed: _openApplyDialog,
        child: const Icon(Icons.add),
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
                      'Could not load history.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final transactions = snapshot.data ?? const [];
                if (transactions.isEmpty) {
                  return Center(
                    child: Text(
                      'No leave transactions yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) =>
                      TransactionTile(transaction: transactions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.showEmployeeName = false,
    this.onApprove,
    this.onReject,
  });

  final LeaveTransaction transaction;
  final bool showEmployeeName;

  /// When set (together with a PENDING application transaction), an
  /// Approve/Reject row is shown below the tile's content.
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final isOpeningBalance =
        transaction.type == LeaveTransactionType.openingBalance;
    final isPositive = transaction.amount >= 0;
    final sign = isPositive ? '+' : '';

    final iconColor = isOpeningBalance
        ? navyBlue
        : (isPositive ? Colors.green.shade700 : Colors.redAccent);
    final iconBackground = isOpeningBalance
        ? taupe.withValues(alpha: 0.35)
        : (isPositive ? Colors.green : Colors.redAccent).withValues(
            alpha: 0.12,
          );
    final icon = isOpeningBalance
        ? Icons.flag_rounded
        : (isPositive ? Icons.arrow_upward : Icons.arrow_downward);

    final canReview =
        transaction.type == LeaveTransactionType.application &&
        transaction.status == 'PENDING' &&
        transaction.sourceId != null &&
        (onApprove != null || onReject != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEmployeeName)
                      Text(
                        transaction.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: navyBlue,
                        ),
                      ),
                    Text(
                      transaction.leaveTypeName,
                      style: TextStyle(
                        fontWeight: showEmployeeName
                            ? FontWeight.w500
                            : FontWeight.w600,
                        fontSize: showEmployeeName ? 12 : 14,
                        color: showEmployeeName ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (transaction.remarks != null &&
                        transaction.remarks!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transaction.remarks!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isPositive
                          ? Colors.green.shade700
                          : Colors.redAccent,
                    ),
                  ),
                  if (transaction.status != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: taupe.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        transaction.status!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: navyBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (canReview) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
                if (onReject != null && onApprove != null)
                  const SizedBox(width: 8),
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
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
}
