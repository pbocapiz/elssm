import 'package:flutter/material.dart';

import 'models/leave_balance.dart';
import 'services/leave_service.dart';
import 'theme.dart';

class LeaveBalancePage extends StatefulWidget {
  const LeaveBalancePage({super.key});

  @override
  State<LeaveBalancePage> createState() => _LeaveBalancePageState();
}

class _LeaveBalancePageState extends State<LeaveBalancePage> {
  late Future<List<LeaveBalance>> _balancesFuture;

  static const _pinnedLeaveTypes = ['Vacation Leave', 'Sick Leave'];

  @override
  void initState() {
    super.initState();
    _balancesFuture = _loadSorted();
  }

  Future<void> _reload() {
    final future = _loadSorted();
    setState(() => _balancesFuture = future);
    return future;
  }

  Future<List<LeaveBalance>> _loadSorted() async {
    final balances = await LeaveService.fetchCurrentEmployeeBalances();
    final sorted = [...balances];
    sorted.sort((a, b) {
      final aRank = _pinnedLeaveTypes.indexOf(a.leaveTypeName);
      final bRank = _pinnedLeaveTypes.indexOf(b.leaveTypeName);
      if (aRank == -1 && bRank == -1) return 0;
      if (aRank == -1) return 1;
      if (bRank == -1) return -1;
      return aRank.compareTo(bRank);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaveBalance>>(
      future: _balancesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load leave balances.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final balances = snapshot.data ?? const [];
        if (balances.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No employee record is linked to your account yet.\n'
                    'Contact your administrator to have your leave balances set up.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: balances.length,
            itemBuilder: (context, index) =>
                _LeaveBalanceCard(balance: balances[index]),
          ),
        );
      },
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  balance.leaveTypeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: navyBlue,
                  ),
                ),
              ),
              Text(
                balance.availableBalance.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'days',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BalanceStatBox(
                        label: 'Opening',
                        value: balance.openingBalance,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BalanceStatBox(
                        label: 'Earned',
                        value: balance.totalEarned,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceStatBox(
                        label: 'Deducted',
                        value: balance.totalDeducted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BalanceStatBox(
                        label: 'Applied',
                        value: balance.totalApplied,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStatBox extends StatelessWidget {
  const _BalanceStatBox({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: navyBlue,
            ),
          ),
        ],
      ),
    );
  }
}
